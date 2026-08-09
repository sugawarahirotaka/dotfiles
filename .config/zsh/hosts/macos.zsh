if [[ -x /usr/libexec/java_home ]]; then
  if dotfiles_java_home="$(/usr/libexec/java_home 2>/dev/null)"; then
    export JAVA_HOME="$dotfiles_java_home"
  fi
  unset dotfiles_java_home
fi

if [[ -z "${DISPLAY:-}" ]]; then
  export DISPLAY=:0
fi
