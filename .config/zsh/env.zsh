WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
fignore=(.o .aux .log .bbl .blg .lof .lot .toc \~)

export HISTFILE="$HOME/.zsh_history"
export SAVEHIST=100000
export HISTSIZE=2000
export LSCOLORS=gxfxcxdxbxegedabagacad
export EDITOR=emacs

if [[ -d /Applications/LibreOffice.app/Contents/MacOS ]]; then
  export PATH="$PATH:/Applications/LibreOffice.app/Contents/MacOS"
fi

dotfiles_function_dir="$HOME/Educ2024/zsh/tmp/func"
if [[ -d "$dotfiles_function_dir" ]]; then
  fpath=("$dotfiles_function_dir" $fpath)
  dotfiles_autoload_functions=("$dotfiles_function_dir"/*(N:t))
  if (( $#dotfiles_autoload_functions > 0 )); then
    autoload $dotfiles_autoload_functions
  fi
fi
unset dotfiles_function_dir dotfiles_autoload_functions
