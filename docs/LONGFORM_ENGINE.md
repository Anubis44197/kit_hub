# Longform Engine

This repository must not generate a 300-500 page novel in one model call.

Long books are produced as a controlled sequence of chapters with persistent state files. The state files are the project memory and must be read before every chapter generation, polish, rewrite, and export step.

## Required State Files

All longform runs must keep these files under `revision/_state/`:

- `book-plan.json`: user prompt, selected direction, working title, writing type, genre, theme, premise, point of view, tense, characters, plot arc, and approval requirement.
- `open-source-story-model.json`: Manuskript, novelWriter, bibisco, and STORM-inspired outline, character, plot, world, cross-reference, research, and export model for the current book.
- `chapter-plan.json`: one reader-facing plan entry per chapter, including title, purpose, events, character focus, continuity promises, and target words.
- `layout-plan.json`: trim size, font, line spacing, indentation, words-per-page estimate, page target, word target, chapter target, and chapter start policy.
- `longform-plan.json`: target pages, target words, target chapters, act map, chapter purposes.
- `character-state.json`: stable traits, current knowledge, secrets, relationships, and arc position.
- `plot-ledger.json`: main dramatic question, open/closed threads, cause-effect chain, final promises.
- `chapter-summaries.json`: compact chapter-by-chapter memory for context recovery.
- `continuity-ledger.json`: timeline, locations, object state, and continuity violations.
- `world-state.json`: locations, time rules, objects, institutions, and world constraints.
- `relationship-graph.json`: character relationship nodes, edges, and change log.
- `knowledge-graph.json`: who knows what, when they learned it, and what remains secret.
- `promise-payoff-ledger.json`: planted clues/questions, expected payoff, paid promises, and abandoned promises.
- `timeline.json`: chronological order and chapter time map.
- `theme-ledger.json`: primary theme, motifs, and theme progression.
- `volume-plan.json`: scale tier, page/word/chapter targets, act map, batch size, and macro audit schedule.
- `style-profile.json`: narration, tense, dialogue style, rhythm, print layout, and forbidden style failures.

## Generation Policy

- Writing cannot start immediately after a simple prompt. `design-big` first produces the book, chapter, and layout plans, then `design-small` is blocked until `runtime/approvals/book-plan-approval.json` is approved by the user.
- Generate in small batches, preferably 1-3 chapters at a time.
- Batch size is scale-aware: short work may allow 3 chapters per batch; long 300-500+ page novels should usually write 1 chapter per batch.
- Before each chapter, load the longform state files, `open-source-story-model.json`, and the current chapter plan.
- After each chapter, update character state, plot ledger, chapter summary, continuity ledger, world state, relationship graph, knowledge graph, promise/payoff ledger, timeline, and theme ledger.
- Each `chapter-summaries.json` entry must include `previous_chapter_result`, `new_event`, `new_information`, `irreversible_change`, `next_causal_link`, and `state_updates`.
- Never let a character use information that is absent from `character-state.json`.
- Never let a character use information that is absent from `knowledge-graph.json`.
- Never close a plot thread unless `plot-ledger.json` records the closure.
- Never introduce a clue, question, prophecy, secret, or motif without an entry in `promise-payoff-ledger.json`.
- Never change narration, tense, or dialogue style unless `style-profile.json` is deliberately updated.

## Scale-Aware Planning

The user may ask for 10 pages, 270 pages, 390 pages, 500 pages, or another length. The system must not use a fixed chapter model.

- `short_form`: up to 20 pages, compact state, 1 act, audit every 3 chapters.
- `novella_or_short_book`: 21-120 pages, 3 acts, audit every 5 chapters.
- `standard_novel`: 121-300 pages, 4 acts, audit every 8 chapters.
- `epic_longform`: 301+ pages, 5 acts, usually 1 chapter per batch, audit every 10 chapters.

`volume-plan.json` is the source of truth for scale tier, target pages, target words, target chapters, batch size, and macro continuity audit schedule.

## Length Fulfillment Gate

The runner must verify the manuscript against the approved plan, not against what the LLM claims it finished.

For `create`, `polish`, and `rewrite`, every existing chapter must meet its planned chapter word budget closely enough to count as a completed chapter. If a chapter is short, the correct action is to continue that chapter, not to mark it complete.

For `export`, the manuscript must satisfy all of these conditions:

- all planned chapter ids from `chapter-plan.json` exist under `episode/`
- written chapter count is at least `target_chapters`
- total manuscript words meet the configured completion ratio for `target_words`
- estimated pages from `volume-plan.json.words_per_page_estimate` meet the configured completion ratio for `target_pages`

This prevents a 50, 100, 245, or 500 page request from being silently compressed into a short three-part story because of a single model response limit.

## Long Book Targets

Recommended ranges:

- 300 pages: 110,000-130,000 words, 40-50 chapters.
- 400 pages: 140,000-170,000 words, 55-70 chapters.
- 500 pages: 175,000-210,000 words, 70-90 chapters.

Actual printed page count depends on trim size, font, margins, line spacing, and publisher layout.

## Validation Gates

The runner validates the existence and basic schema of all longform state files for:

- `design-big`
- `design-small`
- `create`
- `polish`
- `rewrite`
- `export`

`create`, `polish`, `rewrite`, and `export` also require at least one chapter summary.

When generated chapters reach a marker listed in `volume-plan.json.audit_schedule`, the run must include both:

- `revision/_workspace/macro-continuity-audit_EPxxx.json`
- `revision/_workspace/macro-continuity-audit_EPxxx.md`

The audit JSON must declare `verdict=PASS`, `through_chapter`, all checked ledgers, open risks, and required fixes. Missing or failing audit artifacts block create/polish/rewrite/export.

## Continuity And Repetition Gates

For `create`, `polish`, and `rewrite`, the runner also blocks outputs that look like disconnected agents or repeated chapter templates:

- Cross-chapter similarity is checked with token-set overlap.
- Repeated chapter-opening patterns are rejected.
- Duplicate chapter summaries in `revision/_state/chapter-summaries.json` are rejected.
- Every chapter summary must record `previous_chapter_result`, a unique `new_event`, `new_information`, a unique `irreversible_change`, `next_causal_link`, and `state_updates`.
- Consecutive chapters must connect: chapter N's `next_causal_link` must match chapter N+1's `previous_chapter_result`.
- `plot-ledger.json` must keep a non-repeating cause-effect chain for all generated chapters.
- `knowledge-graph.json` must prevent characters from acting on unknown information.
- `promise-payoff-ledger.json` must prevent forgotten clues and unresolved planted promises.
- `timeline.json` must prevent time-order contradictions.
- `relationship-graph.json` must prevent sudden relationship changes without a causing chapter.
- Repeated paragraph openings inside the same episode are rejected.
- Duplicate-line ratio is checked so repeated dialogue or transition text cannot pass as a finished chapter.

These gates are not a replacement for literary editing. They are hard safety rails: if an agent ignores the longform state files or keeps reusing the same scene scaffold, the run fails instead of exporting a misleading DOCX.

## Reader DOCX Cleanliness

Reader-facing DOCX exports must not contain publication review notes, `VERDICT:` lines, run IDs, step IDs, ISBN/bandrol blocker notes, test labels, or validator report text. Those items belong only in `revision/_workspace/` reports.

## Production Adapter Boundary

`scripts/local_phase.ps1` is a deterministic local adapter for validation. Production AI integration should replace the adapter command in `runtime/runner-config.json`, but it must preserve the same artifacts and state update contract.
