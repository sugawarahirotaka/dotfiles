if whence direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

builtin source "$DOTFILES_ZSH_DIR/hosts/init.zsh"

if [[ "$TERM" == "xterm-kitty" ]]; then
  alias ssh='kitten ssh'
fi
