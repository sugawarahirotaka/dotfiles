# Local tool availability

- Obsidian CLI is installed at `/Users/sugawara/.local/bin/obsidian` and requires the Obsidian app to be running.
- Obsidian CLI connects through `/Users/sugawara/.obsidian-cli.sock`. If an `obsidian` command reports that it cannot find Obsidian from inside the sandbox, rerun the same command with `sandbox_permissions: "require_escalated"`; do not conclude that the CLI is missing.

# Codex Skills

Codex Skillを作成、更新、導入、移動、削除またはGit管理するときは、必ず `manage-codex-skills` Skillを使用する。
