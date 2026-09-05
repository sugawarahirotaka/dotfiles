# Move files to the platform trash instead of unlinking them immediately.
rm() {
  emulate -L zsh

  typeset rm_option
  typeset rm_platform="${DOTFILES_RM_PLATFORM:-$OSTYPE}"
  typeset -a rm_paths
  integer rm_force=0

  while (( $# )); do
    case "$1" in
      --)
        shift
        rm_paths+=("$@")
        break
        ;;
      -*)
        if [[ -z "${1#-}" || "${1#-}" == *[^fFrR]* ]]; then
          print -u2 -r -- "rm: trashへの移動では未対応のオプションです: $1"
          print -u2 -r -- "rm: 完全に削除する場合は command rm を使ってください"
          return 2
        fi

        for rm_option in ${(s::)${1#-}}; do
          [[ "$rm_option" == [fF] ]] && rm_force=1
        done
        shift
        ;;
      *)
        rm_paths+=("$1")
        shift
        ;;
    esac
  done

  if (( ! ${#rm_paths} )); then
    (( rm_force )) && return 0
    print -u2 -r -- "rm: オペランドがありません"
    return 1
  fi

  rm_paths=("${(@)rm_paths:A}")

  case "$rm_platform" in
    darwin*)
      if (( $+commands[trash] )); then
        command trash -- "${rm_paths[@]}"
        return
      fi

      if (( $+commands[osascript] )); then
        command osascript - "${rm_paths[@]}" <<'APPLESCRIPT'
on run itemPaths
  tell application "Finder"
    repeat with itemPath in itemPaths
      delete POSIX file itemPath
    end repeat
  end tell
end run
APPLESCRIPT
        return
      fi
      ;;
    linux*)
      if (( $+commands[gio] )); then
        command gio trash -- "${rm_paths[@]}"
        return
      fi

      if (( $+commands[trash-put] )); then
        command trash-put -- "${rm_paths[@]}"
        return
      fi
      ;;
  esac

  print -u2 -r -- "rm: この環境で利用できるtrashコマンドが見つかりません"
  print -u2 -r -- "rm: 完全に削除する場合は command rm を使ってください"
  return 127
}
