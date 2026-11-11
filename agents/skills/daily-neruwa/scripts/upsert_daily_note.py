#!/usr/bin/env python3

from __future__ import annotations

import argparse
import subprocess
from datetime import date, datetime
from pathlib import Path
from zoneinfo import ZoneInfo


START_MARKER = "%% daily-neruwa:start %%"
END_MARKER = "%% daily-neruwa:end %%"
DEFAULT_OBSIDIAN_CLI = "/Users/sugawara/.local/bin/obsidian"
DEFAULT_VAULT = "Obsidian_vault"
DEFAULT_DAILY_FOLDER = "01_Imo/Daily"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Idempotently upsert the Daily Neruwa managed block through Obsidian CLI."
    )
    parser.add_argument("--date", help="Daily note date in YYYY-MM-DD. Default: today in JST.")
    parser.add_argument("--section-file", required=True, help="Markdown body without markers.")
    parser.add_argument("--vault", default=DEFAULT_VAULT)
    parser.add_argument("--daily-folder", default=DEFAULT_DAILY_FOLDER)
    parser.add_argument("--obsidian-cli", default=DEFAULT_OBSIDIAN_CLI)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print the merged note without writing it to Obsidian.",
    )
    return parser.parse_args()


def managed_block(section: str) -> str:
    section = section.strip()
    if START_MARKER in section or END_MARKER in section:
        raise ValueError("section file must not contain daily-neruwa markers")
    if "AI-generated" not in section:
        raise ValueError("section must explicitly contain the AI-generated marker")
    return f"{START_MARKER}\n{section}\n{END_MARKER}"


def upsert_managed_block(existing: str, section: str, note_date: str) -> str:
    has_start = START_MARKER in existing
    has_end = END_MARKER in existing
    if has_start != has_end:
        raise ValueError("daily note contains an unbalanced daily-neruwa marker")

    block = managed_block(section)
    if not existing.strip():
        return f"# {note_date}\n\n{block}\n"

    if has_start:
        start = existing.index(START_MARKER)
        end = existing.index(END_MARKER, start) + len(END_MARKER)
        merged = existing[:start].rstrip() + "\n\n" + block
        suffix = existing[end:].strip("\n")
        if suffix:
            merged += "\n\n" + suffix
        return merged.rstrip() + "\n"

    return existing.rstrip() + "\n\n" + block + "\n"


def run_obsidian(cli: str, vault: str, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [cli, f"vault={vault}", *arguments],
        capture_output=True,
        text=True,
        timeout=30,
    )


def read_note(cli: str, vault: str, note_path: str) -> str:
    result = run_obsidian(cli, vault, "read", f"path={note_path}")
    output = (result.stderr or result.stdout).strip()
    lowered = output.lower()
    if "not found" in lowered or "does not exist" in lowered:
        return ""
    if result.returncode == 0 and not lowered.startswith("error:"):
        return result.stdout
    raise RuntimeError(output)


def write_note(cli: str, vault: str, note_path: str, content: str) -> None:
    result = run_obsidian(
        cli,
        vault,
        "create",
        f"path={note_path}",
        f"content={content}",
        "overwrite",
        "silent",
    )
    output = (result.stderr or result.stdout).strip()
    if result.returncode != 0 or output.lower().startswith("error:"):
        raise RuntimeError(output)


def main() -> int:
    args = parse_args()
    timezone = ZoneInfo("Asia/Tokyo")
    note_date = args.date or datetime.now(timezone).date().isoformat()
    date.fromisoformat(note_date)

    section = Path(args.section_file).expanduser().read_text()
    note_path = f"{args.daily_folder.rstrip('/')}/{note_date}.md"
    existing = read_note(args.obsidian_cli, args.vault, note_path)
    merged = upsert_managed_block(existing, section, note_date)

    if args.dry_run:
        print(merged, end="")
    else:
        write_note(args.obsidian_cli, args.vault, note_path, merged)
        print(note_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
