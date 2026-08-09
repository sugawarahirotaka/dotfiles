if whence direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if [[ -f "$HOME/.zshrc.$HOST" ]]; then
  builtin source "$HOME/.zshrc.$HOST"
fi

if [[ "$TERM" == "xterm-kitty" ]]; then
  alias ssh='kitten ssh'
fi
