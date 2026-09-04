---
name: manage-codex-skills
description: Create, update, install, vendor, remove, move, rename, or change Git management for Codex skills while preserving provenance, plugin boundaries, safe per-skill symlinks, validation, and focused commits. Use whenever Codex Skill ownership, installation, storage, synchronization, or lifecycle management changes.
---

# Manage Codex Skills

Manage personal Codex skills through the dotfiles registry without disturbing system, plugin, external, or project-owned skills.

## Workflow

1. Read `~/dotfiles/.codex/skills-registry.json` and inspect the current `~/.codex/skills` entries, symlink targets, plugin-provided skill names, Git boundaries, and working-tree state before changing anything.
2. Create or update an owned skill only at `~/dotfiles/.codex/skills/<skill-name>/`. Never create its source directory directly under `~/.codex/skills`.
3. For an external skill, establish its upstream URL, immutable commit, tag, or version, license, dependencies, generated-file status, and local modifications before choosing `vendored` or `external`.
4. Treat plugin skills as plugin components by default. Record plugin installation metadata instead of copying plugin caches or separating a skill that depends on plugin MCP servers, apps, permissions, runtimes, or assets.
5. Never modify or copy `~/.codex/skills/.system`, Codex runtime directories, plugin caches, credentials, machine state, virtual environments, caches, or build outputs.
6. Add or update exactly one canonical entry in `~/dotfiles/.codex/skills-registry.json`. Preserve `project` sources such as vault-managed skills and keep `unknown` items out of dotfiles until ownership is established.
7. Run `~/dotfiles/scripts/deploy-codex-skills.zsh` to create the per-skill symlink under `~/.codex/skills`. Do not symlink the whole skills directory. Resolve any collision explicitly and preserve the displaced item in a timestamped backup.
8. Run `~/dotfiles/scripts/check-codex-skills.zsh`, plus tests belonging to the changed skill. Confirm relative references, scripts, references, assets, provenance metadata, symlinks, duplicate names, nested Git repositories, caches, secrets, and large files.
9. Unless the user explicitly says not to commit, run `~/dotfiles/scripts/finalize-codex-skill.zsh <skill-name>` after validation. The command must commit only the target skill, registry, and required deployment files.
10. Push only when the user explicitly requests it.

## Classification Rules

- `owned`: user-authored source lives in `~/dotfiles/.codex/skills` and is linked per skill.
- `vendored`: a license-compatible, self-contained external snapshot lives in dotfiles with immutable upstream metadata and license text.
- `plugin`: the plugin is reinstalled from its marketplace; never copy `~/.codex/plugins/cache`.
- `external`: preserve a fixed URL and revision for reinstallation when redistribution is unclear or inappropriate.
- `project`: the named project or vault remains the source of truth.
- `system`: Codex owns the files; inventory them without copying or modifying them.
- `unknown`: stop before copying or committing until provenance and ownership are known.

When updating a vendored skill, replace only from the recorded upstream revision, update its upstream metadata and registry in the same commit, preserve required license notices, and record whether local changes exist.

## Commands

Preview links:

```zsh
~/dotfiles/scripts/deploy-codex-skills.zsh --dry-run
```

Validate the complete inventory:

```zsh
~/dotfiles/scripts/check-codex-skills.zsh
```

Validate and commit one skill without pushing:

```zsh
~/dotfiles/scripts/finalize-codex-skill.zsh <skill-name>
```
