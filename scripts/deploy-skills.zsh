#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
DOTFILES_DIR="${SKILLS_DOTFILES_DIR:-${SCRIPT_DIR:h}}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
REGISTRY="${SKILLS_REGISTRY:-$DOTFILES_DIR/agents/skills.json}"
INVENTORY="${CODEX_INVENTORY:-$DOTFILES_DIR/.codex/inventory.json}"
REQUESTED_AGENTS=""
DRY_RUN=0
NON_INTERACTIVE=0
typeset -i FAILURES=0
typeset -A PLUGIN_SKILLS
typeset -A MANAGED_NAMES

source "$SCRIPT_DIR/agent-dirs.zsh"

usage() {
  echo "usage: ${0:t} [--agents codex,claude] [--dry-run] [--non-interactive]" >&2
  echo "Without --agents, deploys to every agent whose config directory exists." >&2
}

while (( $# > 0 )); do
  case "$1" in
    --agents)
      (( $# >= 2 )) || { usage; exit 2; }
      REQUESTED_AGENTS="$2"
      shift
      ;;
    --agents=*) REQUESTED_AGENTS="${1#--agents=}" ;;
    --dry-run) DRY_RUN=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; echo "[error] unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$TARGET_HOME" || "${TARGET_HOME:A}" == "/" ]]; then
  echo "[error] invalid HOME" >&2
  exit 1
fi
TARGET_HOME="${TARGET_HOME:A}"
DOTFILES_DIR="${DOTFILES_DIR:A}"

registry() {
  python3 "$SCRIPT_DIR/skills-registry.py" \
    --repo "$DOTFILES_DIR" --registry "$REGISTRY" --inventory "$INVENTORY" --home "$TARGET_HOME" "$@"
}

resolve_realpath() {
  local candidate="$1"
  local dir target
  local -i hops=0

  [[ -z "$candidate" ]] && return 1
  [[ "$candidate" != /* ]] && candidate="$PWD/$candidate"
  while [[ -L "$candidate" ]]; do
    (( hops += 1 ))
    (( hops > 40 )) && return 1
    target="$(readlink "$candidate")" || return 1
    if [[ "$target" == /* ]]; then
      candidate="$target"
    else
      dir="${candidate:h}"
      candidate="$dir/$target"
    fi
  done
  [[ -e "$candidate" ]] || return 1
  printf '%s\n' "${candidate:A}"
}

confirm_replace() {
  local destination="$1"
  local answer

  if (( NON_INTERACTIVE )); then
    return 1
  fi
  if [[ -r /dev/tty ]]; then
    printf "'%s' already exists. Move it to a timestamped backup and replace it? [y/N]: " "$destination" > /dev/tty
    read -r answer < /dev/tty || answer="n"
    printf '\n' > /dev/tty
    [[ "$answer" =~ ^[Yy]$ ]]
    return
  fi
  return 1
}

load_plugin_names() {
  local name names
  PLUGIN_SKILLS=()
  names="$(registry plugin-names --cache-root "$1")" || return 1
  while IFS= read -r name; do
    [[ -n "$name" ]] && PLUGIN_SKILLS[$name]=1
  done <<< "$names"
  return 0
}

backup_path_for() {
  local name="$1"
  local stamp candidate
  stamp="$(date +%Y%m%d%H%M%S)"
  candidate="$BACKUP_PARENT/$stamp/$name"
  while [[ -e "$candidate" || -L "$candidate" ]]; do
    sleep 1
    stamp="$(date +%Y%m%d%H%M%S)"
    candidate="$BACKUP_PARENT/$stamp/$name"
  done
  printf '%s\n' "$candidate"
}

# A broken link that points into this checkout was made by an earlier
# deployment before a source moved; it holds nothing worth backing up.
is_stale_own_link() {
  local destination="$1"
  [[ -L "$destination" && ! -e "$destination" && "$(readlink "$destination")" == "$DOTFILES_DIR/"* ]]
}

link_skill() {
  local name="$1"
  local source="$2"
  local destination="$SKILLS_HOME/$name"
  local source_real destination_real backup

  if [[ -n "${PLUGIN_SKILLS[$name]-}" ]]; then
    echo "[conflict] plugin already provides skill '$name'; no link created: $destination" >&2
    return 1
  fi
  if [[ ! -d "$source" || ! -f "$source/SKILL.md" ]]; then
    echo "[error] managed skill source is incomplete: $source" >&2
    return 1
  fi
  source_real="$(resolve_realpath "$source")" || {
    echo "[error] managed skill source is broken: $source" >&2
    return 1
  }

  if is_stale_own_link "$destination"; then
    if (( DRY_RUN )); then
      echo "[dry-run] would relink stale link: $destination -> $source_real (was $(readlink "$destination"))"
      return 0
    fi
    rm -f -- "$destination" || return 1
    python3 -c 'import os, sys; os.symlink(sys.argv[1], sys.argv[2])' \
      "$source_real" "$destination" || return 1
    echo "[relinked] $destination -> $source_real"
    return 0
  fi

  if [[ -L "$destination" ]]; then
    if destination_real="$(resolve_realpath "$destination" 2>/dev/null)"; then
      if [[ "$destination_real" == "$source_real" ]]; then
        echo "[ok] already linked: $destination -> $source_real"
        return 0
      fi
      echo "[conflict] different symlink: $destination -> $(readlink "$destination") (resolved: $destination_real; expected: $source_real)" >&2
    else
      echo "[conflict] broken symlink: $destination -> $(readlink "$destination")" >&2
    fi
  elif [[ -e "$destination" ]]; then
    echo "[conflict] real file or directory exists: $destination" >&2
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    if (( DRY_RUN )); then
      echo "[dry-run] would require backup before linking: $destination"
      return 1
    fi
    if ! confirm_replace "$destination"; then
      if (( NON_INTERACTIVE )); then
        echo "[error] non-interactive mode will not replace: $destination" >&2
      else
        echo "[skip] kept existing destination: $destination" >&2
      fi
      return 1
    fi
    backup="$(backup_path_for "$name")"
    mkdir -p -- "${backup:h}" || return 1
    mv -- "$destination" "$backup" || return 1
    echo "[backup] $destination -> $backup"
  fi

  if (( DRY_RUN )); then
    echo "[dry-run] would link: $destination -> $source_real"
    return 0
  fi
  mkdir -p -- "$SKILLS_HOME" || return 1
  python3 -c 'import os, sys; os.symlink(sys.argv[1], sys.argv[2])' \
    "$source_real" "$destination" || return 1
  echo "[linked] $destination -> $source_real"
}

deploy_agent() {
  local agent="$1"
  local config_dir managed_links name source

  config_dir="$(agent_config_dir "$agent" "$TARGET_HOME")"
  SKILLS_HOME="${config_dir:A}/skills"
  BACKUP_PARENT="${config_dir:A}/skill-backups"
  if [[ "${SKILLS_HOME:A}" == "/" ]]; then
    echo "[error] invalid skills target for $agent: $SKILLS_HOME" >&2
    return 1
  fi

  managed_links="$(registry managed-links --agent "$agent")" || return 1
  PLUGIN_SKILLS=()
  if [[ "$agent" == codex ]]; then
    load_plugin_names "${CODEX_PLUGIN_CACHE:-$config_dir/plugins/cache}" || return 1
  fi

  echo "[$agent] $SKILLS_HOME"
  MANAGED_NAMES=()
  while IFS= read -r -d $'\0' name && IFS= read -r -d $'\0' source; do
    MANAGED_NAMES[$name]=1
    if ! link_skill "$name" "$source"; then
      (( FAILURES += 1 ))
    fi
  done <<< "$managed_links"
  prune_stale_links
}

# Remove dangling links into this checkout left by a renamed or deleted skill.
prune_stale_links() {
  local link
  [[ -d "$SKILLS_HOME" ]] || return 0
  for link in "$SKILLS_HOME"/*(N@); do
    [[ -z "${MANAGED_NAMES[${link:t}]-}" ]] || continue
    is_stale_own_link "$link" || continue
    if (( DRY_RUN )); then
      echo "[dry-run] would remove stale link: $link -> $(readlink "$link")"
    else
      rm -f -- "$link" || return 1
      echo "[removed] stale link: $link"
    fi
  done
}

AGENT_LIST="$(resolve_agents "$REQUESTED_AGENTS" "$TARGET_HOME")"
if [[ -z "$AGENT_LIST" ]]; then
  echo "[skip] no agent configuration found (~/.codex, ~/.claude); use --agents to deploy anyway"
  exit 0
fi

for agent in "${(@s:,:)AGENT_LIST}"; do
  deploy_agent "$agent"
done

if (( FAILURES > 0 )); then
  echo "[failed] $FAILURES managed skill link(s) were not changed" >&2
  exit 1
fi
if (( DRY_RUN )); then
  echo "[ok] skill link preview complete for: $AGENT_LIST"
else
  echo "[ok] managed skill links are in place for: $AGENT_LIST"
fi
