# Template layout patterns

Use `assets/sugawara-research-template.pptx` as a layout library. Inspect object names before editing and duplicate the closest pattern rather than rebuilding its chrome.

| Template slide | Pattern | Use for | Main named edit targets |
| --- | --- | --- | --- |
| 1 | Minimal title | Talk title, defense, progress report, journal club | `deck-title`, `affiliation`, `author`, `event-meta` |
| 2 | Agenda / section reset | Opening agenda and repeated section transitions | `agenda-items`, `current-section-marker`, `slide-number` |
| 3 | Problem → solution | Motivation, conventional vs proposed mechanism | `lead-claim`, `traditional-copy`, `proposed-copy`, `takeaway-message` |
| 4 | Side-by-side comparison | Baseline vs proposed method under matched conditions | two inspected chart IDs, both annotations, `takeaway-message` |
| 5 | Algorithm / mechanism | Data flow, model pipeline, experimental loop | `algorithm-lead`, `observed-data`, `regression-model`, `pseudo-data`, `bo-copy` |
| 6 | One decisive result | Main quantitative result with compact interpretation | inspected chart ID, `result-summary`, `result-tag`, `takeaway-message` |
| 7 | Small multiples | Dimensions, functions, seeds, conditions, or ablations | four inspected chart IDs, condition labels, `takeaway-message` |
| 8 | Equation chain | Derivation, mathematical mechanism, numerical stability | `derivation-question`, `equation-1` through `equation-3`, meaning tags, `takeaway-message` |
| 9 | Hypothesis → test → result | Cause analysis, ablation, diagnostic experiment | `hypothesis`, `test-plan`, two inspected chart IDs, `test-result`, `takeaway-message` |
| 10 | Synthesis → next action | Conclusion, implications, future plan | `summary-bullets`, `summary-synthesis`, `next-bullets`, `next-timeline`, `takeaway-message` |

## Selection rules

- Choose slide 6 when one figure carries the argument; choose slide 7 only when cross-panel comparison is the point.
- Choose slide 4 only when the two sides use matched metrics, axes, and experimental conditions.
- Choose slide 8 only when the derivation itself advances the talk; otherwise move the equation to notes or appendix.
- Choose slide 9 when an explicit hypothesis is tested by a targeted experiment, not for a generic result list.
- Repeat slide 2 before a new major section instead of inserting a decorative divider.
- Preserve the footer rail and replace its content with real conditions, citations, or a short methodological note.

## Adaptation

If an output slide needs a new silhouette, keep the same header and footer geometry, fonts, palette, flat rectangular treatment, and bottom interpretation. Build the new body around the evidence; do not introduce a new visual language.
