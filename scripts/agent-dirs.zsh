# Where each coding agent keeps its configuration, shared by deploy.sh and the
# skill scripts. Source this file; it defines functions only.
#
# DOTFILES_TARGET_HOME redirects every agent to that home (used by tests and
# previews). Otherwise each agent's own override is honored, as the agent
# itself would: CODEX_HOME for Codex and CLAUDE_CONFIG_DIR for Claude Code.

typeset -ga SUPPORTED_AGENTS=(codex claude)

agent_config_dir() {
  local agent="$1"
  local home="$2"
  local override=""

  case "$agent" in
    codex) override="${CODEX_HOME:-}"; home="$home/.codex" ;;
    claude) override="${CLAUDE_CONFIG_DIR:-}"; home="$home/.claude" ;;
    *) return 1 ;;
  esac
  if [[ -z "${DOTFILES_TARGET_HOME:-}" && -n "$override" ]]; then
    print -r -- "$override"
  else
    print -r -- "$home"
  fi
}

# Print the agents to deploy as a comma-separated list. An explicit list
# (`codex,claude`) is validated; without one, an agent counts as present on
# this machine when its configuration directory exists.
resolve_agents() {
  local requested="$1"
  local home="$2"
  local agent
  local -a result=()

  if [[ -n "$requested" ]]; then
    for agent in "${(@s:,:)requested}"; do
      if (( ! ${SUPPORTED_AGENTS[(Ie)$agent]} )); then
        echo "[error] unknown agent: $agent (supported: ${(j:, :)SUPPORTED_AGENTS})" >&2
        return 1
      fi
      (( ${result[(Ie)$agent]} )) || result+=("$agent")
    done
  else
    for agent in "${SUPPORTED_AGENTS[@]}"; do
      [[ -d "$(agent_config_dir "$agent" "$home")" ]] && result+=("$agent")
    done
  fi
  print -r -- "${(j:,:)result}"
}
