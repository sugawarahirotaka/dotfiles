#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

SCRIPT_PATH="${(%):-%N}"
SCRIPT_DIR="${SCRIPT_PATH:A:h}"
DOTFILES_DIR="${CODEX_DOTFILES_DIR:-${SCRIPT_DIR:h}}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"
REGISTRY="${CODEX_SKILLS_REGISTRY:-$DOTFILES_DIR/.codex/skills-registry.json}"
SKILLS_HOME="${CODEX_SKILLS_HOME:-$TARGET_HOME/.codex/skills}"
PLUGIN_CACHE="${CODEX_PLUGIN_CACHE:-$TARGET_HOME/.codex/plugins/cache}"
BACKUP_PARENT="${CODEX_SKILLS_BACKUP_ROOT:-$TARGET_HOME/.codex/skill-backups}"
DRY_RUN=0
NON_INTERACTIVE=0
typeset -i FAILURES=0
typeset -A PLUGIN_SKILLS

usage() {
  echo "usage: ${0:t} [--dry-run] [--non-interactive]" >&2
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --non-interactive) NON_INTERACTIVE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; echo "[error] unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

if [[ -z "$TARGET_HOME" || "$TARGET_HOME" == "/" || -z "$SKILLS_HOME" || "$SKILLS_HOME" == "/" ]]; then
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
  local name
  while IFS= read -r name; do
    [[ -n "$name" ]] && PLUGIN_SKILLS[$name]=1
  done < <(python3 "$SCRIPT_DIR/codex-skills-registry.py" \
    --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" \
    plugin-names --cache-root "$PLUGIN_CACHE")
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
    mkdir -p -- "${backup:h}"
    mv -- "$destination" "$backup"
    echo "[backup] $destination -> $backup"
  fi

  if (( DRY_RUN )); then
    echo "[dry-run] would link: $destination -> $source_real"
    return 0
  fi
  mkdir -p -- "$SKILLS_HOME"
  ln -s -- "$source_real" "$destination"
  echo "[linked] $destination -> $source_real"
}

python3 "$SCRIPT_DIR/codex-skills-registry.py" \
  --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" validate >/dev/null
load_plugin_names

while IFS= read -r -d $'\0' name && IFS= read -r -d $'\0' source; do
  if ! link_skill "$name" "$source"; then
    (( FAILURES += 1 ))
  fi
done < <(python3 "$SCRIPT_DIR/codex-skills-registry.py" \
  --repo "$DOTFILES_DIR" --registry "$REGISTRY" --home "$TARGET_HOME" managed-links)

if (( FAILURES > 0 )); then
  echo "[failed] $FAILURES managed skill link(s) were not changed" >&2
  exit 1
fi
echo "[ok] all managed Codex skill links are in place"
