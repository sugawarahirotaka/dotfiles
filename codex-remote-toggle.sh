#!/bin/zsh

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Codex Remote 一括 ON/OFF
# @raycast.mode silent

# Optional parameters:
# @raycast.icon 🔌
# @raycast.packageName Codex
# @raycast.description CodexのSSH Remote接続をすべて一括でON/OFFする

set -euo pipefail

readonly codex_app_bundle_id="com.openai.codex"
readonly codex_app_process_pattern="/Applications/ChatGPT.app/Contents/MacOS/ChatGPT"
readonly codex_state_file="${CODEX_REMOTE_STATE_FILE:-${HOME}/.codex/.codex-global-state.json}"
readonly skip_app_restart="${CODEX_REMOTE_SKIP_APP_RESTART:-0}"

if [[ ! -f "${codex_state_file}" ]]; then
  print -u2 "Codexの状態ファイルが見つかりません: ${codex_state_file}"
  exit 1
fi

path=("/opt/local/bin" "/opt/homebrew/bin" "/usr/local/bin" "/usr/bin" "/bin" $path)
readonly jq_command="${commands[jq]:-}"

if [[ -z "${jq_command}" ]]; then
  print -u2 "jqが見つかりません。"
  exit 1
fi

readonly target_count="$(
  "${jq_command}" -r \
    '[.["codex-managed-remote-connections"][]?.hostId | select(type == "string")] | unique | length' \
    "${codex_state_file}"
)"

if (( target_count == 0 )); then
  print -u2 "切り替え対象のCodex Remote接続がありません。"
  exit 1
fi

readonly enabled_count="$(
  "${jq_command}" -r '
    [.["codex-managed-remote-connections"][]?.hostId | select(type == "string")] as $host_ids
    | (.["remote-connection-auto-connect-by-host-id"] // {}) as $states
    | [$host_ids[] | select($states[.] == true)]
    | length
  ' "${codex_state_file}"
)"

if (( enabled_count > 0 )); then
  readonly next_enabled="false"
  readonly next_label="OFF"
else
  readonly next_enabled="true"
  readonly next_label="ON"
fi

app_was_running="false"
if [[ "${skip_app_restart}" != "1" ]] \
  && /usr/bin/pgrep -f "${codex_app_process_pattern}" >/dev/null; then
  app_was_running="true"
  /usr/bin/osascript -e "tell application id \"${codex_app_bundle_id}\" to quit" >/dev/null

  for _ in {1..150}; do
    if ! /usr/bin/pgrep -f "${codex_app_process_pattern}" >/dev/null; then
      break
    fi
    sleep 0.1
  done

  if /usr/bin/pgrep -f "${codex_app_process_pattern}" >/dev/null; then
    print -u2 "Codexを正常終了できなかったため、接続設定を変更しませんでした。"
    exit 1
  fi
fi

readonly state_directory="${codex_state_file:h}"
temporary_state_file="$(mktemp "${state_directory}/.codex-remote-toggle.XXXXXX")"
trap 'rm -f "${temporary_state_file}"' EXIT

"${jq_command}" --argjson enabled "${next_enabled}" '
  (.["remote-connection-auto-connect-by-host-id"] //= {})
  | reduce (.["codex-managed-remote-connections"] // [])[] as $connection (.;
      if ($connection.hostId | type) == "string" then
        .["remote-connection-auto-connect-by-host-id"][$connection.hostId] = $enabled
      else
        .
      end
    )
' "${codex_state_file}" >"${temporary_state_file}"

"${jq_command}" -e . "${temporary_state_file}" >/dev/null
/bin/cp -p "${codex_state_file}" "${codex_state_file}.remote-toggle.bak"
/bin/mv "${temporary_state_file}" "${codex_state_file}"
trap - EXIT

if [[ "${skip_app_restart}" != "1" ]] \
  && { [[ "${app_was_running}" == "true" ]] || [[ "${next_enabled}" == "true" ]]; }; then
  /usr/bin/open -b "${codex_app_bundle_id}"
fi

print "Codex Remote: ${next_label}（${target_count}台）"
