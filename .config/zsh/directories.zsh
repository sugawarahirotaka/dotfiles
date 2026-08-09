DIRSTACKSIZE=20

alias cdd='cd ..'
alias d='dirs -v; echo -n "select number: "; read newdir; cd +"$newdir"'

chpwd() {
  ls
}
