if (( $+commands[sheldon] )); then
  eval "$(sheldon source)"
else
  # Sheldon導入前やネットワーク障害時の移行用フォールバック。
  if [[ -r "$DOTFILES_ROOT/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    builtin source "$DOTFILES_ROOT/zsh-autosuggestions/zsh-autosuggestions.zsh"
  fi

  if [[ -r "$DOTFILES_ROOT/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    builtin source "$DOTFILES_ROOT/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
fi
