# Codexのログインを保存済みプロファイル間で切り替える。
codex-account() {
  command python3 "$DOTFILES_ROOT/scripts/codex-account.py" "$@"
}
