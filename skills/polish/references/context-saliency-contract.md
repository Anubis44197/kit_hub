# Context Saliency Contract

This contract prevents provider, IDE, or local agents from leaving the approved book context while writing or revising longform work.

## Required State Files
- `revision/_state/story-bible.json`
- `revision/_state/chapter-continuity-chain.json`
- `revision/_state/context-saliency-map.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/character-state.json`
- `revision/_state/world-state.json`
- `revision/_state/knowledge-graph.json`
- `revision/_state/promise-payoff-ledger.json`

## Story Bible Shape
`story-bible.json` must include:
- `premise`
- `genre`
- `style`
- `synopsis`
- `characters`
- `worldbuilding`
- `outline`
- `visibility_rules`

The Story Bible is the source of truth. It is not reader-facing text and must not be exported into the manuscript DOCX.

## Chapter Continuity Shape
`chapter-continuity-chain.json` must include:
- `chapters`
- each chapter entry with `id`, `continues_from`, `outline_link`, `required_prior_context`, `handoff_to_next`

Every generated chapter must be linked to the prior chapter unless the approved structure explicitly declares a nonlinear exception.

## Saliency Map Shape
`context-saliency-map.json` must include:
- `chapters`
- each chapter entry with `id`, `visible_characters`, `visible_worldbuilding`, `visible_plot_threads`, `visible_promises`, `blocked_context`, and `selection_reason`

The writing agent may only use visible context plus the current chapter plan and approved user instruction. Future-only reveals, hidden character facts, raw full-world dumps, stale test content, and unrelated project artifacts are forbidden.

## Agent Boundary
`context-saliency-gate` does not write manuscript text. It writes control artifacts and blocks unsafe context before `episode-creator`, `developmental-editor`, or `episode-rewriter` proceeds.

## Failure Rules
- Missing Story Bible: `BLOCKED`
- Missing chapter continuity chain: `BLOCKED`
- Missing saliency map for the requested chapter: `BLOCKED`
- Full raw Story Bible passed to writer without saliency selection: `BLOCKED`
- Future reveal visible too early: `BLOCKED`
- Character uses knowledge not present in `knowledge-graph.json`: `BLOCKED`
- Chapter repeats the previous chapter without a new event, new information, or irreversible change: `BLOCKED`
