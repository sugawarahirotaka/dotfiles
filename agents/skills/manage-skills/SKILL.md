---
name: manage-skills
description: Create, update, install, vendor, remove, move, rename, or change Git management for personal agent skills shared by Codex and Claude Code, while preserving provenance, plugin boundaries, safe per-skill symlinks, validation, and focused commits. Use whenever skill ownership, installation, storage, synchronization, target agents, or lifecycle management changes.
---

# Manage Skills

Manage personal skills through the dotfiles registry without disturbing system, plugin, external, or project-owned skills of either agent.

## Layout

- `~/dotfiles/agents/skills/<skill-name>/`: the only source of owned and vendored skills.
- `~/dotfiles/agents/skills.json`: one entry per source skill, with `targets` listing the agents (`codex`, `claude`) that receive it.
- `~/dotfiles/.codex/inventory.json`: what Codex installed itself (plugins, system and project skills). It is a reinstall record, not a deployment source.
- Deployment links each targeted skill into `~/.codex/skills/<skill-name>` and `~/.claude/skills/<skill-name>` (or `$CLAUDE_CONFIG_DIR/skills`).

## Workflow

1. Read `agents/skills.json` and `.codex/inventory.json`, and inspect the current `~/.codex/skills` and `~/.claude/skills` entries, symlink targets, plugin-provided skill names, Git boundaries, and working-tree state before changing anything.
2. Create or update an owned skill only at `~/dotfiles/agents/skills/<skill-name>/`. Never create its source directory directly under an agent's skills directory.
3. Choose `targets` from what the skill depends on. Include `claude` only when the skill does not rely on Codex-only tools, logs, plugins, or thread IDs, and keep descriptions free of agent product names so both agents trigger on the same requests.
4. For an external skill, establish its upstream URL, immutable commit, tag, or version, license, dependencies, generated-file status, and local modifications before choosing `vendored` or `external`.
5. Treat plugin skills as plugin components by default. Record plugin installation metadata in the inventory instead of copying plugin caches or separating a skill that depends on plugin MCP servers, apps, permissions, runtimes, or assets.
6. Never modify or copy `~/.codex/skills/.system`, agent runtime directories, plugin caches, credentials, machine state, virtual environments, caches, or build outputs.
7. Add or update exactly one entry in `agents/skills.json` for a source skill, or in `.codex/inventory.json` for a Codex-installed one. Preserve `project` sources such as vault-managed skills and keep `unknown` items out of dotfiles until ownership is established.
8. Run `~/dotfiles/scripts/deploy-skills.zsh` to create per-skill symlinks for every agent present on this machine. Do not symlink a whole skills directory. Resolve any collision explicitly and preserve the displaced item in a timestamped backup.
9. Run `~/dotfiles/scripts/check-skills.zsh`, plus tests belonging to the changed skill. Confirm relative references, scripts, references, assets, provenance metadata, symlinks, duplicate names, nested Git repositories, caches, secrets, and large files.
10. Unless the user explicitly says not to commit, run `~/dotfiles/scripts/finalize-skill.zsh <skill-name>` after validation. The command must commit only the target skill, registry, and required deployment files.
11. Push only when the user explicitly requests it.

## Classification Rules

- `owned`: user-authored source lives in `~/dotfiles/agents/skills` and is linked per skill.
- `vendored`: a license-compatible, self-contained external snapshot lives in dotfiles with immutable upstream metadata and license text.
- `plugin`: the plugin is reinstalled from its marketplace; never copy `~/.codex/plugins/cache`.
- `external`: preserve a fixed URL and revision for reinstallation when redistribution is unclear or inappropriate.
- `project`: the named project or vault remains the source of truth.
- `system`: the agent owns the files; inventory them without copying or modifying them.
- `unknown`: stop before copying or committing until provenance and ownership are known.

When updating a vendored skill, replace only from the recorded upstream revision, update its upstream metadata and registry in the same commit, preserve required license notices, and record whether local changes exist.

## Commands

Preview links for the agents on this machine, or for named agents:

```zsh
~/dotfiles/scripts/deploy-skills.zsh --dry-run
~/dotfiles/scripts/deploy-skills.zsh --agents codex,claude --dry-run
```

Validate the registry, sources, and links:

```zsh
~/dotfiles/scripts/check-skills.zsh
```

Validate and commit one skill without pushing:

```zsh
~/dotfiles/scripts/finalize-skill.zsh <skill-name>
```
