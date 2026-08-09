typeset -g DOTFILES_ROOT="${${(%):-%N}:A:h}"

dotfiles_private_file="${DOTFILES_PRIVATE_FILE:-$HOME/.zshrc.private}"
if [[ -r "$dotfiles_private_file" ]]; then
  builtin source "$dotfiles_private_file"
fi
unset dotfiles_private_file

builtin source "$DOTFILES_ROOT/.config/zsh/init.zsh"
