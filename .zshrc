source $HOME/dotfiles/.zshrc.private
autoload -U compinit
autoload history-search-end
autoload -Uz colors
setopt autoresume
colors
compinit
# Tabで次の候補に、Shift+Tabで前の候補に移動する設定
bindkey "^[[Z" reverse-menu-complete

# fzf
#source /opt/local/share/fzf/shell/completion.zsh
#source /opt/local/share/fzf/shell/key-bindings.zsh

# プロンプトにgitのブランチ名などを表示
source $HOME/dotfiles/zsh-git-prompt/zshrc.sh

git_prompt_air(){
    if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = true ]; then
      PS1="%{$fg[green]%}%m:%~%{$fg[default]%}$(git_super_status) > "
    else
      PS1="%{$fg[green]%}%m:%~%{$fg[default]%} > "
    fi
}

git_prompt_other(){
    if [ "$(git rev-parse --is-inside-work-tree 2> /dev/null)" = true ]; then
      PS1="%{$fg[blue]%}%m:%~%{$fg[default]%}$(git_super_status) > "
    else
      PS1="%{$fg[blue]%}%m:%~%{$fg[default]%} > "
    fi
}

show_virtual_env() {
  local env_name=""
  # conda環境がアクティブな場合（CONDA_DEFAULT_ENVまたはDIRENV_DIRが定義されている場合）
  if [[ -n "$CONDA_DEFAULT_ENV" || -n "$DIRENV_DIR" ]]; then
    env_name="($CONDA_DEFAULT_ENV)"
  fi
  # pipの仮想環境がアクティブな場合（VIRTUAL_ENVが定義されている場合）
  if [[ -n "$VIRTUAL_ENV" ]]; then
    env_name="${env_name}($(basename $VIRTUAL_ENV))"
  fi
  echo "$env_name"
}

precmd(){
  if [[ "$HOST" == "dhcp145.fun.bio.keio.ac.jp" || "$HOST" == "Sugawara-MacBook-Air.local" ]]; then
      git_prompt_air
      export JAVA_HOME=`/usr/libexec/java_home`
      # for thefuck
      eval $(thefuck --alias)
  else
      git_prompt_other
  fi
  # 仮想環境名をプロンプトの先頭に表示
  PS1="$(show_virtual_env)$PS1"
}


WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
#補完候補の設定
fignore=(.o .aux .log .bbl .blg .lof .lot .toc \~)
# emacsのエイリアス
alias emacs="/Applications/MacPorts/Emacs.app/Contents/MacOS/Emacs -nw"
# .zshrcのエイリアス
alias sz="source ~/.zshrc"
alias ez="emacs ~/.zshrc"
# Python
alias py='python'
# Git
alias g='git'
# quicklookのエイリアス
alias ql="qlmanage -p"
# lsのおすすめ設定
alias ls="/bin/ls -GF"
# make cleanのエイリアス
alias remake="make clean && make"
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey "^P" history-beginning-search-backward-end
bindkey "^N" history-beginning-search-forward-end
# X11.app(GUIの画面をmacOSに表示するやつ)の設定
export DISPLAY=:0

# ディレクトリが変わるたびにlsを表示する関数
chpwd () {
    ls;
    }

# コマンド入力中のマニュアル表示
[ -n "`alias run-hel`" ] && unalias run-help
autoload run-help

# 小文字と大文字の区別を無くす＋部分一致の補完
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}' 'r:|=*' 'l:|=* r:|=*'
# .から始まるファイルも補完の候補に出す
setopt globdots
# 色つけるやつ
zstyle ':completion:*default' menu select=1
export LSCOLORS=gxfxcxdxbxegedabagacad
zstyle ':completion:*' list-colors di=36 ln=35 ex=31 '=*.c=33' '=*.py=33'

# ヒストリ ALL_EXPORTしたら、export書く必要なくなる
export HISTFILE=~/.zsh_history
export SAVEHIST=100000
export HISTSIZE=2000

# setopt
setopt IGNORE_EOF
setopt CORRECT
setopt SHARE_HISTORY
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
unsetopt auto_remove_slash
setopt menu_complete
setopt numeric_glob_sort
unsetopt nomatch
# cd したら自動的にpushdする
setopt AUTO_PUSHD
# 重複したディレクトリをスタックに追加しない
setopt PUSHD_IGNORE_DUPS
DIRSTACKSIZE=20

alias cdd='cd ..'
alias d='dirs -v; echo -n "select number: "; read newdir; cd +"$newdir"'

fpath=(~/Educ2024/zsh/tmp/func $fpath)
autoload ${fpath[1]}/*(:t)

# kittyのための設定
export EDITOR=emacs
export PATH=$PATH:/Applications/LibreOffice.app/Contents/MacOS

### direnv for python virtualenv
if whence direnv &>/dev/null; then
  eval "$(direnv hook zsh)"
fi

# リモートサーバの個別設定
if [ -f "$HOME/.zshrc.$HOST" ]; then
    source "$HOME/.zshrc.$HOST"
fi

setopt PROMPT_SUBST

# slack done-notify
# メッセージをJSON形式で作成
slack_message() {
  local message=$1
  cat <<EOF
{
  "text": "$message"
}
EOF
}
# メッセージを送信
notify_slack() {
  local message=$1
  curl -X POST -H 'Content-type: application/json' --data "$(slack_message "$message")" $SLACK_WEBHOOK_URL
}
# コマンド終了通知関数
done-notify() {
  local var=$(echo $history[$HISTCMD] | sed -e "s/$0//" -e 's/ *; *//' -e 's/ *&& *//')
  local current_dir=$(pwd)  # 現在のディレクトリを取得
  notify_slack "[$current_dir] $var finished!"
}

nvistat() {
  servers=("v101" "v102" "v103" "v104" "v105" "v106" "v107")
  foreach i in $servers
    echo "${fg_bold[green]}$i${reset_color}:"
    ssh -x $i nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory --format=csv,noheader \
      | sed -e 's/NVIDIA //g' -e 's/Tesla //g' -e 's/ %/%/g' -e 's/Graphics Device/A100 80GB PCIe/g' -e "s/ 0%/ ${fg_bold[cyan]}0${reset_color}%/g" -e "s/ 100%/${fg_bold[red]} 100${reset_color}%/g" \
      | while IFS=, read -r id gpu load mem
        do
          printf "%4s %16s [%4s] [%4s]\n" "$id" "$gpu" "$load" "$mem"
        done
  end
}

# コマンド入力のサジェスト
source $HOME/dotfiles/zsh-autosuggestions/zsh-autosuggestions.zsh
# macair コマンドの候補に色付け
source $HOME/dotfiles/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

shrinkpdf () {
	if [ $# -lt 1 ]
	then
		echo "Usage: $0 file.pdf"
		echo "  will shrink file.pdf"
		return
	fi
	out=${1:r}-s.pdf
	gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite -dCompatibilityLevel=1.5 -dPDFSETTINGS=/printer -sOutputFile=${out} $1
}

# ssh for kitty
if [[ "$TERM" == "xterm-kitty" ]]; then
    alias ssh="kitten ssh"
fi

# backup my nvim config
# backup my neovim config. you can restore the config by using restore-nvim.zsh
backup-nvim() {
  local timestamp=$(date "+%Y-%m-%d-%H%M")
  echo "Backup following directories"
  echo "  ~/.config/nvim      => ~/.config/nvim.${timestamp}"
  echo "  ~/.local/share/nvim => ~/.local/share/nvim.${timestamp}"
  echo "  ~/.local/state/nvim => ~/.local/state/nvim.${timestamp}"
  echo "  ~/.cache/nvim       => ~/.cache/nvim.${timestamp}"
 
  # required
  mv ~/.config/nvim ~/.config/nvim.${timestamp}
 
  # optional but recommended
  mv ~/.local/share/nvim ~/.local/share/nvim.${timestamp}
  mv ~/.local/state/nvim ~/.local/state/nvim.${timestamp}
  mv ~/.cache/nvim ~/.cache/nvim.${timestamp}
}

# Restore your backed up nvim config. Use the backup-nvim.zsh script to create the backup.
restore-nvim() {
  local backup_array=(${(f)"$(command ls -1d ~/.config/nvim.* | sort -nr | sed -e 's/.*nvim/nvim/')"})

  if [ $#backup_array = 0 ]; then
    echo "No backup directory found"
    return 1
  fi
  for ((i = 1; i <= $#backup_array; i++)) print -r -- "[$i] $backup_array[i]"

  # select backup directory
  echo ""
  echo -n "Select index: "
  re='^[0-9]+$'
  read index
  if ! [[ $index =~ $re ]] ; then
    echo "Error: Not a number"
    return 1
  fi
  if [ $index -gt $#backup_array ]; then
    echo "index must be less than $#backup_array"
    return 1
  fi
  if [ $index -lt 1 ]; then
    echo "index must be greater than 1"
    return 1
  fi
  local selected=$backup_array[$index]
  echo "Selected: $selected"
  local backup_config="$HOME/.config/$selected"
  local backup_share="$HOME/.local/share/$selected"
  local backup_state="$HOME/.local/state/$selected"
  local backup_cache="$HOME/.cache/$selected"

  if [ ! -d $backup_config -o ! -d $backup_share -o ! -d $backup_state -o ! -d $backup_cache ]; then
    echo "backup directory not found"
    return 1
  fi

  echo ""
  echo "Restore following directories"
  echo ""
  echo "  $backup_config      => ~/.config/nvim"
  echo "  $backup_share => ~/.local/share/nvim"
  echo "  $backup_state => ~/.local/state/nvim"
  echo "  $backup_cache       => ~/.cache/nvim"
  echo ""
  echo "This operation will overwrite the above directories."
  echo -n "Proceed? [y/N] "

  read yesno
  # execute
  if [ $yesno = "y" -o $yesno = "Y" ]; then
    if [ -d ~/.config//nvim ]; then
      rm -rf ~/.config/nvim
    fi
    if [ -d ~/.local/share/nvim ]; then
      rm -rf ~/.local/share/nvim
    fi
    if [ -d ~/.local/state/nvim ]; then
      rm -rf ~/.local/state/nvim
    fi
    if [ -d ~/.cache//nvim ]; then
      rm -rf ~/.cache/nvim
    fi
    mv $backup_config ~/.config/nvim
    mv $backup_share  ~/.local/share/nvim
    mv $backup_state  ~/.local/state/nvim
    mv $backup_cache  ~/.cache/nvim
  fi
}

<<<<<<< HEAD
# Created by `pipx` on 2025-07-14 09:08:57
export PATH="$PATH:/Users/sugawara/.local/bin"

# Added by Antigravity
export PATH="/Users/sugawara/.antigravity/antigravity/bin:$PATH"
=======
>>>>>>> origin/main
