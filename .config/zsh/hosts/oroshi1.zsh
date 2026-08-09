unalias emacs 2>/dev/null
if [[ -x /opt/local/bin/emacs ]]; then
  alias emacs='/opt/local/bin/emacs -nw'
fi
