---
name: open-source-novel-editor-patterns
description: Contract for adapting proven open source novel editor planning patterns into KitHub state files.
prompt_version: 1.0.0
---

# Open Source Novel Editor Patterns

This reference records the planning patterns adapted into KitHub from established open source writing editors. Do not copy GUI code or vendor project storage wholesale into a book run. Use these projects as explicit state-model sources and preserve attribution in generated planning evidence.

## Upstream References

- Manuskript (`olivierkes/manuskript`, GPL-3.0-or-later): character, plot, world, outline, summary, POV, goal, compile, revision and word-count field model.
- novelWriter (`vkbo/novelWriter`, GPL-3.0): plain-text project tree with roots for novel, plot, characters and world notes; chapter/scene documents; synopsis metadata; tag/cross-reference indexing.
- bibisco (`andreafeccomandi/bibisco`, GPL-3.0): novel structure, premise, fabula, narrative strands, geographic/temporal/social settings, chapter/scene organization, revision management and deep character understanding.
- STORM (`stanford-oval/storm`, MIT): pre-writing before drafting, question-driven research/outline generation, human-in-the-loop steering and grounded discourse for research-heavy writing.

## Mandatory KitHub State Model

Every `design-big` run must produce `revision/_state/open-source-story-model.json` and every later writing phase must load it. The file must include:

- `sources`: upstream project names and the exact pattern each contributed.
- `outline_model`: chapter/scene cards with reader title, synopsis, POV, goal, status, compile flag, word target and revision state.
- `character_model`: name, role, importance, motivation, goal, conflict, epiphany, sentence summary, paragraph summary, full summary, stable traits, knowledge boundaries, arc position and POV eligibility.
- `plot_model`: main plot, subplots, plot steps, result, cause-effect chain, promise/payoff and linked characters.
- `world_model`: geographic, temporal and social setting, objects, institutions, constraints, mood, conflict and continuity rules.
- `cross_reference_model`: tag/reference rules for characters, plots, locations, objects and secrets so generated text can be checked against state instead of memory.
- `research_outline_model`: required question set, source ledger, claim ledger and outline notes for historical, biographical, research and nonfiction writing.
- `export_model`: title page, front matter, chapter starts, scene boundaries, synopsis exclusion from reader output and clean DOCX/PDF/ePub export expectations.

## Enforcement

The LLM/IDE agent must not write manuscript text from the user prompt alone. It must first load the approved brief, approved book plan, chapter plan and `open-source-story-model.json`. If a chapter introduces or changes a character, location, object, relationship, promise, clue, source or timeline fact, the matching state ledger must be updated in the same phase.

Reader-facing output must not contain planning labels such as `EP001`, `Scene 1`, synopsis metadata, tag metadata, outline notes, compliance verdicts or source-model explanations.
