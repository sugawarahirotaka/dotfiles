---
name: codex-thread-links
description: Record durable references from saved Codex logs, session notes, memory notes, handoff notes, or Obsidian Markdown records back to the original Codex chat. Use when the user asks to save, update, recall, import, list, or link Codex conversation logs, asks for "Codexログ", "チャットに飛ぶ", "threadId", "deeplink", or wants saved notes to reopen the corresponding Codex.app thread.
---

# Codex Thread Links

## Overview

When saving or updating a Codex conversation record, include a stable thread reference so the note can later be mapped back to the original Codex chat. Prefer factual `threadId` metadata over guessed URLs.

## Workflow

1. Identify the Codex thread being saved or referenced.
2. Record `codexThreadId` when the current tool context exposes it or the user provides it.
3. Record `codexThreadUrl` only when a working Codex.app deep link or official URL is known. Do not invent URL schemes.
4. Add a human-readable "Codex Chat" link or context line in the body when useful for the target note format.
5. If the thread id is unavailable, write `codexThreadId: ""` or omit it according to the local schema, and note that the original chat link was unavailable.

## Markdown Schema

Use these frontmatter fields when the note schema allows custom metadata:

```yaml
codexThreadId: ""
codexThreadUrl: ""
codexThreadHost: ""
```

Field rules:

- `codexThreadId`: Exact Codex thread id. Never fabricate this value.
- `codexThreadUrl`: Clickable link that has been verified or explicitly supplied. Leave empty if unknown.
- `codexThreadHost`: Optional host label such as `local`, `v108`, or another connected Codex host when relevant.

For body content, prefer a compact line:

```markdown
- Codex Chat: [open original thread](...)
```

If no clickable URL is known, use:

```markdown
- Codex thread id: `...`
```

## Using Codex Tools

When a Codex app thread tool is available, use the stored `codexThreadId` to inspect, continue, or navigate to the thread. Do not require an external URL when the app tool can open the thread directly.

If the user wants click-through links from Obsidian or another editor, verify the local Codex.app deep link behavior before writing a URL as a durable link. If verification is not possible, store the id and state that the deep link is unverified.

## Coordination With Local Schemas

When another skill or repository rule defines a session-note schema, extend that schema minimally with the fields above instead of replacing it. Preserve existing date, host, project, branch, status, and resume-prompt conventions.
