# Codex Skill management

The canonical inventory is [`.codex/skills-registry.json`](../.codex/skills-registry.json). Do not maintain a second hand-written skill list in documentation or shell code.

## Storage model

Owned and vendored sources live under `.codex/skills/<skill-name>/`. Deployment creates one symlink per managed skill under `~/.codex/skills`; it never replaces the whole directory. This leaves room for Codex-managed, plugin, external, and project-specific skills.

The current desktop environment demonstrably discovers `~/.codex/skills`, including the existing vault-backed `codex-session-memory` symlink. Current OpenAI documentation describes `~/.agents/skills` as the general user discovery location and confirms that symlinked skill folders are supported. This repository intentionally retains the working `~/.codex/skills` layout for compatibility instead of performing an unrequested global migration.

- OpenAI local skill discovery: <https://developers.openai.com/codex/build-skills>
- OpenAI plugin installation: <https://developers.openai.com/codex/plugins>

The GitHub repository is public and has no repository-wide license. Owned skills are therefore recorded as `UNLICENSED`; review personal paths and bundled assets before pushing. Vendored content must carry its upstream license and immutable provenance metadata.

## Commands

Preview or deploy the managed links:

```zsh
./scripts/deploy-codex-skills.zsh --dry-run
./scripts/deploy-codex-skills.zsh --non-interactive
```

`./deploy.sh` accepts the same flags and also deploys `.codex/AGENTS.md`. Conflicting real directories, different links, and broken links are preserved. Interactive replacement moves the displaced item under `~/.codex/skill-backups/<timestamp>/`; non-interactive deployment reports the conflict and fails.

Validate registry consistency, sources, links, collisions, provenance, forbidden generated files, nested Git repositories, likely secrets, large files, and the Obsidian project link:

```zsh
./scripts/check-codex-skills.zsh
```

Finalize one owned or vendored skill after deployment:

```zsh
./scripts/finalize-codex-skill.zsh <skill-name>
```

The finalize command runs the skill's tests when a supported test layout exists, rejects unrelated staged changes, stages only the target skill and shared management files, creates no empty commit, and never pushes.

## Updating external and plugin skills

For a vendored update, fetch an immutable upstream revision, verify the license, compare the recorded upstream subdirectory, replace only that snapshot, and update both `UPSTREAM.json` and the registry before finalizing. Never bring an upstream `.git`, virtual environment, cache, log, or generated test output into the repository.

Plugin skills stay attached to their plugin. Reinstall them through the ChatGPT or Codex desktop Plugins tab, or open `/plugins` in Codex CLI, using the plugin identifier and dependency notes in the registry. Do not copy `~/.codex/plugins/cache`; versions, apps, MCP servers, and permissions must be restored through the plugin installation flow.

No hook automatically commits skills. The single routing sentence in `.codex/AGENTS.md`, `manage-codex-skills`, the check command, and the finalize command provide the intended workflow.
