#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

TEST_PATH="${(%):-%N}"
REPO_ROOT="${TEST_PATH:A:h:h}"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/codex-skills-test.XXXXXX")"
trap 'rm -rf -- "$TEST_TMP"' EXIT INT TERM
typeset -i PASSED=0
typeset -i FAILED=0

pass() {
  echo "[pass] $1"
  (( PASSED += 1 ))
}

fail() {
  echo "[fail] $1" >&2
  (( FAILED += 1 ))
}

create_fixture() {
  local label="$1"
  CASE_ROOT="$TEST_TMP/$label"
  CASE_REPO="$CASE_ROOT/repo"
  CASE_HOME="$CASE_ROOT/home"
  CASE_CODEX="$CASE_HOME/.codex/skills"
  CASE_AGENTS="$CASE_HOME/.agents/skills"
  CASE_PLUGIN_CACHE="$CASE_HOME/.codex/plugins/cache"
  mkdir -p "$CASE_REPO/scripts" "$CASE_REPO/.codex/skills/alpha" "$CASE_HOME" "$CASE_PLUGIN_CACHE"
  cp "$REPO_ROOT/scripts/codex-skills-registry.py" "$CASE_REPO/scripts/"
  cp "$REPO_ROOT/scripts/deploy-codex-skills.zsh" "$CASE_REPO/scripts/"
  cp "$REPO_ROOT/scripts/check-codex-skills.zsh" "$CASE_REPO/scripts/"
  cp "$REPO_ROOT/scripts/finalize-codex-skill.zsh" "$CASE_REPO/scripts/"
  chmod +x "$CASE_REPO/scripts/"*
  python3 - "$CASE_REPO" <<'PY'
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
(repo / ".codex/skills/alpha/SKILL.md").write_text(
    "---\nname: alpha\ndescription: Test fixture skill.\n---\n\n# Alpha\n",
    encoding="utf-8",
)
registry = {
    "schema_version": 1,
    "repository": {"url": "test", "visibility": "private", "verified_at": "2026-09-04", "license": "UNLICENSED"},
    "discovery": {"active_user_root": "~/.codex/skills", "official_current_user_root": "~/.agents/skills", "compatibility_policy": "test", "excluded_paths": []},
    "plugins": [],
    "skills": [{
        "name": "alpha",
        "kind": "owned",
        "local_path": ".codex/skills/alpha",
        "destination": "~/.codex/skills/alpha",
        "upstream": "",
        "version": "",
        "plugin_id": "",
        "license": "UNLICENSED",
        "enabled": True,
        "dependencies": [],
        "notes": "test",
    }],
}
(repo / ".codex/skills-registry.json").write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
PY
}

run_deploy() {
  env \
    CODEX_DOTFILES_DIR="$CASE_REPO" \
    DOTFILES_TARGET_HOME="$CASE_HOME" \
    CODEX_SKILLS_HOME="$CASE_CODEX" \
    CODEX_PLUGIN_CACHE="$CASE_PLUGIN_CACHE" \
    "$CASE_REPO/scripts/deploy-codex-skills.zsh" "$@"
}

run_check() {
  env \
    CODEX_DOTFILES_DIR="$CASE_REPO" \
    DOTFILES_TARGET_HOME="$CASE_HOME" \
    CODEX_SKILLS_HOME="$CASE_CODEX" \
    AGENTS_SKILLS_HOME="$CASE_AGENTS" \
    CODEX_SKILLS_REGISTRY="$CASE_REPO/.codex/skills-registry.json" \
    "$CASE_REPO/scripts/check-codex-skills.zsh"
}

run_finalize() {
  env \
    CODEX_DOTFILES_DIR="$CASE_REPO" \
    DOTFILES_TARGET_HOME="$CASE_HOME" \
    CODEX_SKILLS_HOME="$CASE_CODEX" \
    AGENTS_SKILLS_HOME="$CASE_AGENTS" \
    CODEX_SKILLS_REGISTRY="$CASE_REPO/.codex/skills-registry.json" \
    "$CASE_REPO/scripts/finalize-codex-skill.zsh" alpha
}

create_fixture new-link
if run_deploy --non-interactive >/dev/null && [[ -L "$CASE_CODEX/alpha" ]] && [[ "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$CASE_CODEX/alpha")" == "$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$CASE_REPO/.codex/skills/alpha")" ]]; then
  pass "new per-skill symlink"
else
  fail "new per-skill symlink"
fi

if output="$(run_deploy --non-interactive)" && [[ "$output" == *"already linked"* ]]; then
  pass "idempotent rerun"
else
  fail "idempotent rerun"
fi

create_fixture real-conflict
mkdir -p "$CASE_CODEX/alpha"
if ! run_deploy --non-interactive >/dev/null 2>&1 && [[ -d "$CASE_CODEX/alpha" ]] && [[ ! -L "$CASE_CODEX/alpha" ]]; then
  pass "real directory conflict is preserved"
else
  fail "real directory conflict is preserved"
fi

create_fixture symlink-conflict
mkdir -p "$CASE_ROOT/other" "$CASE_CODEX"
ln -s "$CASE_ROOT/other" "$CASE_CODEX/alpha"
if ! run_deploy --non-interactive >/dev/null 2>&1 && [[ "$(readlink "$CASE_CODEX/alpha")" == "$CASE_ROOT/other" ]]; then
  pass "different symlink conflict is preserved"
else
  fail "different symlink conflict is preserved"
fi

create_fixture broken-link
mkdir -p "$CASE_CODEX"
ln -s "$CASE_ROOT/missing" "$CASE_CODEX/alpha"
if ! run_deploy --non-interactive >/dev/null 2>&1 && [[ -L "$CASE_CODEX/alpha" ]] && [[ ! -e "$CASE_CODEX/alpha" ]]; then
  pass "broken symlink is detected and preserved"
else
  fail "broken symlink is detected and preserved"
fi

create_fixture dry-run
if output="$(run_deploy --dry-run --non-interactive)" && [[ "$output" == *"would link"* ]] && [[ ! -e "$CASE_CODEX/alpha" ]]; then
  pass "dry-run does not mutate HOME"
else
  fail "dry-run does not mutate HOME"
fi

create_fixture unregistered
run_deploy --non-interactive >/dev/null
mkdir -p "$CASE_REPO/.codex/skills/rogue"
python3 - "$CASE_REPO/.codex/skills/rogue/SKILL.md" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text("---\nname: rogue\ndescription: Rogue.\n---\n", encoding="utf-8")
PY
if ! run_check >/dev/null 2>&1; then
  pass "unregistered dotfiles skill fails inspection"
else
  fail "unregistered dotfiles skill fails inspection"
fi

create_fixture duplicate-name
run_deploy --non-interactive >/dev/null
mkdir -p "$CASE_AGENTS/alpha"
cp "$CASE_REPO/.codex/skills/alpha/SKILL.md" "$CASE_AGENTS/alpha/SKILL.md"
if ! run_check >/dev/null 2>&1; then
  pass "duplicate discovered skill name fails inspection"
else
  fail "duplicate discovered skill name fails inspection"
fi

create_fixture duplicate-registry
python3 - "$CASE_REPO/.codex/skills-registry.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
data["skills"].append(dict(data["skills"][0]))
path.write_text(json.dumps(data, indent=2) + "\n")
PY
if ! run_deploy --non-interactive >/dev/null 2>&1; then
  pass "duplicate registry name fails deployment"
else
  fail "duplicate registry name fails deployment"
fi

create_fixture plugin-conflict
mkdir -p "$CASE_PLUGIN_CACHE/provider/1/skills/alpha"
cp "$CASE_REPO/.codex/skills/alpha/SKILL.md" "$CASE_PLUGIN_CACHE/provider/1/skills/alpha/SKILL.md"
if ! run_deploy --non-interactive >/dev/null 2>&1 && [[ ! -e "$CASE_CODEX/alpha" ]]; then
  pass "plugin skill collision prevents local link"
else
  fail "plugin skill collision prevents local link"
fi

create_fixture finalize-scope
run_deploy --non-interactive >/dev/null
git -C "$CASE_REPO" init -q
git -C "$CASE_REPO" config user.name "Codex Skill Test"
git -C "$CASE_REPO" config user.email "codex-skill-test@example.invalid"
git -C "$CASE_REPO" add .
git -C "$CASE_REPO" commit -q -m "test: initial fixture"
print '\nUpdated.\n' >> "$CASE_REPO/.codex/skills/alpha/SKILL.md"
touch "$CASE_REPO/unrelated.txt"
if run_finalize >/dev/null && [[ -z "$(git -C "$CASE_REPO" diff --cached --name-only)" ]] && [[ -n "$(git -C "$CASE_REPO" status --short -- unrelated.txt)" ]] && [[ "$(git -C "$CASE_REPO" show --format= --name-only HEAD)" == ".codex/skills/alpha/SKILL.md" ]]; then
  pass "finalize commits only the target change"
else
  fail "finalize commits only the target change"
fi

create_fixture finalize-staged-refusal
run_deploy --non-interactive >/dev/null
git -C "$CASE_REPO" init -q
git -C "$CASE_REPO" config user.name "Codex Skill Test"
git -C "$CASE_REPO" config user.email "codex-skill-test@example.invalid"
git -C "$CASE_REPO" add .
git -C "$CASE_REPO" commit -q -m "test: initial fixture"
print '\nUpdated.\n' >> "$CASE_REPO/.codex/skills/alpha/SKILL.md"
touch "$CASE_REPO/unrelated.txt"
git -C "$CASE_REPO" add unrelated.txt
before="$(git -C "$CASE_REPO" rev-parse HEAD)"
if ! run_finalize >/dev/null 2>&1 && [[ "$(git -C "$CASE_REPO" rev-parse HEAD)" == "$before" ]] && [[ "$(git -C "$CASE_REPO" diff --cached --name-only)" == "unrelated.txt" ]]; then
  pass "finalize refuses unrelated staged changes"
else
  fail "finalize refuses unrelated staged changes"
fi

if [[ -d "$REPO_ROOT/.codex/skills/daily-neruwa" ]] && ! find "$REPO_ROOT/.codex/skills/daily-neruwa" \( -name .git -o -name .venv -o -name .pytest_cache -o -name __pycache__ \) -print -quit | read -r; then
  pass "daily-neruwa snapshot excludes Git and caches"
else
  fail "daily-neruwa snapshot excludes Git and caches"
fi

echo "[result] passed=$PASSED failed=$FAILED"
(( FAILED == 0 ))
