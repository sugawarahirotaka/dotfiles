#!/usr/bin/env python3
"""Parse and validate the agent skill registry and the Codex inventory.

agents/skills.json lists the skills whose sources live in this repository
(owned and vendored) and the agents each one is deployed to.
.codex/inventory.json records what Codex itself installed (plugins, system
and project skills) so it can be reinstalled; those are never deployed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote


AGENTS = ("codex", "claude")
MANAGED_KINDS = {"owned", "vendored"}
INVENTORY_KINDS = {"plugin", "external", "project", "system", "unknown"}
MANAGED_ROOT = "agents/skills"
DEFAULT_REGISTRY = "agents/skills.json"
DEFAULT_INVENTORY = ".codex/inventory.json"
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


def load_json(path: Path, label: str) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise RegistryError(f"{label} not found: {path}") from exc
    except json.JSONDecodeError as exc:
        raise RegistryError(f"invalid JSON in {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise RegistryError(f"{label} root must be an object")
    return data


def load_inventory(path: Path) -> dict:
    if not path.exists():
        return {"schema_version": 1, "plugins": [], "skills": []}
    return load_json(path, "inventory")


def validate_registry(data: dict) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 2:
        errors.append("registry schema_version must be 2")
    skills = data.get("skills")
    if not isinstance(skills, list):
        return errors + ["registry skills must be an array"]

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
        if kind not in MANAGED_KINDS:
            errors.append(f"skill {name} kind must be owned or vendored, not {kind!r}")
        targets = skill.get("targets")
        if (
            not isinstance(targets, list)
            or not targets
            or len(set(targets)) != len(targets)
            or any(target not in AGENTS for target in targets)
        ):
            errors.append(f"skill {name} targets must be a non-empty list drawn from {list(AGENTS)}")
        for field in ("upstream", "version", "license", "notes"):
            if not isinstance(skill.get(field), str):
                errors.append(f"skill {name} field {field} must be a string")
        if not isinstance(skill.get("dependencies"), list):
            errors.append(f"skill {name} dependencies must be an array")
        if kind == "vendored":
            for field in ("upstream", "version", "license"):
                if not skill.get(field):
                    errors.append(f"vendored skill {name} is missing {field}")
    return errors


def validate_inventory(data: dict, managed_names: set[str]) -> list[str]:
    errors: list[str] = []
    if data.get("schema_version") != 1:
        errors.append("inventory schema_version must be 1")
    skills = data.get("skills")
    plugins = data.get("plugins")
    if not isinstance(skills, list):
        return errors + ["inventory skills must be an array"]
    if not isinstance(plugins, list):
        return errors + ["inventory plugins must be an array"]

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
            errors.append(f"inventory skills[{index}] must be an object")
            continue
        name = skill.get("name")
        kind = skill.get("kind")
        if not isinstance(name, str) or not NAME_RE.fullmatch(name):
            errors.append(f"inventory skills[{index}] has invalid name: {name!r}")
            continue
        if name in names:
            errors.append(f"duplicate skill name in inventory: {name}")
        if name in managed_names:
            errors.append(f"skill {name} is in both the registry and the Codex inventory")
        names.add(name)
        if kind not in INVENTORY_KINDS:
            errors.append(f"inventory skill {name} has invalid kind: {kind!r}")
        if not isinstance(skill.get("enabled"), bool):
            errors.append(f"inventory skill {name} enabled must be boolean")
        for field in ("local_path", "destination", "upstream", "version", "plugin_id", "license", "notes"):
            if not isinstance(skill.get(field), str):
                errors.append(f"inventory skill {name} field {field} must be a string")
        if not isinstance(skill.get("dependencies"), list):
            errors.append(f"inventory skill {name} dependencies must be an array")
        if kind == "plugin":
            plugin_id = skill.get("plugin_id")
            if not plugin_id:
                errors.append(f"plugin skill {name} is missing plugin_id")
            elif plugin_id not in plugin_ids:
                errors.append(f"plugin skill {name} references unknown plugin_id {plugin_id}")
    return errors


def load_all(args: argparse.Namespace) -> tuple[Path, dict, dict, Path]:
    """Load and validate both files; raise RegistryError on any problem."""
    repo, registry_path, inventory_path, home = registry_paths(args)
    registry = load_json(registry_path, "registry")
    inventory = load_inventory(inventory_path)
    errors = validate_registry(registry)
    managed_names = {s["name"] for s in registry.get("skills", []) if isinstance(s, dict) and "name" in s}
    errors += validate_inventory(inventory, managed_names)
    if errors:
        raise RegistryError("; ".join(errors))
    return repo, registry, inventory, home


def skill_map(data: dict) -> dict[str, dict]:
    return {entry["name"]: entry for entry in data.get("skills", []) if isinstance(entry, dict) and "name" in entry}


def managed_source(repo: Path, name: str) -> Path:
    return repo / MANAGED_ROOT / name


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




def registry_paths(args: argparse.Namespace) -> tuple[Path, Path, Path, Path]:
    repo = Path(args.repo).expanduser().resolve()
    registry = Path(args.registry).expanduser().resolve() if args.registry else repo / DEFAULT_REGISTRY
    inventory = Path(args.inventory).expanduser().resolve() if args.inventory else repo / DEFAULT_INVENTORY
    home = Path(args.home).expanduser().resolve()
    return repo, registry, inventory, home


def command_validate(args: argparse.Namespace) -> int:
    try:
        load_all(args)
    except RegistryError as exc:
        for error in str(exc).split("; "):
            print(f"[error] {error}", file=sys.stderr)
        return 1
    print("[ok] registry and inventory valid")
    return 0


def command_managed_links(args: argparse.Namespace) -> int:
    repo, registry, _, _ = load_all(args)
    for skill in registry["skills"]:
        if args.agent in skill["targets"]:
            try:
                source = managed_source(repo, skill["name"]).resolve()
            except (OSError, RuntimeError) as exc:
                raise RegistryError(f"cannot resolve source for {skill['name']}: {exc}") from exc
            sys.stdout.buffer.write(skill["name"].encode() + b"\0" + str(source).encode() + b"\0")
    return 0


def plugin_skill_names(inventory: dict, cache_root: Path | None) -> set[str]:
    names = {
        skill["name"]
        for skill in inventory.get("skills", [])
        if skill.get("kind") == "plugin" and skill.get("enabled")
    }
    if cache_root and cache_root.is_dir():
        for skill_md in cache_root.rglob("SKILL.md"):
            if skill_md.parent.parent.name == "skills" and NAME_RE.fullmatch(skill_md.parent.name):
                names.add(skill_md.parent.name)
    return names


def command_plugin_names(args: argparse.Namespace) -> int:
    _, _, inventory, _ = load_all(args)
    cache_root = Path(args.cache_root).expanduser() if args.cache_root else None
    for name in sorted(plugin_skill_names(inventory, cache_root)):
        print(name)
    return 0


def command_field(args: argparse.Namespace) -> int:
    _, registry, _, _ = load_all(args)
    entry = skill_map(registry).get(args.name)
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


def parse_agent_roots(values: list[str]) -> dict[str, Path]:
    roots: dict[str, Path] = {}
    for value in values:
        agent, sep, path = value.partition("=")
        if not sep or agent not in AGENTS or not path:
            raise RegistryError(f"--agent-root must be AGENT=PATH with AGENT in {list(AGENTS)}: {value}")
        roots[agent] = Path(path).expanduser().resolve()
    return roots


def check_link(destination: Path, source: Path) -> str | None:
    if not destination.is_symlink():
        return f"managed skill link is missing: {destination}"
    try:
        if destination.resolve(strict=True) != source.resolve(strict=True):
            return f"managed skill link points elsewhere: {destination} -> {os.readlink(destination)}"
    except FileNotFoundError:
        return f"broken managed skill link: {destination}"
    return None


def check_vendored_metadata(name: str, entry: dict, source: Path) -> list[str]:
    errors: list[str] = []
    metadata_path = source / "UPSTREAM.json"
    try:
        metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"invalid or missing vendored metadata {metadata_path}: {exc}"]
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
    return errors


def check_codex_discovery(args: argparse.Namespace, inventory: dict, codex_root: Path, home: Path) -> list[str]:
    """Codex also discovers ~/.agents/skills and plugin skills; names must stay unique."""
    errors: list[str] = []
    agents_root = Path(args.agents_skills_root).expanduser().resolve() if args.agents_skills_root else home / ".agents/skills"
    if agents_root.is_dir():
        for child in agents_root.iterdir():
            if child.is_symlink() and not child.exists():
                errors.append(f"broken skill symlink: {child} -> {os.readlink(child)}")

    locations: dict[str, list[Path]] = {}
    for root in (codex_root, agents_root):
        for name, paths in direct_skill_locations(root).items():
            locations.setdefault(name, []).extend(paths)
    cache_root = Path(args.plugin_cache_root).expanduser() if args.plugin_cache_root else home / ".codex/plugins/cache"
    plugin_names = plugin_skill_names(inventory, cache_root)
    for name, paths in locations.items():
        if len(paths) > 1:
            errors.append(f"duplicate discovered skill name {name}: {', '.join(map(str, paths))}")
        if name in plugin_names:
            resolved = sorted({str(path.resolve()) for path in paths})
            errors.append(f"local skill collides with plugin skill name {name}: {', '.join(resolved)}")

    for entry in inventory.get("skills", []):
        if entry.get("kind") != "project" or not entry.get("enabled"):
            continue
        source = expand_user_path(entry["local_path"], home)
        destination = expand_user_path(entry["destination"], home)
        if not source.is_dir() or not (source / "SKILL.md").is_file():
            errors.append(f"project skill source is missing: {source}")
        elif (problem := check_link(destination, source)) is not None:
            errors.append(f"project skill {entry['name']}: {problem}")
    return errors


def command_check(args: argparse.Namespace) -> int:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        repo, registry, inventory, home = load_all(args)
        agent_roots = parse_agent_roots(args.agent_root)
    except RegistryError as exc:
        for error in str(exc).split("; "):
            print(f"[error] {error}", file=sys.stderr)
        return 1
    entries = skill_map(registry)

    managed_root = repo / MANAGED_ROOT
    if managed_root.is_dir():
        for child in managed_root.iterdir():
            if child.is_dir() and (child / "SKILL.md").is_file() and child.name not in entries:
                errors.append(f"dotfiles skill is not registered: {child}")

    for name in sorted(entries):
        entry = entries[name]
        source = managed_source(repo, name)
        try:
            source.resolve().relative_to(managed_root.resolve())
        except ValueError:
            errors.append(f"managed skill source is outside dotfiles: {name}: {source.resolve()}")
        errors.extend(validate_skill(source.resolve(), name))
        if entry["kind"] == "vendored" and source.is_dir():
            errors.extend(check_vendored_metadata(name, entry, source))
        for agent, root in agent_roots.items():
            destination = root / name
            if agent in entry["targets"]:
                problem = check_link(destination, source)
                if problem:
                    errors.append(f"{agent}: {problem}")
            elif destination.is_symlink() and destination.exists() and destination.resolve() == source.resolve():
                warnings.append(f"{agent}: {name} is linked but not targeted; remove {destination} after checking it")

    for agent, root in agent_roots.items():
        if root.is_dir():
            for child in root.iterdir():
                if child.is_symlink() and not child.exists():
                    errors.append(f"{agent}: broken skill symlink: {child} -> {os.readlink(child)}")

    if "codex" in agent_roots:
        errors.extend(check_codex_discovery(args, inventory, agent_roots["codex"], home))

    daily = managed_root / "daily-neruwa"
    if daily.is_dir():
        for forbidden in (".git", ".venv", ".pytest_cache", "__pycache__"):
            if any(path.name == forbidden for path in daily.rglob(forbidden)):
                errors.append(f"daily-neruwa contains forbidden path: {forbidden}")

    for warning in warnings:
        print(f"[warn] {warning}")
    for error in errors:
        print(f"[error] {error}", file=sys.stderr)
    if errors:
        print(f"[failed] {len(errors)} skill issue(s)", file=sys.stderr)
        return 1
    checked = ", ".join(agent_roots) if agent_roots else "no agent links"
    print(f"[ok] {len(entries)} managed skills checked ({checked})")
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument("--registry")
    parser.add_argument("--inventory")
    parser.add_argument("--home", default=os.environ.get("HOME", ""))
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser("validate").set_defaults(func=command_validate)

    managed_links = subparsers.add_parser("managed-links")
    managed_links.add_argument("--agent", required=True, choices=AGENTS)
    managed_links.set_defaults(func=command_managed_links)

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
    check.add_argument("--agent-root", action="append", default=[], metavar="AGENT=PATH")
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
