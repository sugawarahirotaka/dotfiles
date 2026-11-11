#!/usr/bin/env zsh

setopt ERR_EXIT NO_UNSET PIPE_FAIL

TEST_PATH="${(%):-%N}"
REPO_ROOT="${TEST_PATH:A:h:h}"
TOOL="$REPO_ROOT/scripts/codex-account.py"
TEST_TMP="$(mktemp -d "${TMPDIR:-/tmp}/codex-account-test.XXXXXX")"
trap 'rm -rf -- "$TEST_TMP"' EXIT INT TERM
typeset -i PASSED=0
typeset -i FAILED=0

pass() { echo "[pass] $1"; (( PASSED += 1 )); }
fail() { echo "[fail] $1" >&2; (( FAILED += 1 )); }

export CODEX_HOME="$TEST_TMP/codex"
export CODEX_ACCOUNT_SKIP_APP_CONTROL=1
export CODEX_ACCOUNT_CODEX_BIN="$TEST_TMP/fake-codex"
mkdir -p "$CODEX_HOME"

# auth.json と同じ形のログインを作る。refresh で同一アカウントのトークン更新を表す。
make_login() {
  python3 - "$@" <<'PY'
import base64, json, sys
email, account, refresh, out = sys.argv[1:5]
def b64(obj):
    return base64.urlsafe_b64encode(json.dumps(obj).encode()).rstrip(b"=").decode()
claims = {"email": email, "https://api.openai.com/auth": {
    "chatgpt_account_id": account, "chatgpt_user_id": f"user-{account}", "chatgpt_plan_type": "plus"}}
data = {"auth_mode": "chatgpt", "OPENAI_API_KEY": None, "tokens": {
    "id_token": f"h.{b64(claims)}.s", "access_token": "a", "refresh_token": refresh, "account_id": account}}
open(out, "w").write(json.dumps(data))
PY
}

refresh_of() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["tokens"]["refresh_token"])' "$1"
}

cat > "$CODEX_ACCOUNT_CODEX_BIN" <<'EOF'
#!/bin/zsh
print -r -- "$*" > "$FAKE_CODEX_ARGS"
[[ "${FAKE_CODEX_FAIL:-0}" == 1 ]] && exit 1
cp "$FAKE_CODEX_LOGIN" "$CODEX_HOME/auth.json"
EOF
chmod +x "$CODEX_ACCOUNT_CODEX_BIN"
export FAKE_CODEX_ARGS="$TEST_TMP/args"

run() { python3 "$TOOL" "$@"; }

make_login a@example.com acct-a r1 "$CODEX_HOME/auth.json"
if ! run use anything >/dev/null 2>&1 && ! run add 'bad/name' >/dev/null 2>&1; then
  pass "rejects unknown and invalid profile names"
else
  fail "rejects unknown and invalid profile names"
fi

if run save personal >/dev/null \
  && [[ "$(python3 -c 'import os,sys; print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$CODEX_HOME/auth-profiles/personal.json")" == 0o600 ]] \
  && [[ "$(run current)" == "personal: a@example.com"* ]]; then
  pass "save stores the active login with mode 600"
else
  fail "save stores the active login with mode 600"
fi

if ! run save other >/dev/null 2>&1; then
  pass "save refuses a second name for the same login"
else
  fail "save refuses a second name for the same login"
fi

make_login b@example.com acct-b r9 "$TEST_TMP/login-b.json"
export FAKE_CODEX_LOGIN="$TEST_TMP/login-b.json"
if run add lab --device-auth >/dev/null \
  && [[ "$(cat "$FAKE_CODEX_ARGS")" == *"login"*"--device-auth" ]] \
  && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r1 ]] \
  && [[ -z "$(ls -A "$CODEX_HOME/auth-profiles" | grep '^\.login-' || true)" ]]; then
  pass "add logs in separately without touching the active login"
else
  fail "add logs in separately without touching the active login"
fi

if FAKE_CODEX_FAIL=1 run add broken >/dev/null 2>&1; then
  fail "failed login saves nothing"
elif [[ ! -e "$CODEX_HOME/auth-profiles/broken.json" ]]; then
  pass "failed login saves nothing"
else
  fail "failed login saves nothing"
fi

# Codex が personal のトークンを更新した状態で切り替える。
make_login a@example.com acct-a r2 "$CODEX_HOME/auth.json"
if run use lab >/dev/null \
  && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r9 ]] \
  && [[ "$(refresh_of "$CODEX_HOME/auth-profiles/personal.json")" == r2 ]] \
  && [[ "$(run list)" == *"* lab"* ]]; then
  pass "use writes refreshed tokens back before switching"
else
  fail "use writes refreshed tokens back before switching"
fi

if run use personal >/dev/null && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r2 ]]; then
  pass "use switches back to the refreshed login"
else
  fail "use switches back to the refreshed login"
fi

make_login c@example.com acct-c r5 "$CODEX_HOME/auth.json"
if ! run use lab >/dev/null 2>&1 && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r5 ]] \
  && [[ "$(run list)" == *"active login is not saved"* ]]; then
  pass "use refuses to discard an unsaved login"
else
  fail "use refuses to discard an unsaved login"
fi

if run use lab --force >/dev/null && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r9 ]]; then
  pass "use --force replaces an unsaved login"
else
  fail "use --force replaces an unsaved login"
fi

# Process checks: a fake `ps` table stands in for running Codex processes.
export CODEX_ACCOUNT_PS_FIXTURE="$TEST_TMP/ps.json"
MY_UID="$(id -u)"
write_ps() {
  python3 - "$CODEX_ACCOUNT_PS_FIXTURE" "$MY_UID" "$@" <<'PY'
import json, sys
path, uid, *specs = sys.argv[1:]
rows = [{"pid": "1", "ppid": "0", "uid": "0", "tty": "??", "comm": "launchd", "args": "/sbin/launchd"}]
for spec in specs:
    pid, ppid, owner, tty, args = spec.split("|")
    rows.append({"pid": pid, "ppid": ppid, "uid": uid if owner == "me" else "0",
                 "tty": tty, "comm": args.split()[0], "args": args})
open(path, "w").write(json.dumps(rows))
PY
}

write_ps "200|1|other|ttys003|/usr/local/bin/codex"
if run use personal >/dev/null && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r2 ]]; then
  pass "another user's Codex process does not block switching"
else
  fail "another user's Codex process does not block switching"
fi

write_ps "300|1|me|ttys004|/usr/local/bin/codex"
if ! run use lab --yes >/dev/null 2>&1 && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r2 ]]; then
  pass "own terminal session blocks switching even with --yes"
else
  fail "own terminal session blocks switching even with --yes"
fi

write_ps "400|1|me|??|/usr/local/bin/codex app-server" "401|400|me|??|/usr/local/bin/codex-code-mode-host" \
  "402|1|me|??|/opt/codex/bin/codex app-server daemon pid-update-loop"
if run use lab --yes >/dev/null 2>&1 && [[ "$(refresh_of "$CODEX_HOME/auth.json")" == r9 ]] \
  && [[ "$(cat "$CODEX_ACCOUNT_PS_FIXTURE")" != *'"400"'* && "$(cat "$CODEX_ACCOUNT_PS_FIXTURE")" != *'"401"'* ]] \
  && [[ "$(cat "$CODEX_ACCOUNT_PS_FIXTURE")" == *'"402"'* ]]; then
  pass "background servers are stopped and the updater is left alone"
else
  fail "background servers are stopped and the updater is left alone"
fi
unset CODEX_ACCOUNT_PS_FIXTURE

if run remove personal >/dev/null && [[ ! -e "$CODEX_HOME/auth-profiles/personal.json" ]]; then
  pass "remove deletes a profile"
else
  fail "remove deletes a profile"
fi

echo "[result] passed=$PASSED failed=$FAILED"
(( FAILED == 0 ))
