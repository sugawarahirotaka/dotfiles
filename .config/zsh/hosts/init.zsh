dotfiles_short_host="${HOST%%.*}"
dotfiles_host_is_managed=0

if [[ "$OSTYPE" == darwin* ]]; then
  builtin source "$DOTFILES_ZSH_DIR/hosts/macos.zsh"
fi

case "$dotfiles_short_host" in
  v10[1-8])
    builtin source "$DOTFILES_ZSH_DIR/hosts/lab-server.zsh"
    dotfiles_host_is_managed=1
    ;;
  oroshi1)
    builtin source "$DOTFILES_ZSH_DIR/hosts/oroshi1.zsh"
    dotfiles_host_is_managed=1
    ;;
esac

dotfiles_legacy_host_file="$HOME/.zshrc.$HOST"
if (( ! dotfiles_host_is_managed )) && [[ -r "$dotfiles_legacy_host_file" ]]; then
  builtin source "$dotfiles_legacy_host_file"
fi

unset dotfiles_short_host dotfiles_host_is_managed dotfiles_legacy_host_file
