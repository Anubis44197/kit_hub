# Genre Structure Templates

These templates prevent long manuscripts from losing shape.

## Novel
- Act I: premise, ordinary world pressure, inciting incident, first irreversible choice.
- Act II-A: investigation or pursuit, complications, relationship pressure, midpoint reversal.
- Act II-B: consequences, false victory or false defeat, moral cost, deepest complication.
- Act III: final plan, confrontation, revelation, character choice, aftermath.

## Story
- Opening pressure.
- One meaningful complication.
- One irreversible turn.
- Consequence or resonance.

## Essay
- Thesis.
- Definitions.
- Argument sequence.
- Counterargument.
- Synthesis.
- Closing claim.

## Research / Academic
- Research question.
- Scope and definitions.
- Method or source basis.
- Evidence chapters.
- Discussion.
- Limitations.
- Conclusion and bibliography plan.

## Memoir / Biography
- Timeline spine.
- Turning points.
- Scene selection.
- Ethical/factual notes.
- Reflection layer.
- Closing meaning.

## Mandatory Ledgers
- Fiction: character state, plot ledger, continuity ledger, style profile, chapter summaries.
- Nonfiction: claim ledger, source ledger, term glossary, chapter argument summaries.
- Hybrid works: both ledger groups apply.

## Longform Memory Rules
- Any book plan must declare `memory_strategy`, `chapter_state_update_contract`, and `reader_progression_policy`.
- Every generated chapter must add a unique `new_event`, `new_information`, `irreversible_change`, and `next_causal_link` to `chapter-summaries.json`.
- Long manuscripts must use an audit schedule; the writer cannot generate unlimited chapters in one pass.
- For large works, state ledgers are the source of truth, not the previous prose alone.

## Supported Structure Families
- `single_turn_story_arc`: short story or compact fiction.
- `controlled_subplot_novella`: novella or short novel with limited subplots.
- `four_act_longform_novel`: sustained novel with opening, complication, consequence, and resolution.
- `clue_escalation_reveal_novel`: mystery, thriller, agent, or detective fiction with clue/payoff control.
- `period_consistency_historical_arc`: historical fiction with period and anachronism control.
- `thesis_counterargument_synthesis`: essay.
- `chronological_life_arc`: biography.
- `memoir_reflection_arc`: memoir.
- `claim_source_argument_book`: research or argument-led nonfiction.
