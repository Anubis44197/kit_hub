# Editorial Quality Scorecard

This scorecard is the minimum professional gate before export.

## Scored Axes
- Structure: chapter purpose, act balance, opening and ending force.
- Character: stable motivation, voice identity, behavior consistency.
- Plot or argument: cause-effect chain, unresolved thread control, promise delivery.
- Style: sentence rhythm, diction, tone, genre fit.
- Scene craft: sensory grounding, conflict, turn, scene consequence.
- Language: Turkish correctness, punctuation, dialogue style, mojibake absence.
- Continuity: timeline, objects, locations, knowledge boundaries.
- Market/book readiness: title/front matter/cover brief/export manifest completeness.
- Evidence discipline: required for nonfiction, biography, history, research, business, self-help.

## Thresholds
- Export block: any critical issue.
- Rewrite required: total score below 85/100.
- Developmental edit required: structure, plot/argument, or character axis below 80.
- Copy edit required: language axis below 90.
- Proofread required: formatting, punctuation, or front matter issue remains.

## Required Output Shape
Each editor report must include:
- `run_id`
- `step_id`
- `writing_type`
- `score_total`
- axis scores
- blocking issues
- recommended next action: `PASS`, `REWRITE`, or `BLOCKED`
