#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL

SCRIPT_PATH="${(%):-%N}"
REPOSITORY_ROOT="${SCRIPT_PATH:A:h:h}"
DOTFILES_TEST_TMP_BASE="${TMPDIR:-/tmp}"
DOTFILES_TEST_ROOT="$(mktemp -d "${DOTFILES_TEST_TMP_BASE%/}/dotfiles-zsh-check.XXXXXX")"

cleanup() {
  if [[ -n "${DOTFILES_TEST_ROOT:-}" \
    && -d "$DOTFILES_TEST_ROOT" \
    && "${DOTFILES_TEST_ROOT:t}" == dotfiles-zsh-check.* ]]; then
    command rm -rf -- "$DOTFILES_TEST_ROOT"
  fi
}
trap cleanup EXIT

fail() {
  print -u2 -r -- "[失敗] $1"
  exit 1
}

typeset -a syntax_files
typeset syntax_file required_link link_path expected_path
typeset startup_output fallback_output starship_output starship_character
typeset starship_prompt_character starship_gpu_output starship_error_file
typeset -a starship_lines
typeset sheldon_source_data_dir sheldon_source_config_dir
typeset sheldon_test_data_dir sheldon_lock_text
typeset host_fixture_dir host_output
syntax_files=(
  "$REPOSITORY_ROOT/.zshenv"
  "$REPOSITORY_ROOT/.zprofile"
  "$REPOSITORY_ROOT/.zshrc"
  "$REPOSITORY_ROOT/.zshrc.private.example"
  "$REPOSITORY_ROOT/deploy.sh"
  "$REPOSITORY_ROOT"/.config/zsh/**/*.zsh(N)
)

for syntax_file in "${syntax_files[@]}"; do
  /bin/zsh -n -- "$syntax_file" || fail "構文エラー: $syntax_file"
done

DOTFILES_TARGET_HOME="$DOTFILES_TEST_ROOT" \
  "$REPOSITORY_ROOT/deploy.sh" > "$DOTFILES_TEST_ROOT/deploy-first.log"
DOTFILES_TARGET_HOME="$DOTFILES_TEST_ROOT" \
  "$REPOSITORY_ROOT/deploy.sh" > "$DOTFILES_TEST_ROOT/deploy-second.log"

typeset -a required_links
required_links=(
  .zshenv
  .zprofile
  .zshrc
  .config/sheldon
  .config/starship.toml
  .config/zsh
)

for required_link in "${required_links[@]}"; do
  link_path="$DOTFILES_TEST_ROOT/$required_link"
  expected_path="$REPOSITORY_ROOT/$required_link"

  [[ -L "$link_path" ]] \
    || fail "シンボリックリンクがありません: $required_link"
  [[ "${link_path:A}" == "${expected_path:A}" ]] \
    || fail "リンク先が一致しません: $required_link"
done

host_fixture_dir="$DOTFILES_TEST_ROOT/host-fixture"
mkdir -p -- "$host_fixture_dir/hosts"
print -r -- 'typeset -g DOTFILES_TEST_HOST_PROFILE=macos' \
  > "$host_fixture_dir/hosts/macos.zsh"
print -r -- 'typeset -g DOTFILES_TEST_HOST_PROFILE=lab-server' \
  > "$host_fixture_dir/hosts/lab-server.zsh"

host_output="$(
  ZDOTDIR="$DOTFILES_TEST_ROOT/empty-zdotdir" \
    /bin/zsh -dfc '
      setopt ERR_EXIT NO_UNSET PIPE_FAIL
      typeset test_host

      DOTFILES_ZSH_DIR="$1"
      for test_host in v101 v102 v103 v104 v105 v106 v107 v108; do
        HOST="$test_host"
        unset DOTFILES_TEST_HOST_PROFILE
        builtin source "$2"
        [[ "$DOTFILES_TEST_HOST_PROFILE" == lab-server ]]
      done

      print -r -- dotfiles-zsh-hosts-ok
    ' dotfiles-check \
      "$host_fixture_dir" \
      "$REPOSITORY_ROOT/.config/zsh/hosts/init.zsh" 2>&1
)" || fail "研究室サーバーのホスト振り分けが動作しません"

[[ "$host_output" == dotfiles-zsh-hosts-ok ]] \
  || fail "ホスト振り分けの検査で予期しない出力があります: $host_output"

mkdir -p -- "$DOTFILES_TEST_ROOT/starship-cache"

sheldon_test_data_dir="$DOTFILES_TEST_ROOT/sheldon-data"
mkdir -p -- "$sheldon_test_data_dir"

if (( $+commands[sheldon] )); then
  sheldon_source_data_dir="${SHELDON_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sheldon}"
  [[ -r "$sheldon_source_data_dir/plugins.lock" \
    && -d "$sheldon_source_data_dir/repos" ]] \
    || fail "Sheldonのデータがありません。先に sheldon lock を実行してください"

  sheldon_source_config_dir="$(
    command sed -n 's/^config_dir = "\(.*\)"/\1/p' \
      "$sheldon_source_data_dir/plugins.lock"
  )"
  [[ -n "$sheldon_source_config_dir" ]] \
    || fail "Sheldonのロックファイルから設定先を取得できません"

  /bin/cp -R \
    "$sheldon_source_data_dir/repos" \
    "$sheldon_test_data_dir/repos"
  sheldon_lock_text="$(< "$sheldon_source_data_dir/plugins.lock")"
  sheldon_lock_text="${sheldon_lock_text//$sheldon_source_data_dir/$sheldon_test_data_dir}"
  sheldon_lock_text="${sheldon_lock_text//$sheldon_source_config_dir/$REPOSITORY_ROOT/.config/sheldon}"
  print -r -- "$sheldon_lock_text" > "$sheldon_test_data_dir/plugins.lock"
fi

startup_output="$(
  HOST=dotfiles-smoke-test \
  ZDOTDIR="$DOTFILES_TEST_ROOT" \
  DOTFILES_PRIVATE_FILE=/dev/null \
  DOTFILES_HISTFILE="$DOTFILES_TEST_ROOT/.zsh_history" \
  DOTFILES_FUNCTION_DIR="$DOTFILES_TEST_ROOT/empty-functions" \
  SHELDON_CONFIG_DIR="$REPOSITORY_ROOT/.config/sheldon" \
  SHELDON_DATA_DIR="$sheldon_test_data_dir" \
  STARSHIP_CACHE="$DOTFILES_TEST_ROOT/starship-cache" \
  TERM=xterm-256color \
    /bin/zsh -d -i -c '
      setopt ERR_EXIT NO_UNSET PIPE_FAIL

      [[ "$DOTFILES_ROOT" == "$1" ]]
      [[ "$HISTFILE" == "$ZDOTDIR/.zsh_history" ]]
      [[ "$aliases[lt]" == "ls -t" ]]
      [[ "$aliases[g]" == "git" ]]
      [[ -o AUTO_PUSHD ]]
      [[ "$(bindkey "^P")" == *history-beginning-search-backward-end* ]]

      (( ${+functions[done-notify]} ))
      (( ${+functions[rm]} ))
      (( ${+functions[nvistat]} ))
      (( ${+functions[shrinkpdf]} ))
      (( ${+functions[backup-nvim]} ))
      (( ${+functions[restore-nvim]} ))

      [[ "$ZSH_AUTOSUGGEST_HISTORY_IGNORE" == "*[![:ascii:]]*" ]]
      [[ "$ZSH_HIGHLIGHT_STYLES[unknown-token]" == default ]]

      if (( $+commands[sheldon] )); then
        (( ${+functions[_zsh_autosuggest_start]} ))
        (( ${+functions[_zsh_highlight]} ))
      fi

      if (( $+commands[starship] )); then
        [[ "$STARSHIP_CONFIG" == "$1/.config/starship.toml" ]]
      fi

      print -r -- dotfiles-zsh-smoke-ok
    ' dotfiles-check "$REPOSITORY_ROOT" 2>&1
)" || fail "対話シェルを起動できません"

[[ "$startup_output" == dotfiles-zsh-smoke-ok ]] \
  || fail "対話シェルの起動時に予期しない出力があります: $startup_output"

mkdir -p -- "$DOTFILES_TEST_ROOT/trash-bin"
print -rl -- '#!/bin/sh' \
  'printf "%s\n" "$@"' \
  > "$DOTFILES_TEST_ROOT/trash-bin/gio"
chmod +x -- "$DOTFILES_TEST_ROOT/trash-bin/gio"

trash_output="$(
  PATH="$DOTFILES_TEST_ROOT/trash-bin:/usr/bin:/bin" \
  DOTFILES_RM_PLATFORM=linux-gnu \
    /bin/zsh -dfc '
      builtin source "$1"
      rm -rf -- "file one" directory
    ' dotfiles-check "$REPOSITORY_ROOT/.config/zsh/functions/rm.zsh" 2>&1
)" || fail "Linuxでrmをtrashへ置き換えられません"

[[ "$trash_output" == $'trash\n--\n'"$REPOSITORY_ROOT"$'/file one\n'"$REPOSITORY_ROOT/directory" ]] \
  || fail "rmからgio trashへの引数変換が正しくありません: $trash_output"

mkdir -p -- "$DOTFILES_TEST_ROOT/empty-zdotdir"
fallback_output="$(
  ZDOTDIR="$DOTFILES_TEST_ROOT/empty-zdotdir" \
    /bin/zsh -dfc '
      setopt ERR_EXIT NO_UNSET PIPE_FAIL
      path=(/usr/bin /bin)
      rehash

      DOTFILES_ROOT="$1"
      DOTFILES_ZSH_DIR="$1/.config/zsh"
      builtin source "$DOTFILES_ZSH_DIR/prompt.zsh"
      builtin source "$DOTFILES_ZSH_DIR/plugins.zsh"

      [[ "$PROMPT" == "%F{blue}%m:%~%f > " ]]
      print -r -- dotfiles-zsh-fallback-ok
    ' dotfiles-check "$REPOSITORY_ROOT" 2>&1
)" || fail "任意ツール未導入時のフォールバックが動作しません"

[[ "$fallback_output" == dotfiles-zsh-fallback-ok ]] \
  || fail "フォールバック時に予期しない出力があります: $fallback_output"

if (( $+commands[starship] )); then
  starship_error_file="$DOTFILES_TEST_ROOT/starship.stderr"
  starship_output="$(
    STARSHIP_CONFIG="$REPOSITORY_ROOT/.config/starship.toml" \
    STARSHIP_CACHE="$DOTFILES_TEST_ROOT/starship-cache" \
    TERM=xterm-256color \
      starship prompt --path "$REPOSITORY_ROOT" 2> "$starship_error_file"
  )" || fail "Starshipプロンプトを生成できません"

  [[ ! -s "$starship_error_file" ]] \
    || fail "Starshipがエラーを出力しました: $(< "$starship_error_file")"

  [[ "$starship_output" == $'\n'* ]] \
    || fail "直前の出力とStarshipプロンプトの間に空行がありません"
  starship_output="${starship_output#$'\n'}"
  [[ "$starship_output" != $'\n'* ]] \
    || fail "Starshipプロンプトの前に空行が複数あります"

  starship_lines=("${(@f)starship_output}")
  (( ${#starship_lines} == 2 )) \
    || fail "Starshipプロンプトが2行ではありません"

  starship_character="$(
    STARSHIP_CONFIG="$REPOSITORY_ROOT/.config/starship.toml" \
    STARSHIP_CACHE="$DOTFILES_TEST_ROOT/starship-cache" \
    TERM=xterm-256color \
      starship module character 2>> "$starship_error_file"
  )" || fail "Starshipの入力記号を生成できません"

  starship_prompt_character="${starship_lines[2]//\%\{/}"
  starship_prompt_character="${starship_prompt_character//\%\}/}"
  [[ "$starship_prompt_character" == "$starship_character" ]] \
    || fail "Starshipプロンプトの2行目が入力記号だけではありません"

  starship_gpu_output="$(
    CUDA_VISIBLE_DEVICES=2,3 \
    STARSHIP_CONFIG="$REPOSITORY_ROOT/.config/starship.toml" \
    STARSHIP_CACHE="$DOTFILES_TEST_ROOT/starship-cache" \
    TERM=xterm-256color \
      starship module env_var.CUDA_VISIBLE_DEVICES 2>> "$starship_error_file"
  )" || fail "StarshipのCUDA GPU表示を生成できません"
  [[ "$starship_gpu_output" == *"GPU 2,3"* ]] \
    || fail "CUDA_VISIBLE_DEVICESの値がStarshipへ表示されません"

  starship_gpu_output="$(
    unset CUDA_VISIBLE_DEVICES
    STARSHIP_CONFIG="$REPOSITORY_ROOT/.config/starship.toml" \
    STARSHIP_CACHE="$DOTFILES_TEST_ROOT/starship-cache" \
    TERM=xterm-256color \
      starship module env_var.CUDA_VISIBLE_DEVICES 2>> "$starship_error_file"
  )" || fail "CUDA GPU未選択時のStarship表示を生成できません"
  [[ -z "$starship_gpu_output" ]] \
    || fail "CUDA_VISIBLE_DEVICESの未設定時にもGPU番号が表示されます"

  [[ ! -s "$starship_error_file" ]] \
    || fail "Starshipがエラーを出力しました: $(< "$starship_error_file")"
fi

print -r -- "[成功] Zsh設定のスモークテストに合格しました"
