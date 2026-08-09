builtin source "$DOTFILES_ROOT/zsh-git-prompt/zshrc.sh"

git_prompt_air() {
  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == true ]]; then
    PS1="%{$fg[green]%}%m:%~%{$fg[default]%}$(git_super_status) > "
  else
    PS1="%{$fg[green]%}%m:%~%{$fg[default]%} > "
  fi
}

git_prompt_other() {
  if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" == true ]]; then
    PS1="%{$fg[blue]%}%m:%~%{$fg[default]%}$(git_super_status) > "
  else
    PS1="%{$fg[blue]%}%m:%~%{$fg[default]%} > "
  fi
}

show_virtual_env() {
  local env_name=""

  if [[ -n "$CONDA_DEFAULT_ENV" || -n "$DIRENV_DIR" ]]; then
    env_name="($CONDA_DEFAULT_ENV)"
  fi

  if [[ -n "$VIRTUAL_ENV" ]]; then
    env_name="$env_name($(basename "$VIRTUAL_ENV"))"
  fi

  echo "$env_name"
}

precmd() {
  if [[ "$HOST" == "dhcp145.fun.bio.keio.ac.jp" || "$HOST" == "Sugawara-MacBook-Air.local" ]]; then
    git_prompt_air
  else
    git_prompt_other
  fi

  PS1="$(show_virtual_env)$PS1"
}
