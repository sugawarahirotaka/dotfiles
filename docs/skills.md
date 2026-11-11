# Agent skill management

Codex and Claude Code share one set of skill sources. Neither agent is the default: each machine gets the agents whose configuration directory exists, and each skill lists the agents it targets.

## Layout

| Path | Role |
| --- | --- |
| [`agents/skills/<name>/`](../agents/skills) | The only source of owned and vendored skills |
| [`agents/skills.json`](../agents/skills.json) | One entry per source skill, with `targets` (`codex`, `claude`) |
| [`agents/AGENTS.md`](../agents/AGENTS.md) | Global instructions, linked as `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` |
| [`.codex/inventory.json`](../.codex/inventory.json) | What Codex installed itself (plugins, system and project skills), kept for reinstallation only |

Do not maintain a second hand-written skill list in documentation or shell code.

Deployment creates one symlink per targeted skill under each agent's skills directory and never replaces the whole directory, leaving room for skills the agents manage themselves:

| Agent | Configuration directory | Skills | Instructions |
| --- | --- | --- | --- |
| Codex | `$CODEX_HOME`, else `~/.codex` | `skills/<name>` | `AGENTS.md` |
| Claude Code | `$CLAUDE_CONFIG_DIR`, else `~/.claude` | `skills/<name>` | `CLAUDE.md` |

When `DOTFILES_TARGET_HOME` is set, both agents use that home's `.codex` and `.claude` instead of the override variables.

## Choosing targets

Target `claude` only when a skill does not depend on Codex-only tools, logs, plugins, or thread IDs. Keep descriptions free of agent product names so both agents trigger on the same requests. Currently `codex-thread-links`, `daily-neruwa` (Codex session logs), and `create-sugawara-research-slides` (Codex presentations plugin) target Codex only.

Codex also discovers `~/.agents/skills`, and plugin skills share its name space, so checks for duplicate names and plugin collisions apply to Codex.

- OpenAI skill discovery: <https://developers.openai.com/codex/build-skills>
- Claude Code skills: <https://code.claude.com/docs/en/skills>

The GitHub repository is public and has no repository-wide license. Owned skills are therefore recorded as `UNLICENSED`; review personal paths and bundled assets before pushing. Vendored content must carry its upstream license and immutable provenance metadata.

## Commands

Preview or deploy the links for every agent present on this machine. `--agents codex,claude` names them explicitly and creates missing directories:

```zsh
./scripts/deploy-skills.zsh --dry-run
./scripts/deploy-skills.zsh --non-interactive
```

`./deploy.sh` runs the same deployment after the shell configuration and also links the global instructions; `./deploy.sh --no-shell` skips the shell configuration.

Conflicting real directories, links elsewhere, and broken links outside this checkout are preserved. Interactive replacement moves the displaced item under the agent's `skill-backups/<timestamp>/`; non-interactive deployment reports the conflict and fails. Broken links that point into this checkout were left by an earlier layout or a renamed skill: deployment relinks them, or removes them when the skill no longer exists.

Validate the registry, inventory, sources, links for the agents present, collisions, provenance, forbidden generated files, nested Git repositories, likely secrets, large files, and the Obsidian project link:

```zsh
./scripts/check-skills.zsh
```

Finalize one owned or vendored skill after deployment:

```zsh
./scripts/finalize-skill.zsh <skill-name>
```

The finalize command runs the skill's tests when a supported test layout exists, rejects unrelated staged changes, stages only the target skill and shared management files, creates no empty commit, and never pushes.

Removing an agent from a skill's `targets` skips it on future runs; `check-skills.zsh` warns about the leftover link, which you remove after checking it.

## Updating external and plugin skills

For a vendored update, fetch an immutable upstream revision, verify the license, compare the recorded upstream subdirectory, replace only that snapshot, and update both `UPSTREAM.json` and the registry before finalizing. Never bring an upstream `.git`, virtual environment, cache, log, or generated test output into the repository.

Codex plugin skills stay attached to their plugin. Reinstall them through the ChatGPT or Codex desktop Plugins tab, or open `/plugins` in Codex CLI, using the plugin identifier and dependency notes in the inventory. Do not copy `~/.codex/plugins/cache`; versions, apps, MCP servers, and permissions must be restored through the plugin installation flow.

No hook automatically commits skills. The `manage-skills` skill, the check command, and the finalize command provide the intended workflow.
