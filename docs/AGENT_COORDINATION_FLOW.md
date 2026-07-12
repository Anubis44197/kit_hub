# Agent Coordination Flow

KitHub agents are coordinated by phase contracts, not by free-form LLM memory. Each phase declares an `agent_sequence` in `runtime/phase-contracts/{phase}.json`.

## Coordination Rule

1. The runner loads the phase contract.
2. Specialist agents run in `agent_sequence` order.
3. Each specialist must produce concrete evidence artifacts.
4. Each specialist must update required state ledgers when it changes story, character, world, source, layout, or export facts.
5. `chief-editor-orchestrator` runs last.
6. The chief editor reviews specialist evidence, required state, approvals, reader-facing cleanliness, and phase blockers.
7. The phase can pass only when `runtime/agent-compliance/{phase}.json` lists every required agent, every required reference, every required state file, every output artifact, hashes, statuses, and evidence.

## Chief Editor Boundary

`chief-editor-orchestrator` does not write the manuscript. It is the final phase supervisor. Its job is to reject unsupported `PASS` claims and block progress when:

- an agent is missing;
- an agent has no evidence artifact;
- an output artifact is stale, copied, or outside the allowed roots;
- `open-source-story-model.json` was not loaded after `design-big`;
- character knowledge, relationship state, plot promises, source claims, or layout facts changed without ledger updates;
- export tries to package review notes, technical labels, or stale DOCX content.

## Phase Summaries

- `intake`: brief agents ask and lock the book brief; chief editor confirms no default topic was invented.
- `propose`: proposal agent creates options; chief editor confirms no story direction is silently chosen.
- `design-big`: concept, character, plot, structure agents build the book plan, open-source story model, and state ledgers; chief editor confirms the plan is reviewable before user approval.
- `design-small`: chapter-range planners turn the approved plan into scene/continuity planning; chief editor confirms no manuscript was written early.
- `create`: writing agents draft from approved plan/state; chief editor confirms chapter progression, state updates, and evidence.
- `polish`: editorial agents revise structure, continuity, line/copy quality, Turkish language, and layout; chief editor confirms no unresolved rewrite blockers remain.
- `rewrite`: rewrite agents repair only approved/verified failures; chief editor confirms fixes are narrow and state-consistent.
- `export`: export agents package front matter, cover brief, publication checks, and DOCX; chief editor confirms DOCX content/layout/provenance before PASS.

## Fail-Closed Principle

If coordination evidence is ambiguous, the phase must be `BLOCKED`, not `PASS`. A missing artifact is never treated as an implicit success.
