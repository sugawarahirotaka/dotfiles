#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

SCRIPT_PATH="${(%):-%N}"
DOTFILES_DIR="${SCRIPT_PATH:A:h}"
TARGET_HOME="${DOTFILES_TARGET_HOME:-$HOME}"

if [[ -z "$TARGET_HOME" || "$TARGET_HOME" == "/" ]]; then
  echo "[error] invalid deploy target: $TARGET_HOME" >&2
  exit 1
fi

TARGET_HOME="${TARGET_HOME:A}"

# ホーム直下へ配置するファイル・ディレクトリ。
# リポジトリ直下を一括処理せず、意図したものだけを配布する。
HOME_LINKS=(
  ".gitconfig"
  ".hammerspoon"
  ".latexmkrc"
  ".npmrc"
  ".tmux.conf"
  ".yatexrc"
  ".zprofile"
  ".zshenv"
  ".zshrc"
  "codex-remote-toggle.sh"
)

# ~/.config 全体ではなく、管理対象のサブディレクトリだけを配置する。
CONFIG_LINKS=(
  "ctpv"
  "htop"
  "karabiner"
  "kitty"
  "lf"
  "nvim"
  "sheldon"
  "starship.toml"
  "zsh"
)

sync_git_submodules() {
  if [[ ! -f "$DOTFILES_DIR/.gitmodules" ]]; then
    return 0
  fi

  if ! command -v git >/dev/null 2>&1; then
    echo "[warn] git command not found; skip submodule sync"
    return 0
  fi

  echo "[submodule] sync urls"
  git -C "$DOTFILES_DIR" submodule sync --recursive

  echo "[submodule] update/init"
  git -C "$DOTFILES_DIR" submodule update --init --recursive
}

resolve_realpath() {
  local path="$1"
  local dir target
  local -i hops=0

  [[ -z "$path" ]] && return 1
  [[ "$path" != /* ]] && path="$PWD/$path"

  while [[ -L "$path" ]]; do
    (( hops += 1 ))
    (( hops > 40 )) && return 1

    target="$(readlink "$path")" || return 1
    if [[ "$target" == /* ]]; then
      path="$target"
    else
      dir="${path:h}"
      path="$dir/$target"
    fi
  done

  [[ -e "$path" ]] || return 1
  printf '%s\n' "${path:A}"
}

confirm_replace() {
  local dst="$1"
  local answer

  if [[ -r /dev/tty ]]; then
    printf "'%s' already exists. Move to backup and replace? [y/N]: " "$dst" > /dev/tty
    if ! read -r answer < /dev/tty; then
      answer="n"
    fi
    printf '\n' > /dev/tty
  else
    answer="n"
    echo "[skip] no tty available: $dst"
  fi

  [[ "$answer" =~ ^[Yy]$ ]]
}

link_item() {
  local src="$1"
  local dst="$2"
  local src_path src_real link_target dst_dir dst_real backup

  if [[ ! -e "$src" && ! -L "$src" ]]; then
    echo "[skip] source not found: $src"
    return 0
  fi

  src_path="${src:A}"

  if [[ "$src_path" == "$dst" ]]; then
    echo "[skip] source and destination are literally the same path: $src_path"
    return 0
  fi

  if ! src_real="$(resolve_realpath "$src" 2>/dev/null)"; then
    echo "[skip] source is broken or cyclic symlink: $src"
    return 0
  fi

  if [[ -L "$dst" ]]; then
    link_target="$(readlink "$dst")" || link_target=""

    if [[ -n "$link_target" ]]; then
      if [[ "$link_target" != /* ]]; then
        dst_dir="${dst:h}"
        link_target="$dst_dir/$link_target"
      fi

      if dst_real="$(resolve_realpath "$link_target" 2>/dev/null)" \
        && [[ "$dst_real" == "$src_real" ]]; then
        echo "[ok] already linked: $dst -> $link_target"
        return 0
      fi
    fi

    echo "[warn] destination is a broken or different symlink: $dst"
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    if ! confirm_replace "$dst"; then
      echo "[skip] keep existing: $dst"
      return 0
    fi

    backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$dst" "$backup"
    echo "[backup] $dst -> $backup"
  fi

  mkdir -p -- "${dst:h}"
  ln -s -- "$src_path" "$dst"
  echo "[linked] $dst -> $src_path"
}

main() {
  local name

  if [[ "${DOTFILES_SKIP_SUBMODULES:-0}" == "1" ]]; then
    echo "[submodule] skipped by DOTFILES_SKIP_SUBMODULES=1"
  else
    sync_git_submodules
  fi

  for name in "${HOME_LINKS[@]}"; do
    link_item "$DOTFILES_DIR/$name" "$TARGET_HOME/$name"
  done

  for name in "${CONFIG_LINKS[@]}"; do
    link_item "$DOTFILES_DIR/.config/$name" "$TARGET_HOME/.config/$name"
  done
}

main "$@"
