slack_message() {
  local message="$1"
  cat <<EOF
{
  "text": "$message"
}
EOF
}

notify_slack() {
  local message="$1"
  curl -X POST -H 'Content-type: application/json' \
    --data "$(slack_message "$message")" \
    "$SLACK_WEBHOOK_URL"
}

done-notify() {
  local command_line
  local current_dir

  command_line=$(echo "$history[$HISTCMD]" | sed -e "s/$0//" -e 's/ *; *//' -e 's/ *&& *//')
  current_dir=$(pwd)
  notify_slack "[$current_dir] $command_line finished!"
}
