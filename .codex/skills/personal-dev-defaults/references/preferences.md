# Preferences

These preferences apply only to development tasks.

## Python workflow

- Prefer repo-native workflow over personal defaults when the project already has a clear standard such as Poetry, pip, mise, asdf, a Makefile, or a devcontainer.
- If no stronger project convention is present, use `uv` for environment creation, dependency installation, and command execution.

## Git workflow

- Do not use Git state or a request for Git operations as a trigger for this skill. Decide from the software-development work itself.
- During implementation, first check whether the project is already inside a Git worktree. If it is not, initialize Git in the project directory unless the user says not to, the directory is temporary or disposable, or doing so would capture a broader directory than the project in scope.
- Unless the user says not to commit, make small commits regularly so each commit captures one meaningful step.
- Use these commit prefixes: `add:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`.

## Generated files

- Do not commit build outputs, generated files, lockstep artifacts, or other machine-produced results by default.
- If such files appear necessary to commit, ask for explicit confirmation first.

## Scope

- Apply these rules to coding, debugging, refactoring, testing, and environment setup.
- Do not apply them when the only requested target files or deliverables are `.tex` and/or `.md`.
- Do not apply them to non-development tasks such as research or writing questions, note-taking, or Obsidian organization.
