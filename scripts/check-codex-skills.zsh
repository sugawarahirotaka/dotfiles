#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
DOTFILES_DIR="${CODEX_DOTFILES_DIR:-${SCRIPT_DIR:h}}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
REGISTRY="${CODEX_SKILLS_REGISTRY:-$DOTFILES_DIR/.codex/skills-registry.json}"
CODEX_SKILLS_HOME="${CODEX_SKILLS_HOME:-$TARGET_HOME/.codex/skills}"
AGENTS_SKILLS_HOME="${AGENTS_SKILLS_HOME:-$TARGET_HOME/.agents/skills}"
PLUGIN_CACHE="${CODEX_PLUGIN_CACHE:-$TARGET_HOME/.codex/plugins/cache}"

if [[ -z "$TARGET_HOME" || "$TARGET_HOME" == "/" ]]; then
  echo "[error] invalid HOME" >&2
  exit 1
fi

exec python3 "$SCRIPT_DIR/codex-skills-registry.py" \
  --repo "$DOTFILES_DIR" \
  --registry "$REGISTRY" \
  --home "$TARGET_HOME" \
  check \
  --codex-skills-root "$CODEX_SKILLS_HOME" \
  --agents-skills-root "$AGENTS_SKILLS_HOME" \
  --plugin-cache-root "$PLUGIN_CACHE"
