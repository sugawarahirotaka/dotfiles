---
name: create-sugawara-research-slides
description: "Create or edit Japanese scientific research presentations as editable 4:3 PPTX files in Sugawara's established Keynote-derived style: blue title bands, figure-first technical density, restrained semantic color, and one slide–one message. Use for 菅原流 or Sugawara-style progress reports, thesis defenses, journal-club decks, short pitches, or any request to match the research Keynote corpus under /Users/sugawara/Research."
---

# Create Sugawara Research Slides

Produce coherent research decks that look and read like Sugawara's 2024–2026 Keynote work while remaining editable in PowerPoint.

## Required resources

1. Read [references/style-system.md](references/style-system.md) before planning copy or visuals.
2. Read [references/layout-patterns.md](references/layout-patterns.md) before mapping content to slides.
3. Use [assets/sugawara-research-template.pptx](assets/sugawara-research-template.pptx) as the default visual source. Copy it into the temporary workspace; never modify the bundled asset in place.
4. Use the Presentations skill and its template-following workflow. Implement with `@oai/artifact-tool`; do not use `python-pptx`.

## Workflow

### 1. Fix the communication job

Infer the audience, presentation length, decision or understanding required, central claim, supplied evidence, and source constraints. Default to Japanese and 4:3 unless the user explicitly requests another language or aspect ratio.

### 2. Build the narrative before laying out slides

For every intended slide, define:

- one message expressible as a 15–45 Japanese-character sentence;
- the evidence needed to support that message;
- one layout pattern from the template;
- the audience-facing conclusion or transition.

Use a cumulative arc appropriate to the task, commonly background → problem → method → result → interpretation → next step. Reuse the agenda slide at major section boundaries and mark only the current section.

Apply the one-message gate: if the sentence 「このスライドで言いたいことは＿＿＿」 cannot be completed unambiguously, split or delete the slide. Every chart, equation, annotation, and bullet must support that sentence.

### 3. Map slides to the template

Inspect every template slide, then create a frame map from each output slide to one template slide. Duplicate mapped slides and edit existing objects in place using inspected stable IDs and names. Preserve the blue header, section label, page marker, typography, margins, and footer rail.

- If the user provides an existing Sugawara-style PPTX, treat it as the primary template and preserve its master → layout → slide hierarchy.
- If no template pattern fits, build one new slide with the exact tokens in `style-system.md`; do not force content into an unsuitable frame.
- Do not use Codex Grid, generic corporate templates, rounded dashboard cards, shadows, decorative gradients, or widescreen stretching.

### 4. Author at Sugawara density

Prefer technical evidence over decorative imagery. A normal content slide should usually contain one of these:

- one main figure plus 2–4 concise interpretation points;
- two directly comparable figures plus one conclusion;
- four small multiples with identical axes and one cross-panel conclusion;
- one algorithm or causal flow plus the minimum equations or labels needed;
- one equation chain with color-linked annotations and a final meaning statement.

Keep body text mostly at 20–26 px, dense technical annotations at 18–20 px, and sources at 14–16 px. Shorten or split content before shrinking further. Keep the title bar title on one line. Use direct Japanese, concrete nouns, active verbs, and short labels.

Place the main interpretation near the bottom, separated by a thin rule when useful. Use red only for the decisive problem, difference, failure, or conclusion; use the other accents according to `style-system.md`. Avoid coloring entire paragraphs.

### 5. Handle visuals and evidence

Use native editable charts, tables, text, and simple connectors where practical. Preserve supplied plots and scientific figures as raster or vector assets without redrawing them as approximate shapes. Keep axes, legends, color mappings, sample sizes, and comparison conditions explicit.

Add `[Sources]` blocks to speaker notes for every external non-trivial claim and external asset. Use notes for derivations, experimental conditions, caveats, and speaking detail that would overload the canvas.

### 6. Verify before delivery

1. Render every final slide and inspect each one at full size.
2. Run overflow detection and fix all unintended overlap, clipping, broken connectors, unexpected wrapping, and empty placeholders.
3. Confirm every slide passes the one-message gate and that the highlighted conclusion matches the evidence.
4. Confirm title bars, section labels, slide numbers, source rails, fonts, and accent semantics remain consistent.
5. Confirm charts and equations are legible, comparable panels share scales, and citations are traceable.
6. Export an editable `.pptx`. Deliver PDF only when the user also requests it.
