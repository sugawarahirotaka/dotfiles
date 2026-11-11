#!/usr/bin/env python3
"""Switch Codex between saved ChatGPT logins.

Each login is kept as a copy of ``$CODEX_HOME/auth.json`` under
``$CODEX_HOME/auth-profiles/<name>.json``. Switching writes the active login
back to its profile first, because Codex rotates refresh tokens and an old
copy may no longer work.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Dict, List, Optional, Tuple

APP_BUNDLE_ID = "com.openai.codex"
PROFILE_DIR_NAME = "auth-profiles"
NAME_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")


class AccountError(Exception):
    pass


class Login:
    def __init__(self, raw: bytes, key: str, email: str, plan: str, account_id: str) -> None:
        self.raw = raw
        self.key = key
        self.email = email
        self.plan = plan
        self.account_id = account_id

    def label(self) -> str:
        parts = [self.email or "(no email)"]
        if self.plan:
            parts.append(self.plan)
        if self.account_id:
            parts.append(f"account {self.account_id[:8]}")
        return ", ".join(parts)


def codex_home() -> Path:
    value = os.environ.get("CODEX_HOME")
    return Path(value).expanduser() if value else Path.home() / ".codex"


def auth_file(home: Path) -> Path:
    return home / "auth.json"


def profile_dir(home: Path) -> Path:
    return home / PROFILE_DIR_NAME


def profile_file(home: Path, name: str) -> Path:
    if not NAME_PATTERN.match(name):
        raise AccountError(f"invalid profile name: {name!r} (use letters, digits, '.', '_', '-')")
    return profile_dir(home) / f"{name}.json"


def jwt_claims(token: str) -> Dict:
    try:
        payload = token.split(".")[1]
        payload += "=" * (-len(payload) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
    except (IndexError, ValueError):
        return {}
    return claims if isinstance(claims, dict) else {}


def parse_login(raw: bytes, origin: Path) -> Login:
    try:
        data = json.loads(raw)
    except ValueError as exc:
        raise AccountError(f"{origin} is not valid JSON") from exc
    if not isinstance(data, dict):
        raise AccountError(f"{origin} has an unexpected format")

    tokens = data.get("tokens")
    if isinstance(tokens, dict) and tokens.get("id_token"):
        claims = jwt_claims(str(tokens["id_token"]))
        auth = claims.get("https://api.openai.com/auth")
        auth = auth if isinstance(auth, dict) else {}
        account_id = str(tokens.get("account_id") or auth.get("chatgpt_account_id") or "")
        user_id = str(auth.get("chatgpt_user_id") or auth.get("user_id") or claims.get("sub") or "")
        if not account_id and not user_id:
            raise AccountError(f"{origin} has no account or user id")
        return Login(
            raw,
            key=f"chatgpt:{account_id}:{user_id}",
            email=str(claims.get("email") or ""),
            plan=str(auth.get("chatgpt_plan_type") or ""),
            account_id=account_id,
        )

    api_key = data.get("OPENAI_API_KEY")
    if isinstance(api_key, str) and api_key:
        digest = hashlib.sha256(api_key.encode()).hexdigest()[:12]
        return Login(raw, key=f"apikey:{digest}", email="", plan="api-key", account_id="")

    raise AccountError(f"{origin} contains no ChatGPT tokens or API key")


def read_login(path: Path) -> Optional[Login]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError:
        return None
    return parse_login(raw, path)


def write_secret(path: Path, raw: bytes) -> None:
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(raw)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temp_name, 0o600)
        os.replace(temp_name, path)
    except BaseException:
        try:
            os.unlink(temp_name)
        except FileNotFoundError:
            pass
        raise


def saved_profiles(home: Path) -> List[Tuple[str, Login]]:
    directory = profile_dir(home)
    if not directory.is_dir():
        return []
    profiles = []
    for path in sorted(directory.glob("*.json")):
        name = path.stem
        if not NAME_PATTERN.match(name):
            continue
        profiles.append((name, parse_login(path.read_bytes(), path)))
    return profiles


def profile_for_key(home: Path, key: str) -> Optional[str]:
    for name, login in saved_profiles(home):
        if login.key == key:
            return name
    return None


def ask_yes_no(question: str) -> bool:
    try:
        with open("/dev/tty", "r+") as tty:
            tty.write(f"{question} [y/N]: ")
            tty.flush()
            return tty.readline().strip().lower() in {"y", "yes"}
    except OSError:
        return False


def app_control_enabled() -> bool:
    return sys.platform == "darwin" and os.environ.get("CODEX_ACCOUNT_SKIP_APP_CONTROL") != "1"


def app_running() -> bool:
    result = subprocess.run(
        ["/usr/bin/osascript", "-e", f'application id "{APP_BUNDLE_ID}" is running'],
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() == "true"


def quit_app() -> None:
    subprocess.run(
        ["/usr/bin/osascript", "-e", f'tell application id "{APP_BUNDLE_ID}" to quit'],
        capture_output=True,
    )
    for _ in range(150):
        if not app_running():
            return
        time.sleep(0.1)
    raise AccountError("the Codex app did not quit; auth.json was not changed")


class CodexProcess:
    def __init__(self, pid: str, tty: str, args: str) -> None:
        self.pid = pid
        self.tty = tty
        self.args = args

    @property
    def is_daemon(self) -> bool:
        # The background app server that the app and CLI share; it outlives them.
        return " app-server" in self.args and "--managed-daemon" in self.args

    @property
    def is_updater(self) -> bool:
        # Keeps the daemon package up to date; it does not hold or write the login.
        return " app-server daemon pid-update-loop" in self.args

    def __str__(self) -> str:
        where = f"terminal {self.tty}" if self.tty not in {"??", "?", "-"} else "background"
        return f"{self.pid} ({where}) {self.args[:160]}"


def ps_column(column: str) -> Dict[str, str]:
    result = subprocess.run(["ps", "-axo", f"pid=,{column}="], capture_output=True, text=True)
    table = {}
    for line in result.stdout.splitlines():
        pid, _, value = line.strip().partition(" ")
        table[pid] = value.strip()
    return table


def running_codex_processes() -> List[CodexProcess]:
    if os.environ.get("CODEX_ACCOUNT_SKIP_APP_CONTROL") == "1":
        return []
    commands = ps_column("comm")
    ttys = ps_column("tty")
    args = ps_column("args")
    found = []
    for pid, command in commands.items():
        name = os.path.basename(command)
        if (name == "codex" or name.startswith("codex-")) and pid != str(os.getpid()):
            process = CodexProcess(pid, ttys.get(pid, "?"), args.get(pid, command))
            if not process.is_updater:
                found.append(process)
    return found


def stop_daemon() -> None:
    codex_bin = os.environ.get("CODEX_ACCOUNT_CODEX_BIN") or shutil.which("codex")
    if not codex_bin:
        raise AccountError("codex command not found; stop the app-server daemon manually")
    subprocess.run([codex_bin, "app-server", "daemon", "stop"], capture_output=True)
    for _ in range(100):
        if not any(process.is_daemon for process in running_codex_processes()):
            return
        time.sleep(0.1)
    raise AccountError("the Codex app-server daemon did not stop; auth.json was not changed")


def describe_processes(processes: List[CodexProcess]) -> str:
    return "\n  ".join(str(process) for process in processes)


def command_list(args: argparse.Namespace) -> int:
    home = codex_home()
    current = read_login(auth_file(home))
    profiles = saved_profiles(home)
    if not profiles:
        print("no saved profiles")
    for name, login in profiles:
        marker = "*" if current and current.key == login.key else " "
        print(f"{marker} {name:<16} {login.label()}")
    if current is None:
        print("\nnot logged in")
    elif profile_for_key(home, current.key) is None:
        print(f"\nactive login is not saved: {current.label()}")
        print("save it with: codex-account save <name>")
    return 0


def command_current(args: argparse.Namespace) -> int:
    home = codex_home()
    current = read_login(auth_file(home))
    if current is None:
        print("not logged in")
        return 1
    name = profile_for_key(home, current.key)
    print(f"{name or '(unsaved)'}: {current.label()}")
    return 0


def save_login(home: Path, name: str, login: Login, force: bool) -> None:
    destination = profile_file(home, name)
    existing_name = profile_for_key(home, login.key)
    if existing_name and existing_name != name:
        raise AccountError(f"this login is already saved as {existing_name!r}")
    existing = read_login(destination)
    if existing and existing.key != login.key and not force:
        raise AccountError(
            f"profile {name!r} holds another login ({existing.label()}); pass --force to replace it"
        )
    write_secret(destination, login.raw)


def command_save(args: argparse.Namespace) -> int:
    home = codex_home()
    current = read_login(auth_file(home))
    if current is None:
        raise AccountError(f"{auth_file(home)} not found; log in with `codex login` first")
    save_login(home, args.name, current, args.force)
    print(f"saved {args.name}: {current.label()}")
    return 0


def command_add(args: argparse.Namespace) -> int:
    home = codex_home()
    destination = profile_file(home, args.name)
    if destination.exists():
        raise AccountError(f"profile {args.name!r} already exists")
    codex_bin = os.environ.get("CODEX_ACCOUNT_CODEX_BIN") or shutil.which("codex")
    if not codex_bin:
        raise AccountError("codex command not found")

    profile_dir(home).mkdir(mode=0o700, parents=True, exist_ok=True)
    login_home = Path(tempfile.mkdtemp(prefix=".login-", dir=profile_dir(home)))
    try:
        env = dict(os.environ, CODEX_HOME=str(login_home))
        command = [codex_bin, "login", "-c", 'cli_auth_credentials_store="file"', *args.login_args]
        if subprocess.run(command, env=env).returncode != 0:
            raise AccountError("codex login failed; no profile was saved")
        login = read_login(auth_file(login_home))
        if login is None:
            raise AccountError("codex login did not write auth.json; no profile was saved")
        save_login(home, args.name, login, force=False)
    finally:
        shutil.rmtree(login_home, ignore_errors=True)
    print(f"saved {args.name}: {login.label()}")
    print(f"switch with: codex-account use {args.name}")
    return 0


def command_use(args: argparse.Namespace) -> int:
    home = codex_home()
    target_path = profile_file(home, args.name)
    target = read_login(target_path)
    if target is None:
        raise AccountError(f"profile {args.name!r} not found")

    reopen = False
    if app_control_enabled() and app_running():
        if not (args.yes or ask_yes_no("Quit the Codex app to switch accounts?")):
            raise AccountError("the Codex app is running; auth.json was not changed")
        quit_app()
        reopen = not args.no_reopen

    if not args.force:
        processes = running_codex_processes()
        sessions = [process for process in processes if not process.is_daemon]
        if sessions:
            raise AccountError(
                "Codex sessions are still running and may overwrite auth.json:\n  "
                f"{describe_processes(sessions)}\nexit them (e.g. /quit in each terminal) first, or pass --force"
            )
        if any(process.is_daemon for process in processes):
            if not (args.yes or ask_yes_no("Stop the Codex background server (app-server daemon)?")):
                raise AccountError("the Codex app-server daemon is running; auth.json was not changed")
            stop_daemon()
            remaining = running_codex_processes()
            if remaining:
                raise AccountError(
                    f"Codex started again while switching:\n  {describe_processes(remaining)}"
                )

    # Read after quitting: the app may refresh tokens while shutting down.
    current = read_login(auth_file(home))
    if current is not None:
        current_name = profile_for_key(home, current.key)
        if current_name is None and not args.force:
            raise AccountError(
                f"active login is not saved ({current.label()}); "
                "run `codex-account save <name>` first, or pass --force to discard it"
            )
        if current_name is not None and current.raw != profile_file(home, current_name).read_bytes():
            write_secret(profile_file(home, current_name), current.raw)
        if current.key == target.key:
            target = read_login(target_path) or target

    write_secret(auth_file(home), target.raw)
    print(f"Codex account: {args.name} ({target.label()})")

    if reopen:
        subprocess.run(["/usr/bin/open", "-b", APP_BUNDLE_ID])
    return 0


def command_remove(args: argparse.Namespace) -> int:
    home = codex_home()
    path = profile_file(home, args.name)
    login = read_login(path)
    if login is None:
        raise AccountError(f"profile {args.name!r} not found")
    path.unlink()
    print(f"removed {args.name}")
    current = read_login(auth_file(home))
    if current and current.key == login.key:
        print("the active login stays in auth.json; save it again before switching away")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="codex-account",
        description="Switch Codex between saved ChatGPT logins.",
    )
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("list", help="list saved profiles").set_defaults(func=command_list)
    sub.add_parser("current", help="show the active profile").set_defaults(func=command_current)

    save = sub.add_parser("save", help="save the active login as a profile")
    save.add_argument("name")
    save.add_argument("--force", action="store_true", help="replace a profile holding another login")
    save.set_defaults(func=command_save)

    add = sub.add_parser("add", help="log in to another account without touching the active one")
    add.add_argument("name")
    add.add_argument("login_args", nargs=argparse.REMAINDER, help="extra `codex login` options, e.g. --device-auth")
    add.set_defaults(func=command_add)

    use = sub.add_parser("use", help="switch the active login")
    use.add_argument("name")
    use.add_argument("-y", "--yes", action="store_true", help="quit the Codex app without asking")
    use.add_argument("--no-reopen", action="store_true", help="leave the Codex app closed afterwards")
    use.add_argument("--force", action="store_true", help="switch even if Codex is running or the login is unsaved")
    use.set_defaults(func=command_use)

    remove = sub.add_parser("remove", help="delete a saved profile")
    remove.add_argument("name")
    remove.set_defaults(func=command_remove)
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except AccountError as exc:
        print(f"codex-account: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
