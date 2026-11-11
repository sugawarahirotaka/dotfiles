#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
DOTFILES_DIR="${CODEX_DOTFILES_DIR:-${SCRIPT_DIR:h}}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
REGISTRY="${CODEX_SKILLS_REGISTRY:-$DOTFILES_DIR/.codex/skills-registry.json}"
PLUGIN_CACHE="${CODEX_PLUGIN_CACHE:-$TARGET_HOME/.codex/plugins/cache}"
AGENT=Codex
LINK_ARGS=(managed-links)
DRY_RUN=0
NON_INTERACTIVE=0
typeset -i FAILURES=0
typeset -A PLUGIN_SKILLS

usage() {
  echo "usage: ${0:t} [--claude] [--dry-run] [--non-interactive]" >&2
}

while (( $# > 0 )); do
  case "$1" in
    --claude) AGENT=Claude ;;
    --dry-run) DRY_RUN=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; echo "[error] unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ "$AGENT" == Claude ]]; then
  CLAUDE_DIR="$TARGET_HOME/.claude"
  if [[ -z "${DOTFILES_TARGET_HOME:-}" ]]; then
    CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$CLAUDE_DIR}"
  fi
  SKILLS_HOME="$CLAUDE_DIR/skills"
  BACKUP_PARENT="$CLAUDE_DIR/skill-backups"
  LINK_ARGS+=(--claude)
else
  SKILLS_HOME="${CODEX_SKILLS_HOME:-$TARGET_HOME/.codex/skills}"
  BACKUP_PARENT="${CODEX_SKILLS_BACKUP_ROOT:-$TARGET_HOME/.codex/skill-backups}"
fi

if [[ -z "$TARGET_HOME" || "${TARGET_HOME:A}" == "/" || "${SKILLS_HOME:A}" == "/" ]]; then
  echo "[error] invalid HOME or skills target" >&2
  exit 1
fi

TARGET_HOME="${TARGET_HOME:A}"
DOTFILES_DIR="${DOTFILES_DIR:A}"
SKILLS_HOME="${SKILLS_HOME:A}"
BACKUP_PARENT="${BACKUP_PARENT:A}"

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
  names="$(python3 "$SCRIPT_DIR/codex-skills-registry.py" \
    --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" \
    plugin-names --cache-root "$PLUGIN_CACHE")" || return 1
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

MANAGED_LINKS="$(python3 "$SCRIPT_DIR/codex-skills-registry.py" \
  --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" "${LINK_ARGS[@]}")"
if [[ "$AGENT" == Codex ]]; then
  load_plugin_names
fi

while IFS= read -r -d $'\0' name && IFS= read -r -d $'\0' source; do
  if ! link_skill "$name" "$source"; then
    (( FAILURES += 1 ))
  fi
done <<< "$MANAGED_LINKS"

if (( FAILURES > 0 )); then
  echo "[failed] $FAILURES managed skill link(s) were not changed" >&2
  exit 1
fi
if (( DRY_RUN )); then
  echo "[ok] $AGENT skill link preview complete"
else
  echo "[ok] all managed $AGENT skill links are in place"
fi
