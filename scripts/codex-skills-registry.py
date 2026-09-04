#!/usr/bin/env python3
"""Parse and validate the canonical Codex skill registry."""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote


KINDS = {"owned", "vendored", "plugin", "external", "project", "system", "unknown"}
MANAGED_KINDS = {"owned", "vendored"}
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
LINK_RE = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
SUSPICIOUS_NAMES = re.compile(
    r"^(?:\.env(?:\..+)?|id_(?:rsa|dsa|ecdsa|ed25519)|credentials(?:\..+)?|"
    r"secrets?(?:\..+)?|.*\.(?:p12|pfx|pem|key))$",
    re.IGNORECASE,
)
SECRET_PATTERNS = (
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"\bAKIA[0-9A-Z]{16}\b"),
    re.compile(r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    re.compile(r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b"),
    re.compile(r"\bsk-[A-Za-z0-9]{24,}\b"),
)
CACHE_NAMES = {".venv", ".pytest_cache", "__pycache__", ".mypy_cache", ".ruff_cache", ".cache"}
MAX_FILE_BYTES = 5 * 1024 * 1024


class RegistryError(ValueError):
    pass


def load_registry(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RegistryError(f"registry not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RegistryError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise RegistryError("registry root must be an object")
    return data


def validate_registry(data: dict) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    skills = data.get("skills")
    plugins = data.get("plugins")
    if not isinstance(skills, list):
        return errors + ["skills must be an array"]
    if not isinstance(plugins, list):
        return errors + ["plugins must be an array"]

    plugin_ids: set[str] = set()
    for index, plugin in enumerate(plugins):
        if not isinstance(plugin, dict):
            errors.append(f"plugins[{index}] must be an object")
            continue
        plugin_id = plugin.get("id")
        if not isinstance(plugin_id, str) or not plugin_id:
            errors.append(f"plugins[{index}] is missing id")
            continue
        if plugin_id in plugin_ids:
            errors.append(f"duplicate plugin id: {plugin_id}")
        plugin_ids.add(plugin_id)
        for field in ("marketplace", "version", "license", "reinstall"):
            if not isinstance(plugin.get(field), str) or not plugin[field].strip():
                errors.append(f"plugin {plugin_id} is missing {field}")
        for field in ("dependencies", "permissions"):
            if not isinstance(plugin.get(field), list):
                errors.append(f"plugin {plugin_id} field {field} must be an array")

    names: set[str] = set()
    for index, skill in enumerate(skills):
        if not isinstance(skill, dict):
            errors.append(f"skills[{index}] must be an object")
            continue
        name = skill.get("name")
        kind = skill.get("kind")
        if not isinstance(name, str) or not NAME_RE.fullmatch(name):
            errors.append(f"skills[{index}] has invalid name: {name!r}")
            continue
        if name in names:
            errors.append(f"duplicate skill name in registry: {name}")
        names.add(name)
        if kind not in KINDS:
            errors.append(f"skill {name} has invalid kind: {kind!r}")
        if not isinstance(skill.get("enabled"), bool):
            errors.append(f"skill {name} enabled must be boolean")
        for field in ("local_path", "destination", "upstream", "version", "plugin_id", "license", "notes"):
            if not isinstance(skill.get(field), str):
                errors.append(f"skill {name} field {field} must be a string")
        if not isinstance(skill.get("dependencies"), list):
            errors.append(f"skill {name} dependencies must be an array")
        if kind in MANAGED_KINDS:
            expected_local = f".codex/skills/{name}"
            expected_destination = f"~/.codex/skills/{name}"
            if skill.get("local_path") != expected_local:
                errors.append(f"managed skill {name} local_path must be {expected_local}")
            if skill.get("destination") != expected_destination:
                errors.append(f"managed skill {name} destination must be {expected_destination}")
        if kind == "vendored":
            for field in ("upstream", "version", "license"):
                if not skill.get(field):
                    errors.append(f"vendored skill {name} is missing {field}")
        if kind == "plugin":
            plugin_id = skill.get("plugin_id")
            if not plugin_id:
                errors.append(f"plugin skill {name} is missing plugin_id")
            elif plugin_id not in plugin_ids:
                errors.append(f"plugin skill {name} references unknown plugin_id {plugin_id}")
    return errors


def skill_map(data: dict) -> dict[str, dict]:
    return {entry["name"]: entry for entry in data.get("skills", []) if isinstance(entry, dict) and "name" in entry}


def expand_user_path(value: str, home: Path) -> Path:
    if value == "~":
        return home
    if value.startswith("~/"):
        return home / value[2:]
    return Path(value)


def parse_frontmatter(path: Path) -> tuple[dict[str, str], list[str]]:
    errors: list[str] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeDecodeError) as exc:
        return {}, [f"cannot read {path}: {exc}"]
    if not lines or lines[0] != "---":
        return {}, [f"{path}: missing opening YAML frontmatter delimiter"]
    try:
        end = lines.index("---", 1)
    except ValueError:
        return {}, [f"{path}: missing closing YAML frontmatter delimiter"]
    fields: dict[str, str] = {}
    for lineno, line in enumerate(lines[1:end], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            errors.append(f"{path}:{lineno}: unsupported frontmatter line")
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        value = value.strip()
        if value.startswith(("\"", "'")) and value.endswith(value[:1]) and len(value) >= 2:
            value = value[1:-1]
        fields[key] = value
    return fields, errors


def validate_skill(path: Path, expected_name: str) -> list[str]:
    errors: list[str] = []
    if not path.is_dir():
        return [f"skill directory missing: {path}"]
    skill_md = path / "SKILL.md"
    if not skill_md.is_file():
        return [f"missing SKILL.md: {path}"]
    fields, frontmatter_errors = parse_frontmatter(skill_md)
    errors.extend(frontmatter_errors)
    if fields.get("name") != expected_name:
        errors.append(f"{skill_md}: frontmatter name {fields.get('name')!r} does not match {expected_name!r}")
    if not fields.get("description"):
        errors.append(f"{skill_md}: frontmatter description is missing or empty")

    for markdown_path in path.rglob("*.md"):
        try:
            markdown = markdown_path.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError):
            continue
        prose_lines: list[str] = []
        in_fence = False
        for line in markdown.splitlines():
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if not in_fence:
                prose_lines.append(re.sub(r"`[^`]*`", "", line))
        prose = "\n".join(prose_lines)
        for target in LINK_RE.findall(prose):
            target = target.strip().split()[0].strip("<>")
            if not target or target.startswith(("#", "http://", "https://", "mailto:")):
                continue
            target = unquote(target.split("#", 1)[0])
            if target.startswith("/"):
                errors.append(f"{markdown_path}: local Markdown link must be relative: {target}")
                continue
            resolved = (markdown_path.parent / target).resolve()
            try:
                resolved.relative_to(path.resolve())
            except ValueError:
                errors.append(f"{markdown_path}: relative link escapes skill directory: {target}")
                continue
            if not resolved.exists():
                errors.append(f"{markdown_path}: broken relative link: {target}")

    for root, dirs, files in os.walk(path, followlinks=False):
        root_path = Path(root)
        for dirname in list(dirs):
            child = root_path / dirname
            if dirname == ".git":
                errors.append(f"nested .git is forbidden: {child}")
            if dirname in CACHE_NAMES:
                errors.append(f"cache or virtual environment is forbidden: {child}")
        for filename in files:
            child = root_path / filename
            if SUSPICIOUS_NAMES.fullmatch(filename):
                errors.append(f"secret-like filename is forbidden: {child}")
            try:
                size = child.stat().st_size
            except OSError as exc:
                errors.append(f"cannot stat {child}: {exc}")
                continue
            if size > MAX_FILE_BYTES:
                errors.append(f"file exceeds 5 MiB limit: {child} ({size} bytes)")
            if size <= 1024 * 1024:
                try:
                    content = child.read_text(encoding="utf-8")
                except (OSError, UnicodeDecodeError):
                    continue
                if child.parent.name == "scripts" and child.suffix == ".py":
                    try:
                        compile(content, str(child), "exec")
                    except SyntaxError as exc:
                        errors.append(f"invalid Python script {child}:{exc.lineno}: {exc.msg}")
                for pattern in SECRET_PATTERNS:
                    if pattern.search(content):
                        errors.append(f"secret-like content detected in {child}: {pattern.pattern}")
                        break
    return errors


def registry_paths(args: argparse.Namespace) -> tuple[Path, Path, Path]:
    repo = Path(args.repo).expanduser().resolve()
    registry = Path(args.registry).expanduser().resolve() if args.registry else repo / ".codex/skills-registry.json"
    home = Path(args.home).expanduser().resolve()
    return repo, registry, home


def command_validate(args: argparse.Namespace) -> int:
    _, registry, _ = registry_paths(args)
    try:
        data = load_registry(registry)
        errors = validate_registry(data)
    except RegistryError as exc:
        errors = [str(exc)]
    for error in errors:
        print(f"[error] {error}", file=sys.stderr)
    if not errors:
        print(f"[ok] registry valid: {registry}")
    return bool(errors)


def command_managed_links(args: argparse.Namespace) -> int:
    repo, registry, _ = registry_paths(args)
    data = load_registry(registry)
    errors = validate_registry(data)
    if errors:
        raise RegistryError("; ".join(errors))
    for skill in data["skills"]:
        if skill["kind"] in MANAGED_KINDS and skill["enabled"]:
            source = (repo / skill["local_path"]).resolve()
            sys.stdout.buffer.write(skill["name"].encode() + b"\0" + str(source).encode() + b"\0")
    return 0


def command_plugin_names(args: argparse.Namespace) -> int:
    _, registry, _ = registry_paths(args)
    data = load_registry(registry)
    names = {skill["name"] for skill in data.get("skills", []) if skill.get("kind") == "plugin" and skill.get("enabled")}
    if args.cache_root:
        cache_root = Path(args.cache_root).expanduser()
        if cache_root.is_dir():
            for skill_md in cache_root.rglob("SKILL.md"):
                if skill_md.parent.parent.name == "skills" and NAME_RE.fullmatch(skill_md.parent.name):
                    names.add(skill_md.parent.name)
    for name in sorted(names):
        print(name)
    return 0


def command_field(args: argparse.Namespace) -> int:
    _, registry, _ = registry_paths(args)
    data = load_registry(registry)
    entry = skill_map(data).get(args.name)
    if entry is None:
        print(f"skill is not registered: {args.name}", file=sys.stderr)
        return 1
    value = entry.get(args.field)
    if isinstance(value, (str, int, float, bool)):
        print(str(value).lower() if isinstance(value, bool) else value)
        return 0
    print(json.dumps(value, ensure_ascii=False))
    return 0


def command_validate_skill(args: argparse.Namespace) -> int:
    errors = validate_skill(Path(args.path).expanduser().resolve(), args.name)
    for error in errors:
        print(f"[error] {error}", file=sys.stderr)
    if not errors:
        print(f"[ok] skill valid: {args.name}")
    return bool(errors)


def direct_skill_locations(root: Path) -> dict[str, list[Path]]:
    result: dict[str, list[Path]] = {}
    if not root.is_dir():
        return result
    for child in root.iterdir():
        if child.name.startswith("."):
            continue
        if (child / "SKILL.md").is_file():
            result.setdefault(child.name, []).append(child)
    return result


def command_check(args: argparse.Namespace) -> int:
    repo, registry, home = registry_paths(args)
    errors: list[str] = []
    warnings: list[str] = []
    try:
        data = load_registry(registry)
    except RegistryError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1
    errors.extend(validate_registry(data))
    entries = skill_map(data)

    managed_root = repo / ".codex/skills"
    registered_managed = {name for name, entry in entries.items() if entry.get("kind") in MANAGED_KINDS}
    if managed_root.is_dir():
        for child in managed_root.iterdir():
            if child.is_dir() and (child / "SKILL.md").is_file() and child.name not in registered_managed:
                errors.append(f"dotfiles skill is not registered: {child}")

    for name in sorted(registered_managed):
        entry = entries[name]
        source = (repo / entry["local_path"]).resolve()
        try:
            source.relative_to(managed_root.resolve())
        except ValueError:
            errors.append(f"managed skill source is outside dotfiles: {name}: {source}")
        errors.extend(validate_skill(source, name))
        if entry.get("enabled"):
            destination = expand_user_path(entry["destination"], home)
            if not destination.is_symlink():
                errors.append(f"managed skill destination is not a symlink: {destination}")
            else:
                try:
                    if destination.resolve(strict=True) != source.resolve(strict=True):
                        errors.append(f"managed skill symlink points elsewhere: {destination} -> {os.readlink(destination)}")
                except FileNotFoundError:
                    errors.append(f"broken managed skill symlink: {destination}")
        if entry.get("kind") == "vendored" and source.is_dir():
            metadata_path = source / "UPSTREAM.json"
            try:
                metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError) as exc:
                errors.append(f"invalid or missing vendored metadata {metadata_path}: {exc}")
            else:
                for field in ("upstream_url", "commit", "retrieved_at", "license", "update_method", "local_changes"):
                    if field not in metadata or metadata[field] in (None, ""):
                        errors.append(f"vendored metadata missing {field}: {metadata_path}")
                if metadata.get("upstream_url") != entry.get("upstream"):
                    errors.append(f"vendored upstream mismatch for {name}")
                if metadata.get("commit") != entry.get("version"):
                    errors.append(f"vendored version mismatch for {name}")
                license_file = metadata.get("license_file")
                if not license_file or not (source / license_file).is_file():
                    errors.append(f"vendored license file missing for {name}")

    codex_root = Path(args.codex_skills_root).expanduser().resolve() if args.codex_skills_root else home / ".codex/skills"
    agents_root = Path(args.agents_skills_root).expanduser().resolve() if args.agents_skills_root else home / ".agents/skills"
    for root in (codex_root, agents_root):
        if root.is_dir():
            for child in root.iterdir():
                if child.is_symlink() and not child.exists():
                    errors.append(f"broken skill symlink: {child} -> {os.readlink(child)}")

    locations: dict[str, list[Path]] = {}
    for root in (codex_root, agents_root):
        for name, paths in direct_skill_locations(root).items():
            locations.setdefault(name, []).extend(paths)
    plugin_skill_names = {entry["name"] for entry in data["skills"] if entry.get("kind") == "plugin" and entry.get("enabled")}
    plugin_cache = Path(args.plugin_cache_root).expanduser() if args.plugin_cache_root else home / ".codex/plugins/cache"
    if plugin_cache.is_dir():
        for plugin_skill_md in plugin_cache.rglob("SKILL.md"):
            if plugin_skill_md.parent.parent.name == "skills" and NAME_RE.fullmatch(plugin_skill_md.parent.name):
                plugin_skill_names.add(plugin_skill_md.parent.name)

    for name, paths in locations.items():
        resolved = {str(path.resolve()) for path in paths}
        if len(paths) > 1:
            errors.append(f"duplicate discovered skill name {name}: {', '.join(map(str, paths))}")
        if name in plugin_skill_names:
            errors.append(f"local skill collides with plugin skill name {name}: {', '.join(sorted(resolved))}")

    project_entry = entries.get("codex-session-memory")
    if project_entry and project_entry.get("kind") == "project" and project_entry.get("enabled"):
        source = expand_user_path(project_entry["local_path"], home)
        destination = expand_user_path(project_entry["destination"], home)
        if not source.is_dir() or not (source / "SKILL.md").is_file():
            errors.append(f"Obsidian project skill source is missing: {source}")
        if not destination.is_symlink():
            errors.append(f"Obsidian project skill link is missing: {destination}")
        else:
            try:
                if destination.resolve(strict=True) != source.resolve(strict=True):
                    errors.append(f"Obsidian project skill link points elsewhere: {destination}")
            except FileNotFoundError:
                errors.append(f"Obsidian project skill link is broken: {destination}")

    if any(entry.get("name") == "daily-neruwa" and entry.get("kind") == "owned" for entry in data["skills"]):
        daily = managed_root / "daily-neruwa"
        for forbidden in (".git", ".venv", ".pytest_cache", "__pycache__"):
            if any(path.name == forbidden for path in daily.rglob(forbidden)):
                errors.append(f"daily-neruwa contains forbidden path: {forbidden}")

    for warning in warnings:
        print(f"[warn] {warning}")
    for error in errors:
        print(f"[error] {error}", file=sys.stderr)
    if errors:
        print(f"[failed] {len(errors)} Codex skill issue(s)", file=sys.stderr)
        return 1
    print(f"[ok] {len(entries)} registered Codex skills checked")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--registry")
    parser.add_argument("--home", default=os.environ.get("HOME", ""))
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("validate").set_defaults(func=command_validate)
    subparsers.add_parser("managed-links").set_defaults(func=command_managed_links)

    plugin_names = subparsers.add_parser("plugin-names")
    plugin_names.add_argument("--cache-root")
    plugin_names.set_defaults(func=command_plugin_names)

    field = subparsers.add_parser("field")
    field.add_argument("name")
    field.add_argument("field")
    field.set_defaults(func=command_field)

    validate_skill_parser = subparsers.add_parser("validate-skill")
    validate_skill_parser.add_argument("name")
    validate_skill_parser.add_argument("path")
    validate_skill_parser.set_defaults(func=command_validate_skill)

    check = subparsers.add_parser("check")
    check.add_argument("--codex-skills-root")
    check.add_argument("--agents-skills-root")
    check.add_argument("--plugin-cache-root")
    check.set_defaults(func=command_check)
    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if not args.home:
        parser.error("HOME or --home is required")
    try:
        return int(args.func(args))
    except RegistryError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
