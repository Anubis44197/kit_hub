---
name: design-big
description: "Produce approved full-book architecture: book plan, chapter plan, layout plan, state ledgers, and config scaffold."
prompt_version: "1.1.0"
---

# Design Big Skill

## Purpose
Create top-level architecture documents for a book project before any chapter writing starts.

This phase never writes manuscript chapters. It turns the user's actual request into a reviewable plan. The user must approve that plan through `runtime/approvals/book-plan-approval.json` before `design-small`, `create`, `polish`, `rewrite`, or `export` may proceed.

## Flow
1. Parse the actual user request from `runtime/book-request.md`.
2. Run domain research only when source artifacts will be recorded; otherwise do not claim research.
3. Orchestrate design agents:
   - concept-builder
   - character-architect
   - plot-hook-engineer
   - book-structure-optimizer
4. Run consistency merge pass.
5. Publish reader-facing plan files, machine-readable state files, and `novel-config.md`.
6. Stop for user review. Do not start chapter-range planning or manuscript writing.

## Hard Rules
- Do not use placeholder language such as `plan_required`, `to_be_confirmed`, `TBD`, `TODO`, or "fill in later".
- Every character entry must include concrete role, name, desire, fear, and arc.
- If the user specifies a character count, the plan must preserve that count or explicitly ask the user to reduce it before writing starts.
- Every plot arc must include concrete opening promise, inciting incident, midpoint turn, climax, and resolution.
- Every chapter plan entry must include reader-facing title, purpose, events, character focus, continuity promises, and target words.
- Layout targets must align with target pages, target words, target chapters, trim size, font, and words-per-page estimate.
- Technical ids such as `EP001` may exist in state file ids, but reader-facing titles must not be technical labels.

## Outputs
- `design/*_bootstrap.md`
- `design/*_character.md`
- `design/*_plot-hook.md`
- `design/04_book_plan.md`
- `design/05_chapter_plan.md`
- `design/06_layout_plan.md`
- `novel-config.md`
- `revision/_state/book-plan.json`
- `revision/_state/open-source-story-model.json`
- `revision/_state/story-bible.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/layout-plan.json`
- `revision/_state/longform-plan.json`
- `revision/_state/character-state.json`
- `revision/_state/plot-ledger.json`
- `revision/_state/chapter-summaries.json`
- `revision/_state/continuity-ledger.json`
- `revision/_state/chapter-continuity-chain.json`
- `revision/_state/context-saliency-map.json`
- `revision/_state/style-profile.json`
- `revision/_state/writing-type-profile.json`
- `revision/_state/genre-structure-template.json`
- `revision/_state/editorial-quality-scorecard.json`
- `revision/_state/llm-adapter-contract.json`
- `revision/_state/claim-ledger.json`
- `revision/_state/source-ledger.json`
- `revision/_state/term-glossary.json`
- `revision/_state/argument-ledger.json`

## Open Source Story Model Contract
- Load `skills/polish/references/open-source-novel-editor-patterns.md` before planning.
- Produce `revision/_state/open-source-story-model.json` in every design-big run.
- Bind `book-plan.json.open_source_story_model` to `revision/_state/open-source-story-model.json`.
- The generated model must include Manuskript-style character/plot/world/outline fields, novelWriter-style synopsis/tag/cross-reference rules, bibisco-style premise/fabula/narrative-strand/setting rules, and STORM-style pre-writing question/source rules.
- Later writing phases must treat this file as governing state, not optional commentary.

## Story Bible and Saliency Contract
- Produce `revision/_state/story-bible.json` in every design-big run.
- The Story Bible must include premise, genre, style, synopsis, characters, worldbuilding, outline, and visibility rules.
- Produce initial `revision/_state/chapter-continuity-chain.json` and `revision/_state/context-saliency-map.json`.
- The saliency map must state that writing agents may not receive the full raw Story Bible without chapter-specific context selection.
- Later create, polish, and rewrite phases must use the saliency map to keep the LLM inside the approved book context.
