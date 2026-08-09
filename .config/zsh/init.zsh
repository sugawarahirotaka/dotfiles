typeset -g DOTFILES_ZSH_DIR="$DOTFILES_ROOT/.config/zsh"

for dotfiles_zsh_module in \
  core.zsh \
  env.zsh \
  options.zsh \
  completion.zsh \
  keybindings.zsh \
  aliases.zsh \
  directories.zsh \
  functions/notification.zsh \
  functions/nvidia.zsh \
  functions/pdf.zsh \
  functions/nvim.zsh \
  integrations.zsh \
  prompt.zsh \
  plugin-settings.zsh \
  plugins.zsh
do
  builtin source "$DOTFILES_ZSH_DIR/$dotfiles_zsh_module"
done

unset dotfiles_zsh_module
