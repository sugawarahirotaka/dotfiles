typeset -g DOTFILES_ROOT="${${(%):-%N}:A:h}"

if [[ -r "$HOME/.zshrc.private" ]]; then
  builtin source "$HOME/.zshrc.private"
fi

builtin source "$DOTFILES_ROOT/.config/zsh/init.zsh"
