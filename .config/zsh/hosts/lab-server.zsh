if [[ -d /usr/local/anaconda3/bin ]]; then
  export PATH="/usr/local/anaconda3/bin:$PATH"
fi

unalias emacs 2>/dev/null
if [[ -x /usr/bin/emacs ]]; then
  alias emacs='/usr/bin/emacs -nw'
fi

if [[ -x /usr/local/anaconda3/bin/conda ]]; then
  if dotfiles_conda_setup="$("/usr/local/anaconda3/bin/conda" shell.zsh hook 2>/dev/null)"; then
    eval "$dotfiles_conda_setup"
  elif [[ -r /usr/local/anaconda3/etc/profile.d/conda.sh ]]; then
    builtin source /usr/local/anaconda3/etc/profile.d/conda.sh
  fi
  unset dotfiles_conda_setup
fi
