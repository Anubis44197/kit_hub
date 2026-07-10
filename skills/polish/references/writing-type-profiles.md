# Writing Type Profiles

This reference defines the supported production profiles. Every run must choose one primary `writing_type` and may add secondary labels only when they do not conflict with the primary form.

## Fiction
- `novel`: long-form plot, sustained character arc, chapter causality, complete ending.
- `story`: compact arc, limited cast, high scene economy, single dominant turn.
- `novella`: middle-length structure, one central arc, controlled subplot count.
- `children_book`: age-appropriate vocabulary, clear moral/emotional arc, no unsuitable content.
- `young_adult`: strong voice, identity pressure, readable pacing, age-safe conflict handling.
- `fantasy`: world rules ledger, magic/technology consistency, map/location continuity.
- `science_fiction`: speculative premise logic, technology constraints, cause-effect rigor.
- `mystery_thriller`: clue ledger, suspect logic, fair-play reveal, escalation ladder.
- `romance`: relationship beat map, consent clarity, emotional progression, satisfying resolution.
- `historical_fiction`: period consistency, research notes, anachronism audit.

## Nonfiction
- `essay`: thesis, argument ladder, counterargument, conclusion.
- `memoir`: lived-experience arc, scene truth, ethical handling of real people.
- `biography`: chronology, source ledger, factual caution, non-invented private facts.
- `research_book`: claim-source matrix, citation plan, glossary, chapter argument map.
- `self_help`: promise boundary, exercises, examples, safety disclaimers where needed.
- `business_book`: framework, case examples, operational clarity, evidence discipline.
- `academic`: formal structure, citation style, definitions, methodology boundaries.
- `poetry_collection`: poem sequence logic, voice consistency, section ordering, no forced prose chapter rules.
- `screenplay`: scene headings, action lines, dialogue blocks, character cues, production-readable format.

## Mandatory Profile Fields
Each active profile must define:
- `writing_type`
- `genre`
- `target_reader`
- `structure_model`
- `voice_model`
- `evidence_policy`
- `continuity_policy`
- `completion_criteria`

## Canonical Type Rules
- Do not use `user_defined`, `other`, `book`, or a free-text Turkish label as `writing_type`.
- Use one canonical value: `novel`, `story`, `novella`, `children_book`, `young_adult`, `essay`, `memoir`, `biography`, `research_book`, `self_help`, `business_book`, `academic`, `poetry_collection`, or `screenplay`.
- Put mystery, thriller, historical, fantasy, science fiction, romance, literary, and similar labels in `genre`.
- `book-plan.json.writing_type` and `writing-type-profile.json.writing_type` must match exactly.

## Type-Specific Ledger Rules
- Fiction profiles require character, plot, world, relationship, knowledge, timeline, theme, continuity, promise/payoff, and chapter-summary ledgers.
- Nonfiction profiles require claim, source, term glossary, argument, continuity, and chapter-summary ledgers.
- Poetry collections require poem-order, motif, voice, section, and language-rhythm checks.
- Screenplays require scene, character cue, dialogue, action, continuity, and format checks.
- Hybrid projects must satisfy both fiction and nonfiction ledger groups.

## Completion Rule
No export is ready unless the selected profile has a matching structure template and quality scorecard.
