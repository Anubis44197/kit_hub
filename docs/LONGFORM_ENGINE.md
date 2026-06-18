# Longform Engine

This repository must not generate a 300-500 page novel in one model call.

Long books are produced as a controlled sequence of chapters with persistent state files. The state files are the project memory and must be read before every chapter generation, polish, rewrite, and export step.

## Required State Files

All longform runs must keep these files under `revision/_state/`:

- `longform-plan.json`: target pages, target words, target chapters, act map, chapter purposes.
- `character-state.json`: stable traits, current knowledge, secrets, relationships, and arc position.
- `plot-ledger.json`: main dramatic question, open/closed threads, cause-effect chain, final promises.
- `chapter-summaries.json`: compact chapter-by-chapter memory for context recovery.
- `continuity-ledger.json`: timeline, locations, object state, and continuity violations.
- `style-profile.json`: narration, tense, dialogue style, rhythm, print layout, and forbidden style failures.

## Generation Policy

- Generate in small batches, preferably 1-3 chapters at a time.
- Before each chapter, load the longform state files and the current chapter plan.
- After each chapter, update character state, plot ledger, chapter summary, and continuity ledger.
- Never let a character use information that is absent from `character-state.json`.
- Never close a plot thread unless `plot-ledger.json` records the closure.
- Never change narration, tense, or dialogue style unless `style-profile.json` is deliberately updated.

## Long Book Targets

Recommended ranges:

- 300 pages: 110,000-130,000 words, 40-50 chapters.
- 400 pages: 140,000-170,000 words, 55-70 chapters.
- 500 pages: 175,000-210,000 words, 70-90 chapters.

Actual printed page count depends on trim size, font, margins, line spacing, and publisher layout.

## Validation Gates

The runner validates the existence and basic schema of all longform state files for:

- `design-big`
- `create`
- `polish`
- `rewrite`
- `export`

`create`, `polish`, `rewrite`, and `export` also require at least one chapter summary.

## Continuity And Repetition Gates

For `create`, `polish`, and `rewrite`, the runner also blocks outputs that look like disconnected agents or repeated chapter templates:

- Cross-chapter similarity is checked with token-set overlap.
- Repeated chapter-opening patterns are rejected.
- Duplicate chapter summaries in `revision/_state/chapter-summaries.json` are rejected.
- Every chapter summary must record `new_information` and a unique `irreversible_change`.
- `plot-ledger.json` must keep a non-repeating cause-effect chain for all generated chapters.
- Repeated paragraph openings inside the same episode are rejected.
- Duplicate-line ratio is checked so repeated dialogue or transition text cannot pass as a finished chapter.

These gates are not a replacement for literary editing. They are hard safety rails: if an agent ignores the longform state files or keeps reusing the same scene scaffold, the run fails instead of exporting a misleading DOCX.

## Production Adapter Boundary

`scripts/local_phase.ps1` is a deterministic local adapter for validation. Production AI integration should replace the adapter command in `runtime/runner-config.json`, but it must preserve the same artifacts and state update contract.
