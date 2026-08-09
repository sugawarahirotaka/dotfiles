if (( $+commands[starship] )); then
  export STARSHIP_CONFIG="$DOTFILES_ROOT/.config/starship.toml"
  eval "$(starship init zsh)"
else
  PROMPT='%F{blue}%m:%~%f > '
fi
