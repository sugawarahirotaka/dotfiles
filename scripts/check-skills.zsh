#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
DOTFILES_DIR="${SKILLS_DOTFILES_DIR:-${SCRIPT_DIR:h}}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
REGISTRY="${SKILLS_REGISTRY:-$DOTFILES_DIR/agents/skills.json}"
INVENTORY="${CODEX_INVENTORY:-$DOTFILES_DIR/.codex/inventory.json}"
AGENTS_SKILLS_HOME="${AGENTS_SKILLS_HOME:-$TARGET_HOME/.agents/skills}"
REQUESTED_AGENTS=""

source "$SCRIPT_DIR/agent-dirs.zsh"

case "${1:-}" in
  --agents) REQUESTED_AGENTS="${2:-}" ;;
  --agents=*) REQUESTED_AGENTS="${1#--agents=}" ;;
  "") ;;
  *) echo "usage: ${0:t} [--agents codex,claude]" >&2; exit 2 ;;
esac

if [[ -z "$TARGET_HOME" || "$TARGET_HOME" == "/" ]]; then
  echo "[error] invalid HOME" >&2
  exit 1
fi

typeset -a check_args=()
agent_list="$(resolve_agents "$REQUESTED_AGENTS" "$TARGET_HOME")"
for agent in "${(@s:,:)agent_list}"; do
  [[ -n "$agent" ]] || continue
  check_args+=(--agent-root "$agent=$(agent_config_dir "$agent" "$TARGET_HOME")/skills")
  if [[ "$agent" == codex ]]; then
    check_args+=(--plugin-cache-root "${CODEX_PLUGIN_CACHE:-$(agent_config_dir codex "$TARGET_HOME")/plugins/cache}")
  fi
done

exec python3 "$SCRIPT_DIR/skills-registry.py" \
  --repo "$DOTFILES_DIR" \
  --registry "$REGISTRY" \
  --inventory "$INVENTORY" \
  --home "$TARGET_HOME" \
  check \
  --agents-skills-root "$AGENTS_SKILLS_HOME" \
  "${check_args[@]}"
