from __future__ import annotations

import json
from datetime import date
from pathlib import Path
from zoneinfo import ZoneInfo

from scripts.daily_codex_review import collect_evidence


JST = ZoneInfo("Asia/Tokyo")


def write_jsonl(path: Path, events: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(event, ensure_ascii=False) for event in events) + "\n")


def test_collects_resumed_top_level_session_and_excludes_subagent(tmp_path: Path) -> None:
    codex_home = tmp_path / ".codex"
    codex_home.mkdir()
    (codex_home / "session_index.jsonl").write_text(
        json.dumps({"id": "thread-main", "thread_name": "Main work"}) + "\n"
    )

    main_log = codex_home / "sessions/2026/01/01/rollout-main.jsonl"
    write_jsonl(
        main_log,
        [
            {
                "timestamp": "2026-01-01T00:00:00Z",
                "type": "session_meta",
                "payload": {
                    "id": "thread-main",
                    "timestamp": "2026-01-01T00:00:00Z",
                    "cwd": str(tmp_path / "repo"),
                    "source": "vscode",
                    "originator": "Codex Desktop",
                },
            },
            {
                "timestamp": "2026-08-11T16:00:00Z",
                "type": "event_msg",
                "payload": {"type": "user_message", "message": "実装を仕上げて"},
            },
            {
                "timestamp": "2026-08-11T16:00:01Z",
                "type": "event_msg",
                "payload": {
                    "type": "user_message",
                    "message": "<environment_context>ignored</environment_context>",
                },
            },
            {
                "timestamp": "2026-08-11T16:01:00Z",
                "type": "response_item",
                "payload": {
                    "type": "custom_tool_call",
                    "name": "exec",
                    "input": (
                        'const r = await tools.exec_command({cmd: "git status", '
                        f'workdir: "{tmp_path / "repo"}"}});\n'
                        'await tools.apply_patch("*** Begin Patch\\n'
                        '*** Update File: src/app.py\\n*** End Patch");'
                    ),
                },
            },
            {
                "timestamp": "2026-08-11T16:02:00Z",
                "type": "event_msg",
                "payload": {
                    "type": "agent_message",
                    "phase": "final_answer",
                    "message": "実装とテストが完了した。",
                },
            },
        ],
    )

    subagent_log = codex_home / "sessions/2026/08/12/rollout-subagent.jsonl"
    write_jsonl(
        subagent_log,
        [
            {
                "timestamp": "2026-08-11T16:00:00Z",
                "type": "session_meta",
                "payload": {
                    "id": "thread-subagent",
                    "timestamp": "2026-08-11T16:00:00Z",
                    "cwd": str(tmp_path),
                    "source": {"subagent": {"other": "guardian"}},
                },
            },
            {
                "timestamp": "2026-08-11T16:00:01Z",
                "type": "event_msg",
                "payload": {"type": "user_message", "message": "approval transcript"},
            },
        ],
    )

    evidence = collect_evidence(codex_home, date(2026, 8, 12), JST)

    assert evidence["session_count"] == 1
    assert evidence["scan_stats"]["subagent"] == 1
    session = evidence["sessions"][0]
    assert session["thread_id"] == "thread-main"
    assert session["resumed"] is True
    assert [item["text"] for item in session["user_messages"]] == ["実装を仕上げて"]
    assert session["assistant_final_messages"][-1]["text"] == "実装とテストが完了した。"
    assert session["tool_counts"]["exec_command"] == 1
    assert session["command_counts"]["git"] == 1
    assert str((tmp_path / "repo/src/app.py").resolve()) in session["modified_files"]
