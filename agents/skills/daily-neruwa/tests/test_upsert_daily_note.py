from __future__ import annotations

import subprocess

import pytest

from scripts import upsert_daily_note
from scripts.upsert_daily_note import END_MARKER, START_MARKER, upsert_managed_block


SECTION_V1 = """> [!summary]- AI-generated: Codex振り返り
> 初回の要約。"""

SECTION_V2 = """> [!summary]- AI-generated: Codex振り返り
> 更新後の要約。"""


def test_creates_new_daily_note_with_title_and_markers() -> None:
    merged = upsert_managed_block("", SECTION_V1, "2026-08-12")

    assert merged.startswith("# 2026-08-12\n")
    assert START_MARKER in merged
    assert END_MARKER in merged
    assert "初回の要約" in merged


def test_replaces_only_managed_block_and_preserves_personal_text() -> None:
    existing = (
        "# 2026-08-12\n\n"
        "朝の個人メモ。\n\n"
        f"{START_MARKER}\n{SECTION_V1}\n{END_MARKER}\n\n"
        "夜の個人メモ。\n"
    )

    merged = upsert_managed_block(existing, SECTION_V2, "2026-08-12")

    assert "朝の個人メモ。" in merged
    assert "夜の個人メモ。" in merged
    assert "初回の要約" not in merged
    assert "更新後の要約" in merged
    assert merged.count(START_MARKER) == 1
    assert merged.count(END_MARKER) == 1


def test_rejects_unbalanced_markers() -> None:
    with pytest.raises(ValueError, match="unbalanced"):
        upsert_managed_block(f"# 2026-08-12\n\n{START_MARKER}\n", SECTION_V1, "2026-08-12")


def test_requires_ai_generated_marker() -> None:
    with pytest.raises(ValueError, match="AI-generated"):
        upsert_managed_block("", "## Codex\n秘密の文章", "2026-08-12")


def test_read_note_treats_cli_not_found_output_as_missing(monkeypatch: pytest.MonkeyPatch) -> None:
    result = subprocess.CompletedProcess(
        args=[],
        returncode=0,
        stdout='Error: File "01_Imo/Daily/2099-01-01.md" not found.\n',
        stderr="",
    )
    monkeypatch.setattr(upsert_daily_note, "run_obsidian", lambda *args: result)

    assert upsert_daily_note.read_note("obsidian", "vault", "missing.md") == ""


def test_write_note_rejects_cli_error_with_zero_exit(monkeypatch: pytest.MonkeyPatch) -> None:
    result = subprocess.CompletedProcess(
        args=[], returncode=0, stdout="Error: write failed\n", stderr=""
    )
    monkeypatch.setattr(upsert_daily_note, "run_obsidian", lambda *args: result)

    with pytest.raises(RuntimeError, match="write failed"):
        upsert_daily_note.write_note("obsidian", "vault", "note.md", "content")
