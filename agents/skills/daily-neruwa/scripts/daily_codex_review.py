#!/usr/bin/env python3

from __future__ import annotations

import argparse
import ast
import json
import os
import re
import shlex
import subprocess
from collections import Counter
from dataclasses import dataclass, field
from datetime import date, datetime, time
from pathlib import Path
from typing import Any
from zoneinfo import ZoneInfo


DEFAULT_TIMEZONE = "Asia/Tokyo"
MAX_MESSAGE_CHARS = 2_000
MAX_COMMAND_CHARS = 500

PATCH_FILE_RE = re.compile(
    r"^\s*\*\*\* (?:Add|Update|Delete) File: (?P<path>.+?)\s*$",
    re.MULTILINE,
)
NESTED_TOOL_RE = re.compile(r"\btools\.([A-Za-z0-9_]+)")

INJECTED_CONTEXT_PREFIXES = (
    "# AGENTS.md instructions for ",
    "<environment_context>",
    "<skill>",
    "<INSTRUCTIONS>",
    "The following is the Codex agent history whose request action you are assessing.",
    "The following is the Codex agent history added since your last approval assessment.",
)


@dataclass
class SessionEvidence:
    thread_id: str
    session_path: Path
    thread_name: str
    cwd: str | None
    source: str
    originator: str | None
    meta_started_at: datetime | None
    activity_started_at: datetime | None = None
    activity_ended_at: datetime | None = None
    user_messages: list[dict[str, str]] = field(default_factory=list)
    assistant_final_messages: list[dict[str, str]] = field(default_factory=list)
    assistant_progress_messages: list[dict[str, str]] = field(default_factory=list)
    directories: set[str] = field(default_factory=set)
    modified_files: set[str] = field(default_factory=set)
    tool_counts: Counter[str] = field(default_factory=Counter)
    command_counts: Counter[str] = field(default_factory=Counter)
    git_commands: list[str] = field(default_factory=list)
    activity_events: int = 0

    @property
    def resumed(self) -> bool:
        if self.meta_started_at is None or self.activity_started_at is None:
            return False
        return self.meta_started_at.date() != self.activity_started_at.date()

    @property
    def meaningful(self) -> bool:
        return bool(
            self.user_messages
            or self.assistant_final_messages
            or self.tool_counts
            or self.modified_files
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect factual evidence from top-level Codex sessions active on one JST day."
    )
    parser.add_argument("--date", help="Target date in YYYY-MM-DD. Default: today in timezone.")
    parser.add_argument(
        "--timezone",
        default=DEFAULT_TIMEZONE,
        help=f"IANA timezone name. Default: {DEFAULT_TIMEZONE}",
    )
    parser.add_argument(
        "--codex-home",
        default=os.environ.get("CODEX_HOME", str(Path.home() / ".codex")),
        help="Codex home directory. Default: $CODEX_HOME or ~/.codex",
    )
    parser.add_argument(
        "--format",
        choices=("json", "markdown"),
        default="json",
        help="Evidence output format. Default: json",
    )
    parser.add_argument("--output", help="Write evidence to this file instead of stdout.")
    parser.add_argument(
        "--include-subagents",
        action="store_true",
        help="Include approval, guardian, and other subagent sessions.",
    )
    return parser.parse_args()


def parse_timestamp(raw: str | None, timezone: ZoneInfo) -> datetime | None:
    if not raw:
        return None
    try:
        return datetime.fromisoformat(raw.replace("Z", "+00:00")).astimezone(timezone)
    except ValueError:
        return None


def clip(text: str, limit: int = MAX_MESSAGE_CHARS) -> str:
    compact = "\n".join(line.rstrip() for line in text.strip().splitlines()).strip()
    if len(compact) <= limit:
        return compact
    return compact[: limit - 3].rstrip() + "..."


def clean_user_message(message: str) -> str:
    cleaned = re.sub(r"\[\$[^\]]+\]\([^)]+\)", "", message)
    return clip(cleaned)


def is_injected_context(message: str) -> bool:
    stripped = message.lstrip()
    return stripped.startswith(INJECTED_CONTEXT_PREFIXES)


def normalize_path(raw_path: str, base: str | None = None) -> str:
    path = Path(raw_path).expanduser()
    if not path.is_absolute() and base:
        path = Path(base) / path
    return str(path.resolve(strict=False))


def source_label(source: Any) -> str:
    if isinstance(source, str):
        return source
    if isinstance(source, dict) and "subagent" in source:
        subagent = source.get("subagent")
        if isinstance(subagent, dict) and subagent:
            return "subagent:" + ",".join(sorted(str(key) for key in subagent))
        return "subagent"
    if source is None:
        return "unknown"
    return json.dumps(source, ensure_ascii=False, sort_keys=True)


def is_subagent_source(source: Any) -> bool:
    return isinstance(source, dict) and "subagent" in source


def read_session_index(index_path: Path) -> dict[str, str]:
    titles: dict[str, str] = {}
    if not index_path.exists():
        return titles
    for line in index_path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        thread_id = item.get("id")
        thread_name = item.get("thread_name")
        if isinstance(thread_id, str) and isinstance(thread_name, str):
            titles[thread_id] = thread_name
    return titles


def parse_string_literal(literal: str) -> str | None:
    try:
        value = ast.literal_eval(literal)
    except (SyntaxError, ValueError):
        return None
    return value if isinstance(value, str) else None


def extract_js_string_fields(source: str, key: str) -> list[str]:
    pattern = re.compile(
        rf"\b{re.escape(key)}\s*:\s*(\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*')",
        re.DOTALL,
    )
    values: list[str] = []
    for match in pattern.finditer(source):
        value = parse_string_literal(match.group(1))
        if value is not None:
            values.append(value)
    return values


def command_name(command: str) -> str:
    try:
        parts = shlex.split(command)
    except ValueError:
        parts = command.split()
    while parts and "=" in parts[0] and not parts[0].startswith(("/", "./")):
        parts.pop(0)
    return Path(parts[0]).name if parts else "unknown"


def record_command(session: SessionEvidence, command: str) -> None:
    command = command.strip()
    if not command:
        return
    session.command_counts[command_name(command)] += 1
    compact = " ".join(command.split())
    if re.search(r"(?:^|\s)git(?:\s|$)", compact) and compact not in session.git_commands:
        session.git_commands.append(clip(compact, MAX_COMMAND_CHARS))


def record_patch_paths(session: SessionEvidence, text: str, base: str | None = None) -> None:
    candidates = (text, text.replace("\\r\\n", "\n").replace("\\n", "\n"))
    for candidate in candidates:
        for match in PATCH_FILE_RE.finditer(candidate):
            raw_path = match.group("path").strip()
            session.modified_files.add(normalize_path(raw_path, base or session.cwd))


def inspect_legacy_arguments(session: SessionEvidence, value: Any) -> None:
    if isinstance(value, dict):
        base = session.cwd
        for key in ("workdir", "cwd"):
            workdir = value.get(key)
            if isinstance(workdir, str) and workdir:
                normalized = normalize_path(workdir, session.cwd)
                session.directories.add(normalized)
                base = normalized
        command = value.get("cmd")
        if isinstance(command, str):
            record_command(session, command)
        for nested in value.values():
            inspect_legacy_arguments(session, nested)
        return
    if isinstance(value, list):
        for nested in value:
            inspect_legacy_arguments(session, nested)
        return
    if isinstance(value, str):
        record_patch_paths(session, value)


def inspect_function_call(session: SessionEvidence, payload: dict[str, Any]) -> None:
    name = str(payload.get("name") or "unknown")
    if name not in {"wait", "write_stdin"}:
        session.tool_counts[name] += 1
    raw_arguments = payload.get("arguments", "")
    if not isinstance(raw_arguments, str):
        return
    try:
        arguments = json.loads(raw_arguments)
    except json.JSONDecodeError:
        record_patch_paths(session, raw_arguments)
        return
    inspect_legacy_arguments(session, arguments)


def inspect_custom_tool_call(session: SessionEvidence, payload: dict[str, Any]) -> None:
    source = payload.get("input", "")
    if not isinstance(source, str):
        return

    nested_tools = NESTED_TOOL_RE.findall(source)
    if nested_tools:
        session.tool_counts.update(nested_tools)
    else:
        name = str(payload.get("name") or "unknown")
        session.tool_counts[name] += 1

    workdirs = extract_js_string_fields(source, "workdir")
    workdirs.extend(extract_js_string_fields(source, "cwd"))
    normalized_workdirs = [normalize_path(item, session.cwd) for item in workdirs]
    session.directories.update(normalized_workdirs)

    for command in extract_js_string_fields(source, "cmd"):
        record_command(session, command)

    base = normalized_workdirs[-1] if normalized_workdirs else session.cwd
    record_patch_paths(session, source, base)


def append_message(target: list[dict[str, str]], timestamp: datetime, text: str) -> None:
    item = {"timestamp": timestamp.isoformat(), "text": clip(text)}
    if item not in target:
        target.append(item)


def response_message_text(payload: dict[str, Any]) -> str:
    content = payload.get("content")
    if not isinstance(content, list):
        return ""
    parts: list[str] = []
    for item in content:
        if not isinstance(item, dict):
            continue
        text = item.get("text")
        if isinstance(text, str):
            parts.append(text)
    return "\n".join(parts)


def parse_session_file(
    session_path: Path,
    titles: dict[str, str],
    target_date: date,
    timezone: ZoneInfo,
    include_subagents: bool,
) -> tuple[SessionEvidence | None, str]:
    session: SessionEvidence | None = None
    saw_target_activity = False

    for line in session_path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        event_type = event.get("type")
        payload = event.get("payload")
        if not isinstance(payload, dict):
            payload = {}

        if event_type == "session_meta":
            raw_source = payload.get("source")
            if is_subagent_source(raw_source) and not include_subagents:
                return None, "subagent"
            thread_id = str(payload.get("id") or session_path.stem)
            cwd = payload.get("cwd") if isinstance(payload.get("cwd"), str) else None
            session = SessionEvidence(
                thread_id=thread_id,
                session_path=session_path,
                thread_name=titles.get(thread_id, thread_id),
                cwd=cwd,
                source=source_label(raw_source),
                originator=(
                    payload.get("originator")
                    if isinstance(payload.get("originator"), str)
                    else None
                ),
                meta_started_at=parse_timestamp(payload.get("timestamp"), timezone),
            )
            if cwd:
                session.directories.add(normalize_path(cwd))
            continue

        if session is None:
            continue
        timestamp = parse_timestamp(event.get("timestamp"), timezone)
        if timestamp is None or timestamp.date() != target_date:
            continue

        saw_target_activity = True
        session.activity_events += 1
        if session.activity_started_at is None:
            session.activity_started_at = timestamp
        session.activity_ended_at = timestamp

        payload_type = payload.get("type")
        if event_type == "event_msg" and payload_type == "user_message":
            message = payload.get("message")
            if isinstance(message, str) and not is_injected_context(message):
                cleaned = clean_user_message(message)
                if cleaned:
                    append_message(session.user_messages, timestamp, cleaned)
        elif event_type == "event_msg" and payload_type == "agent_message":
            message = payload.get("message")
            if not isinstance(message, str) or not message.strip():
                continue
            phase = payload.get("phase")
            if phase == "final_answer":
                append_message(session.assistant_final_messages, timestamp, message)
            elif phase == "commentary":
                append_message(session.assistant_progress_messages, timestamp, message)
        elif event_type == "response_item" and payload_type == "function_call":
            inspect_function_call(session, payload)
        elif event_type == "response_item" and payload_type == "custom_tool_call":
            inspect_custom_tool_call(session, payload)
        elif event_type == "response_item" and payload_type == "message":
            phase = payload.get("phase")
            if phase == "final_answer" and not session.assistant_final_messages:
                text = response_message_text(payload)
                if text:
                    append_message(session.assistant_final_messages, timestamp, text)

    if not saw_target_activity:
        return None, "no-target-activity"
    if session is None or not session.meaningful:
        return None, "not-meaningful"
    session.assistant_progress_messages = session.assistant_progress_messages[-5:]
    session.git_commands = session.git_commands[:20]
    return session, "included"


def run_git(path: str, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", path, *args],
            check=True,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        return None
    return result.stdout.strip()


def collect_repository_evidence(
    sessions: list[SessionEvidence], target_date: date, timezone: ZoneInfo
) -> list[dict[str, Any]]:
    roots: set[str] = set()
    for session in sessions:
        for directory in session.directories:
            if not Path(directory).is_dir():
                continue
            root = run_git(directory, "rev-parse", "--show-toplevel")
            if root:
                roots.add(normalize_path(root))

    since = datetime.combine(target_date, time.min, tzinfo=timezone).isoformat()
    until = datetime.combine(target_date, time.max, tzinfo=timezone).isoformat()
    repositories: list[dict[str, Any]] = []
    for root in sorted(roots):
        status = run_git(root, "status", "--short") or ""
        log = run_git(
            root,
            "log",
            "--all",
            f"--since={since}",
            f"--until={until}",
            "--date=iso-strict",
            "--pretty=format:%H%x09%ad%x09%s",
            "-n",
            "50",
        ) or ""
        commits: list[dict[str, str]] = []
        for line in log.splitlines():
            parts = line.split("\t", 2)
            if len(parts) == 3:
                commits.append({"sha": parts[0], "date": parts[1], "subject": parts[2]})
        repositories.append(
            {
                "root": root,
                "branch": run_git(root, "branch", "--show-current") or "",
                "head": run_git(root, "rev-parse", "HEAD") or "",
                "origin": run_git(root, "remote", "get-url", "origin") or "",
                "dirty_files": [line for line in status.splitlines() if line.strip()][:100],
                "commits_dated_in_window": commits,
            }
        )
    return repositories


def session_to_dict(session: SessionEvidence) -> dict[str, Any]:
    return {
        "thread_id": session.thread_id,
        "thread_name": session.thread_name,
        "session_file": str(session.session_path),
        "source": session.source,
        "originator": session.originator,
        "cwd": session.cwd,
        "meta_started_at": (
            session.meta_started_at.isoformat() if session.meta_started_at else None
        ),
        "activity_started_at": (
            session.activity_started_at.isoformat() if session.activity_started_at else None
        ),
        "activity_ended_at": (
            session.activity_ended_at.isoformat() if session.activity_ended_at else None
        ),
        "resumed": session.resumed,
        "user_messages": session.user_messages,
        "assistant_final_messages": session.assistant_final_messages,
        "assistant_progress_messages": session.assistant_progress_messages,
        "directories": sorted(session.directories),
        "modified_files": sorted(session.modified_files),
        "tool_counts": dict(session.tool_counts.most_common()),
        "command_counts": dict(session.command_counts.most_common()),
        "git_commands": session.git_commands,
    }


def collect_evidence(
    codex_home: Path,
    target_date: date,
    timezone: ZoneInfo,
    include_subagents: bool = False,
) -> dict[str, Any]:
    titles = read_session_index(codex_home / "session_index.jsonl")
    session_root = codex_home / "sessions"
    stats: Counter[str] = Counter()
    sessions: list[SessionEvidence] = []

    if session_root.exists():
        for session_path in sorted(session_root.glob("*/*/*/rollout-*.jsonl")):
            stats["scanned"] += 1
            session, reason = parse_session_file(
                session_path,
                titles,
                target_date,
                timezone,
                include_subagents,
            )
            stats[reason] += 1
            if session is not None:
                sessions.append(session)

    sessions.sort(key=lambda item: item.activity_started_at or datetime.min.replace(tzinfo=timezone))
    repositories = collect_repository_evidence(sessions, target_date, timezone)
    return {
        "schema_version": 2,
        "date": target_date.isoformat(),
        "timezone": str(timezone),
        "generated_at": datetime.now(timezone).isoformat(),
        "session_count": len(sessions),
        "scan_stats": dict(stats),
        "sessions": [session_to_dict(session) for session in sessions],
        "repositories": repositories,
    }


def render_markdown(evidence: dict[str, Any]) -> str:
    lines = [
        f"# Daily Neruwa evidence: {evidence['date']}",
        "",
        f"- Timezone: `{evidence['timezone']}`",
        f"- Top-level sessions: {evidence['session_count']}",
        "",
    ]
    for session in evidence["sessions"]:
        lines.extend(
            [
                f"## {session['thread_name']}",
                "",
                f"- Thread ID: `{session['thread_id']}`",
                f"- Activity: {session['activity_started_at']} - {session['activity_ended_at']}",
                f"- CWD: `{session['cwd'] or ''}`",
                f"- Resumed: `{str(session['resumed']).lower()}`",
            ]
        )
        if session["user_messages"]:
            lines.append("- User intent: " + session["user_messages"][0]["text"])
        if session["assistant_final_messages"]:
            lines.append("- Final result: " + session["assistant_final_messages"][-1]["text"])
        if session["modified_files"]:
            lines.append("- Modified files: " + ", ".join(session["modified_files"][:12]))
        lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    args = parse_args()
    timezone = ZoneInfo(args.timezone)
    target_date = (
        date.fromisoformat(args.date) if args.date else datetime.now(timezone).date()
    )
    evidence = collect_evidence(
        Path(args.codex_home).expanduser(),
        target_date,
        timezone,
        include_subagents=args.include_subagents,
    )
    rendered = (
        json.dumps(evidence, ensure_ascii=False, indent=2) + "\n"
        if args.format == "json"
        else render_markdown(evidence)
    )
    if args.output:
        output_path = Path(args.output).expanduser()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(rendered)
        print(output_path)
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
