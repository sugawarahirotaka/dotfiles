ZSH_AUTOSUGGEST_HISTORY_IGNORE='*[![:ascii:]]*'
builtin source "$DOTFILES_ROOT/zsh-autosuggestions/zsh-autosuggestions.zsh"

typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[unknown-token]=default
builtin source "$DOTFILES_ROOT/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
