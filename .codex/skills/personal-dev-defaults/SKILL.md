---
name: personal-dev-defaults
description: Apply Sugawara's preferences when Codex is asked to implement or modify software or tests, run software-development tooling, or configure dependencies, runtimes, containers, builds, or development environments. Trigger from the requested development work, regardless of whether Git is already initialized; Git presence or Git operations are not trigger criteria. Do not trigger merely because the task occurs in a repository, and do not trigger when the only requested target files or deliverables are `.tex` and/or `.md`. Also exclude read-only searching, review, diagnosis, or explanation; research and writing questions; note-taking and Obsidian work; and document, slide, spreadsheet, or PDF tasks unless the user explicitly asks to use this skill.
---

# Personal Dev Defaults

Apply this skill only when the user's requested outcome includes at least one of these actions:

- create or change software or tests;
- run tests, builds, linters, formatters, package managers, or other project tooling;
- configure dependencies, runtimes, containers, or development environments;

Do not use Git state or Git operations to decide whether to apply this skill. The presence or absence of a Git repository, source files, a working directory, or an `AGENTS.md` file is not sufficient by itself. Apply the Git defaults below only after the task independently qualifies as software development.

Skip this skill when the only requested target files or deliverables are `.tex` and/or `.md`, even if those files are inside a source repository.

Skip this skill for read-only explanation, review, investigation, or content work when no concrete development operation is requested. Examples include:

- answering a question about a paper stored as TeX;
- checking notation, wording, equations, citations, or research content;
- reading or searching repository files only to answer a question;
- reviewing or explaining code without running project tooling or implementing a change;
- creating or editing notes, prose, Markdown, TeX, documents, slides, spreadsheets, PDFs, or Obsidian content.

If a task mixes content work with genuine software development, apply these defaults only to the development portion.

## Defaults

- Follow clear repo-local conventions first. If the repository already centers Poetry, pip, mise, asdf, a Makefile, a devcontainer, or similar workflow, use that instead of forcing `uv`.
- Otherwise, use `uv` as the default for Python environment setup, dependency management, and command execution.
- If a task needs a GUI you are implementing, prefer a browser-based local UI over desktop GUI toolkits such as Tk, unless the repo already has a different established GUI stack.
- For implementation work, use Git even when the project has not been initialized yet. First check whether the project is already inside a Git worktree. If it is not, initialize Git in the project directory unless the user says not to, the directory is temporary or disposable, or doing so would capture a broader directory than the project in scope.
- Unless the user says not to commit, create small, meaningful intermediate commits regularly as progress checkpoints.
- Use commit messages in the form `add: ...`, `fix: ...`, `refactor: ...`, `docs: ...`, `test: ...`, or `chore: ...`.
- Do not commit generated artifacts, build outputs, or other auto-generated files unless the user explicitly asks for that or confirms they are required.

## Reference

Read [references/preferences.md](references/preferences.md) when you need the fuller preference details or expect to make commits.
