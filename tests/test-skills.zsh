#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

TEST_PATH="${(%):-%N}"
REPO_ROOT="${TEST_PATH:A:h:h}"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/skills-test.XXXXXX")"
TEST_TMP="${TEST_TMP:A}"
trap 'rm -rf -- "$TEST_TMP"' EXIT INT TERM
typeset -i PASSED=0
typeset -i FAILED=0
unset CODEX_HOME CLAUDE_CONFIG_DIR

pass() {
  echo "[pass] $1"
  (( PASSED += 1 ))
}

fail() {
  echo "[fail] $1" >&2
  (( FAILED += 1 ))
}

realpath_of() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

# targets: comma-separated agents for the fixture skill "alpha".
create_fixture() {
  local label="$1"
  local targets="${2:-codex}"
  CASE_ROOT="$TEST_TMP/$label"
  CASE_REPO="$CASE_ROOT/repo"
  CASE_HOME="$CASE_ROOT/home"
  CASE_CODEX="$CASE_HOME/.codex/skills"
  CASE_CLAUDE="$CASE_HOME/.claude/skills"
  CASE_AGENTS="$CASE_HOME/.agents/skills"
  CASE_PLUGIN_CACHE="$CASE_HOME/.codex/plugins/cache"
  CASE_REGISTRY="$CASE_REPO/agents/skills.json"
  mkdir -p "$CASE_REPO/scripts" "$CASE_REPO/agents/skills/alpha" "$CASE_REPO/.codex" "$CASE_PLUGIN_CACHE"
  cp "$REPO_ROOT"/scripts/{skills-registry.py,deploy-skills.zsh,check-skills.zsh,finalize-skill.zsh,agent-dirs.zsh} "$CASE_REPO/scripts/"
  chmod +x "$CASE_REPO/scripts/"*
  python3 - "$CASE_REPO" "$targets" <<'PY'
import json
import sys
from pathlib import Path

repo = Path(sys.argv[1])
(repo / "agents/skills/alpha/SKILL.md").write_text(
    "---\nname: alpha\ndescription: Test fixture skill.\n---\n\n# Alpha\n",
    encoding="utf-8",
)
registry = {
    "schema_version": 2,
    "repository": {"url": "test", "visibility": "private", "verified_at": "2026-11-11", "license": "UNLICENSED"},
    "skills": [{
        "name": "alpha",
        "kind": "owned",
        "targets": sys.argv[2].split(","),
        "upstream": "",
        "version": "",
        "license": "UNLICENSED",
        "dependencies": [],
        "notes": "test",
    }],
}
(repo / "agents/skills.json").write_text(json.dumps(registry, indent=2) + "\n", encoding="utf-8")
(repo / ".codex/inventory.json").write_text(
    json.dumps({"schema_version": 1, "plugins": [], "skills": []}) + "\n", encoding="utf-8"
)
PY
}

edit_registry() {
  python3 - "$CASE_REGISTRY" "$1" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text())
exec(sys.argv[2], {"data": data})
path.write_text(json.dumps(data, indent=2) + "\n")
PY
}

case_env() {
  env SKILLS_DOTFILES_DIR="$CASE_REPO" DOTFILES_TARGET_HOME="$CASE_HOME" \
    AGENTS_SKILLS_HOME="$CASE_AGENTS" "$@"
}

run_deploy() { case_env "$CASE_REPO/scripts/deploy-skills.zsh" "$@"; }
run_check() { case_env "$CASE_REPO/scripts/check-skills.zsh" "$@"; }
run_finalize() { case_env "$CASE_REPO/scripts/finalize-skill.zsh" alpha; }

create_fixture new-link
if run_deploy --non-interactive >/dev/null && [[ -L "$CASE_CODEX/alpha" ]] \
  && [[ "$(realpath_of "$CASE_CODEX/alpha")" == "$(realpath_of "$CASE_REPO/agents/skills/alpha")" ]]; then
  pass "new per-skill symlink"
else
  fail "new per-skill symlink"
fi

if output="$(run_deploy --non-interactive)" && [[ "$output" == *"already linked"* ]] && run_check >/dev/null; then
  pass "idempotent rerun and passing check"
else
  fail "idempotent rerun and passing check"
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
  pass "broken symlink outside the checkout is preserved"
else
  fail "broken symlink outside the checkout is preserved"
fi

create_fixture stale-own-link
mkdir -p "$CASE_CODEX"
ln -s "${CASE_REPO:A}/.codex/skills/alpha" "$CASE_CODEX/alpha"
if output="$(run_deploy --dry-run)" && [[ "$output" == *"would relink"* ]] \
  && [[ "$(readlink "$CASE_CODEX/alpha")" == *"/.codex/skills/alpha" ]] \
  && run_deploy --non-interactive >/dev/null \
  && [[ "$(realpath_of "$CASE_CODEX/alpha")" == "$(realpath_of "$CASE_REPO/agents/skills/alpha")" ]] \
  && [[ ! -e "$CASE_HOME/.codex/skill-backups" ]] \
  && ln -s "${CASE_REPO:A}/.codex/skills/renamed" "$CASE_CODEX/renamed" \
  && ln -s "$CASE_ROOT/missing" "$CASE_CODEX/foreign" \
  && run_deploy --non-interactive >/dev/null \
  && [[ ! -L "$CASE_CODEX/renamed" && -L "$CASE_CODEX/foreign" ]]; then
  pass "stale link into the checkout is relinked without backup"
else
  fail "stale link into the checkout is relinked without backup"
fi

create_fixture dry-run
if output="$(run_deploy --dry-run --non-interactive)" && [[ "$output" == *"would link"* ]] && [[ ! -e "$CASE_CODEX/alpha" ]]; then
  pass "dry-run does not mutate HOME"
else
  fail "dry-run does not mutate HOME"
fi

create_fixture unregistered
run_deploy --non-interactive >/dev/null
mkdir -p "$CASE_REPO/agents/skills/rogue"
print -r -- $'---\nname: rogue\ndescription: Rogue.\n---' > "$CASE_REPO/agents/skills/rogue/SKILL.md"
if ! run_check >/dev/null 2>&1; then
  pass "unregistered dotfiles skill fails inspection"
else
  fail "unregistered dotfiles skill fails inspection"
fi

create_fixture duplicate-name
run_deploy --non-interactive >/dev/null
mkdir -p "$CASE_AGENTS/alpha"
cp "$CASE_REPO/agents/skills/alpha/SKILL.md" "$CASE_AGENTS/alpha/SKILL.md"
if ! run_check >/dev/null 2>&1; then
  pass "duplicate discovered skill name fails inspection"
else
  fail "duplicate discovered skill name fails inspection"
fi

create_fixture duplicate-registry
edit_registry 'data["skills"].append(dict(data["skills"][0]))'
if ! run_deploy --non-interactive >/dev/null 2>&1; then
  pass "duplicate registry name fails deployment"
else
  fail "duplicate registry name fails deployment"
fi

create_fixture invalid-targets
edit_registry 'data["skills"][0]["targets"] = ["codex", "cursor"]'
if ! run_deploy --non-interactive >/dev/null 2>&1 && [[ ! -e "$CASE_CODEX/alpha" ]]; then
  pass "unknown target agent fails deployment"
else
  fail "unknown target agent fails deployment"
fi

create_fixture plugin-conflict
mkdir -p "$CASE_PLUGIN_CACHE/provider/1/skills/alpha"
cp "$CASE_REPO/agents/skills/alpha/SKILL.md" "$CASE_PLUGIN_CACHE/provider/1/skills/alpha/SKILL.md"
if ! run_deploy --non-interactive >/dev/null 2>&1 && [[ ! -e "$CASE_CODEX/alpha" ]]; then
  pass "plugin skill collision prevents local link"
else
  fail "plugin skill collision prevents local link"
fi

create_fixture no-agents
command rm -rf -- "$CASE_HOME/.codex"
if output="$(run_deploy --non-interactive)" && [[ "$output" == *"no agent configuration"* ]] \
  && [[ ! -e "$CASE_HOME/.codex" && ! -e "$CASE_HOME/.claude" ]]; then
  pass "no agent present deploys nothing"
else
  fail "no agent present deploys nothing"
fi
if ! run_deploy --agents cursor >/dev/null 2>&1 \
  && run_deploy --agents claude --non-interactive >/dev/null && [[ ! -e "$CASE_CLAUDE/alpha" ]] \
  && run_deploy --agents codex --non-interactive >/dev/null && [[ -L "$CASE_CODEX/alpha" ]]; then
  pass "explicit agents are validated and still respect targets"
else
  fail "explicit agents are validated and still respect targets"
fi

create_fixture claude-codex-only codex
mkdir -p "$CASE_HOME/.claude"
if output="$(run_deploy --non-interactive)" && [[ "$output" == *"for: codex,claude"* ]] \
  && [[ -L "$CASE_CODEX/alpha" && ! -e "$CASE_CLAUDE/alpha" ]] && run_check >/dev/null; then
  pass "Codex-only skill is not linked for Claude"
else
  fail "Codex-only skill is not linked for Claude"
fi

create_fixture claude-both codex,claude
mkdir -p "$CASE_HOME/.claude"
export CLAUDE_CONFIG_DIR="$CASE_ROOT/other-claude-config"
if run_deploy --dry-run >/dev/null && [[ ! -e "$CASE_CLAUDE" ]] \
  && run_deploy --non-interactive >/dev/null \
  && [[ -L "$CASE_CLAUDE/alpha" && -L "$CASE_CODEX/alpha" && ! -e "$CLAUDE_CONFIG_DIR" ]] \
  && [[ "$(readlink "$CASE_CLAUDE/alpha")" == "${CASE_REPO:A}/agents/skills/alpha" ]] \
  && output="$(run_deploy --non-interactive)" && [[ "$output" == *"already linked"* ]] \
  && run_check >/dev/null; then
  pass "shared skill is linked for both agents from one source"
else
  fail "shared skill is linked for both agents from one source"
fi
unset CLAUDE_CONFIG_DIR

rm "$CASE_CLAUDE/alpha"
if ! run_check >/dev/null 2>&1 && run_check --agents codex >/dev/null; then
  pass "check reports a missing link only for agents present"
else
  fail "check reports a missing link only for agents present"
fi

mkdir "$CASE_CLAUDE/alpha"
if ! run_deploy --non-interactive >/dev/null 2>&1 \
  && [[ -d "$CASE_CLAUDE/alpha" && ! -L "$CASE_CLAUDE/alpha" ]] \
  && [[ -z "$(ls -A "$CASE_CLAUDE/alpha")" ]]; then
  pass "Claude deployment preserves an existing skill directory"
else
  fail "Claude deployment preserves an existing skill directory"
fi

mv "$CASE_REPO/agents/skills/alpha" "$CASE_ROOT/original-alpha"
ln -s alpha "$CASE_REPO/agents/skills/alpha"
if ! output="$(run_deploy --dry-run 2>&1)" && [[ "$output" != *"preview complete"* ]]; then
  pass "invalid skill source fails the preview"
else
  fail "invalid skill source fails the preview"
fi

# deploy.sh links the shared instructions for each agent present and fixes stale links.
DEPLOY_HOME="$TEST_TMP/deploy-home"
mkdir -p "$DEPLOY_HOME/.codex" "$DEPLOY_HOME/.claude"
ln -s "${REPO_ROOT:A}/.codex/AGENTS.md" "$DEPLOY_HOME/.codex/AGENTS.md"
if DOTFILES_TARGET_HOME="$DEPLOY_HOME" "$REPO_ROOT/deploy.sh" --no-shell --non-interactive >/dev/null \
  && [[ "$(realpath_of "$DEPLOY_HOME/.codex/AGENTS.md")" == "$(realpath_of "$REPO_ROOT/agents/AGENTS.md")" ]] \
  && [[ "$(realpath_of "$DEPLOY_HOME/.claude/CLAUDE.md")" == "$(realpath_of "$REPO_ROOT/agents/AGENTS.md")" ]] \
  && [[ -L "$DEPLOY_HOME/.claude/skills/write-readable-japanese" && ! -e "$DEPLOY_HOME/.claude/skills/daily-neruwa" ]] \
  && [[ -L "$DEPLOY_HOME/.codex/skills/daily-neruwa" && ! -e "$DEPLOY_HOME/.zshrc" ]]; then
  pass "deploy.sh shares instructions and skills across agents"
else
  fail "deploy.sh shares instructions and skills across agents"
fi

# Old deployments linked all of ~/.config to the checkout; replacing ~/.config/<name>
# would then move the source itself aside and leave a self-referencing link.
SELF_ROOT="$TEST_TMP/self-link"
mkdir -p "$SELF_ROOT/repo/.config/zsh" "$SELF_ROOT/repo/scripts" "$SELF_ROOT/home"
cp "$REPO_ROOT/deploy.sh" "$SELF_ROOT/repo/"
cp "$REPO_ROOT/scripts/agent-dirs.zsh" "$SELF_ROOT/repo/scripts/"
print -r -- "# zsh" > "$SELF_ROOT/repo/.config/zsh/init.zsh"
ln -s "$SELF_ROOT/repo/.config" "$SELF_ROOT/home/.config"
if output="$(DOTFILES_TARGET_HOME="$SELF_ROOT/home" "$SELF_ROOT/repo/deploy.sh" --non-interactive 2>&1)" \
  && [[ "$output" == *"already in place through a parent symlink: $SELF_ROOT/home/.config/zsh"* ]] \
  && [[ -d "$SELF_ROOT/repo/.config/zsh" && ! -L "$SELF_ROOT/repo/.config/zsh" ]] \
  && [[ -f "$SELF_ROOT/repo/.config/zsh/init.zsh" ]]; then
  pass "deploy.sh leaves sources alone when ~/.config links into the checkout"
else
  fail "deploy.sh leaves sources alone when ~/.config links into the checkout"
fi

create_fixture project-skill-elsewhere
python3 - "$CASE_REPO/.codex/inventory.json" "$CASE_ROOT/vault/memory" <<'PY'
import json, sys
path, source = sys.argv[1:]
data = json.load(open(path))
data["skills"].append({"name": "memory", "kind": "project", "enabled": True, "local_path": source,
    "destination": "~/.codex/skills/memory", "upstream": "", "version": "", "plugin_id": "",
    "license": "", "dependencies": [], "notes": "test"})
open(path, "w").write(json.dumps(data))
PY
run_deploy --non-interactive >/dev/null
if output="$(run_check 2>&1)" && [[ "$output" == *"not available on this machine"* ]] \
  && ln -s "$CASE_ROOT/vault/memory" "$CASE_CODEX/memory" && ! run_check >/dev/null 2>&1; then
  pass "project skill missing on this machine warns, a dangling link fails"
else
  fail "project skill missing on this machine warns, a dangling link fails"
fi

init_fixture_repo() {
  run_deploy --non-interactive >/dev/null
  git -C "$CASE_REPO" init -q
  git -C "$CASE_REPO" config user.name "Skill Test"
  git -C "$CASE_REPO" config user.email "skill-test@example.invalid"
  git -C "$CASE_REPO" add .
  git -C "$CASE_REPO" commit -q -m "test: initial fixture"
  print '\nUpdated.\n' >> "$CASE_REPO/agents/skills/alpha/SKILL.md"
  touch "$CASE_REPO/unrelated.txt"
}

create_fixture finalize-scope
init_fixture_repo
if run_finalize >/dev/null && [[ -z "$(git -C "$CASE_REPO" diff --cached --name-only)" ]] \
  && [[ -n "$(git -C "$CASE_REPO" status --short -- unrelated.txt)" ]] \
  && [[ "$(git -C "$CASE_REPO" show --format= --name-only HEAD)" == "agents/skills/alpha/SKILL.md" ]] \
  && [[ "$(git -C "$CASE_REPO" log -1 --format=%s)" == "update: update alpha skill" ]]; then
  pass "finalize commits only the target change"
else
  fail "finalize commits only the target change"
fi

create_fixture finalize-staged-refusal
init_fixture_repo
git -C "$CASE_REPO" add unrelated.txt
before="$(git -C "$CASE_REPO" rev-parse HEAD)"
if ! run_finalize >/dev/null 2>&1 && [[ "$(git -C "$CASE_REPO" rev-parse HEAD)" == "$before" ]] \
  && [[ "$(git -C "$CASE_REPO" diff --cached --name-only)" == "unrelated.txt" ]]; then
  pass "finalize refuses unrelated staged changes"
else
  fail "finalize refuses unrelated staged changes"
fi

if [[ -d "$REPO_ROOT/agents/skills/daily-neruwa" ]] && ! find "$REPO_ROOT/agents/skills/daily-neruwa" \( -name .git -o -name .venv -o -name .pytest_cache -o -name __pycache__ \) -print -quit | read -r; then
  pass "daily-neruwa snapshot excludes Git and caches"
else
  fail "daily-neruwa snapshot excludes Git and caches"
fi

echo "[result] passed=$PASSED failed=$FAILED"
(( FAILED == 0 ))
