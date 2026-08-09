backup-nvim() {
  local timestamp
  timestamp=$(date "+%Y-%m-%d-%H%M")

  echo "Backup following directories"
  echo "  ~/.config/nvim      => ~/.config/nvim.$timestamp"
  echo "  ~/.local/share/nvim => ~/.local/share/nvim.$timestamp"
  echo "  ~/.local/state/nvim => ~/.local/state/nvim.$timestamp"
  echo "  ~/.cache/nvim       => ~/.cache/nvim.$timestamp"

  mv "$HOME/.config/nvim" "$HOME/.config/nvim.$timestamp"
  mv "$HOME/.local/share/nvim" "$HOME/.local/share/nvim.$timestamp"
  mv "$HOME/.local/state/nvim" "$HOME/.local/state/nvim.$timestamp"
  mv "$HOME/.cache/nvim" "$HOME/.cache/nvim.$timestamp"
}

restore-nvim() {
  local -a backup_array
  local index re selected
  local backup_config backup_share backup_state backup_cache
  local yesno

  backup_array=(${(f)"$(command ls -1d "$HOME"/.config/nvim.* 2>/dev/null | sort -nr | sed -e 's/.*nvim/nvim/')"})

  if (( $#backup_array == 0 )); then
    echo "No backup directory found"
    return 1
  fi

  for ((index = 1; index <= $#backup_array; index++)); do
    print -r -- "[$index] $backup_array[index]"
  done

  echo ""
  echo -n "Select index: "
  re='^[0-9]+$'
  read index

  if [[ ! "$index" =~ $re ]]; then
    echo "Error: Not a number"
    return 1
  fi

  if (( index > $#backup_array )); then
    echo "index must be less than or equal to $#backup_array"
    return 1
  fi

  if (( index < 1 )); then
    echo "index must be greater than or equal to 1"
    return 1
  fi

  selected="$backup_array[$index]"
  echo "Selected: $selected"

  backup_config="$HOME/.config/$selected"
  backup_share="$HOME/.local/share/$selected"
  backup_state="$HOME/.local/state/$selected"
  backup_cache="$HOME/.cache/$selected"

  if [[ ! -d "$backup_config" || ! -d "$backup_share" || ! -d "$backup_state" || ! -d "$backup_cache" ]]; then
    echo "backup directory not found"
    return 1
  fi

  echo ""
  echo "Restore following directories"
  echo ""
  echo "  $backup_config => ~/.config/nvim"
  echo "  $backup_share  => ~/.local/share/nvim"
  echo "  $backup_state  => ~/.local/state/nvim"
  echo "  $backup_cache  => ~/.cache/nvim"
  echo ""
  echo "This operation will overwrite the above directories."
  echo -n "Proceed? [y/N] "
  read yesno

  if [[ "$yesno" == "y" || "$yesno" == "Y" ]]; then
    [[ -d "$HOME/.config/nvim" ]] && rm -rf "$HOME/.config/nvim"
    [[ -d "$HOME/.local/share/nvim" ]] && rm -rf "$HOME/.local/share/nvim"
    [[ -d "$HOME/.local/state/nvim" ]] && rm -rf "$HOME/.local/state/nvim"
    [[ -d "$HOME/.cache/nvim" ]] && rm -rf "$HOME/.cache/nvim"

    mv "$backup_config" "$HOME/.config/nvim"
    mv "$backup_share" "$HOME/.local/share/nvim"
    mv "$backup_state" "$HOME/.local/state/nvim"
    mv "$backup_cache" "$HOME/.cache/nvim"
  fi
}
