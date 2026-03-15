#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL
IFS=$'\n\t'

SCRIPT_PATH="${(%):-%N}"
DOTFILES_DIR="${SCRIPT_PATH:A:h}"

EXCLUDES=(
  "."
  ".."
  ".git"
  ".gitignore"
  "deploy.sh"
  "README.md"
  ".DS_Store"
)

# 配布対象にしたくないものをパターン除外
EXCLUDE_PATTERNS=(
  ".zshrc.v*"
  ".zshrc.oroshi*"
)

is_excluded() {
  local name="$1"
  local ex

  for ex in "${EXCLUDES[@]}"; do
    [[ "$name" == "$ex" ]] && return 0
  done

  for ex in "${EXCLUDE_PATTERNS[@]}"; do
    [[ "$name" == ${~ex} ]] && return 0
  done

  return 1
}

resolve_realpath() {
  local path="$1"
  local dir target
  local -i hops=0

  [[ -z "$path" ]] && return 1

  # 相対パスなら絶対化
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

while IFS= read -r -d '' src; do
  name="${src:t}"

  if is_excluded "$name"; then
    continue
  fi

  src_path="${src:A}"
  dst="$HOME/$name"

  # 同じ文字列パスなら何もしない
  if [[ "$src_path" == "$dst" ]]; then
    echo "[skip] source and destination are literally the same path: $src_path"
    continue
  fi

  # source が壊れたリンクならスキップ
  if ! src_real="$(resolve_realpath "$src" 2>/dev/null)"; then
    echo "[skip] source is broken or cyclic symlink: $src"
    continue
  fi

  # 既に正しいリンクなら何もしない
  if [[ -L "$dst" ]]; then
    link_target="$(readlink "$dst")" || link_target=""

    if [[ -n "$link_target" ]]; then
      if [[ "$link_target" != /* ]]; then
        dst_dir="${dst:h}"
        link_target="$dst_dir/$link_target"
      fi

      if dst_real="$(resolve_realpath "$link_target" 2>/dev/null)"; then
        if [[ "$dst_real" == "$src_real" ]]; then
          echo "[ok] already linked: $dst -> $link_target"
          continue
        fi
      fi
    fi

    echo "[warn] destination is a broken or different symlink: $dst"
  fi

  # 既存ファイル/ディレクトリ/リンクは確認して退避
  if [[ -e "$dst" || -L "$dst" ]]; then
    if ! confirm_replace "$dst"; then
      echo "[skip] keep existing: $dst"
      continue
    fi

    backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
    mv -- "$dst" "$backup"
    echo "[backup] $dst -> $backup"
  fi

  ln -s -- "$src_path" "$dst"
  echo "[linked] $dst -> $src_path"

done < <(find "$DOTFILES_DIR" -mindepth 1 -maxdepth 1 -print0)
