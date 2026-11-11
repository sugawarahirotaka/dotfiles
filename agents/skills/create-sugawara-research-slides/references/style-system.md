# Sugawara research-slide style system

This system was distilled from five representative Keynote decks spanning 2024–2026: B4 progress, M1 progress, M1 short pitch, M2 progress, and journal club. The visual audit covered 186 visible slides. Later decks take precedence when details conflict.

## Core invariant

Each slide combines three layers:

1. a compact blue header that establishes section, topic, and position;
2. dense but organized technical evidence in the white body;
3. one explicit interpretation, usually near the bottom and often partly red.

The deck is figure-first and explanation-rich, not minimalist. Density is acceptable when every element supports the same message.

## Canvas and geometry

- Default aspect ratio: 4:3, `1024 × 768` in artifact-tool coordinates.
- Background: white.
- Header: full-width `#0076BA`, about 56 px high.
- Header slots: section label left, one-line slide title centered, page marker right.
- Body begins around 78–96 px; keep 34–56 px side margins.
- Reserve the final 90–120 px for the interpretation and 14–16 px source rail when needed.
- Use square corners, flat fills, thin rules, and aligned rectangular frames. Avoid shadows and decorative rounding.

## Typography

- Japanese: Hiragino Sans W3 for regular text and W6 for emphasis.
- Latin labels: Helvetica/Lucida Grande-compatible sans.
- Mathematics: STIX or Times-compatible math face.
- Title slide: 42–50 px bold, usually two lines maximum.
- Header title: 28–32 px bold and one line.
- Section label: 16–20 px regular; page marker: 20–22 px.
- Body: 20–26 px; dense technical labels: 18–20 px.
- Footnotes and sources: 14–16 px.
- Do not use body text below 18 px except sources, axis labels, or unavoidable figure-internal labels.

## Palette and meaning

| Token | Hex | Meaning |
| --- | --- | --- |
| Primary blue | `#0076BA` | Header, proposed method, structural frame |
| Deep blue | `#005781` | Optional secondary blue emphasis |
| Red | `#EE220C` | Problem, failure, decisive difference, final conclusion |
| Orange | `#FF9300` | Alternative, key variable, expectation, warning |
| Green | `#158620` | Baseline series, positive observation, supported claim |
| Teal | `#00A89D` | Process step, model component, next action |
| Pink | `#EF5FA7` | Secondary mathematical term or linked annotation |
| Pale blue | `#D2EBFF` | Proposed-method or mechanism background |
| Pale yellow | `#FDF8BA` | Assumption, hypothesis, or attention background |
| Neutral gray | `#666666` | Baseline labels and secondary structure |

Use no more than two semantic accents beyond blue on a normal slide. Keep the same concept the same color across the deck.

## Copy and hierarchy

- Prefer a topic title in the blue bar and a conclusion sentence near the bottom, matching the source decks.
- Start explanations with compact lead-ins such as `課題`, `目的`, `手法`, `結果`, `仮説`, or `Question`.
- Bold the lead-in and color only the decisive phrase.
- Use bullets for parallel evidence, not for the main story.
- Replace inventories of facts with evidence → interpretation.
- Repeat the agenda at section boundaries; highlight only the active section in red.

## Figures, charts, and equations

- Make one main chart large enough to read; use 2-up or 2×2 only for direct comparison.
- Keep axes, scales, legend semantics, colors, and panel dimensions consistent across small multiples.
- Put sample size, conditions, metric definition, and sources in the plot area or footer.
- Annotate plots with circles, arrows, short labels, or colored frames only when they identify the evidence for the slide message.
- Show equations as a sequence. Link corresponding terms with the same orange, pink, blue, or red cue and end with the scientific meaning.
- Do not use stock imagery or ornamental icons unless the research content genuinely requires them.
