# Daily Review Format

Write the aggregate review in concise Japanese. Keep individual session links in the session callouts managed by `codex-session-memory`; use this section to synthesize the day across sessions.

Pass only the content below to `upsert_daily_note.py`. The script adds the hidden `daily-neruwa` markers.

```markdown
## Codex振り返り

> [!summary]- AI-generated: 今日のCodex作業
> その日の軸を2〜4文で要約する。何を完成させ、何を判断し、どこに続きがあるかが一読で分かるようにする。

### 今日進めたこと

- 成果単位でまとめる。似たsessionは統合する。
- 必要なら対象repoやhostを添える。

### 判断・学び

- 後から思い出す価値がある決定、方向転換、失敗から得た知見だけを書く。

### 明日への引き継ぎ

- 未完了作業を、再開時にそのまま実行できる粒度で書く。
```

## Rules

- Keep `AI-generated` exactly as written because this section lives in `01_Imo/`.
- Omit empty headings instead of writing `なし`.
- Do not list command counts, token counts, or every touched file.
- Do not repeat details already clear in a linked session note.
- Keep personal reflections outside the managed block. Never rewrite or summarize the user's own prose.
