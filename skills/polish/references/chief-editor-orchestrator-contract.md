# Chief Editor Orchestrator Contract

The chief editor orchestrator is the supervising phase authority. It does not write the manuscript; it checks whether the required agents produced valid evidence and whether the phase may continue.

## Required Evidence Model
Every required phase agent must have an `agent_evidence` record in `runtime/agent-compliance/{phase}.json`.

Each record must include:
- `agent`
- `status`
- `evidence_artifacts`
- `checks_performed`
- `verdict`

## PASS Rules
A phase may pass only when:
- every phase-contract required agent is executed;
- `agent_sequence` exists in the phase contract and `chief-editor-orchestrator` is last;
- every required agent has `status = completed`;
- every required agent has at least one evidence artifact;
- every evidence artifact exists and is listed in `output_artifacts`;
- the chief editor orchestrator also has evidence for the final phase decision;
- the chief editor verdict lists every non-chief output artifact in `checked_output_artifacts`;
- no `missing_items` are present;
- no specialist verdict is `BLOCKED` or `REWRITE`.

## Blockers
- Missing state ledgers.
- Missing specialist evidence.
- Unsupported official TDK/source verification claims.
- DOCX layout profile claims not proven by DOCX XML.
- Reader-facing technical labels, stale test files, or copied old DOCX outputs.
- Creative writing before user-approved plan gates.

## Coordination Duties
- Read `runtime/phase-contracts/{phase}.json` and follow `agent_sequence`.
- Treat all earlier agents as specialist producers and the chief editor as the final approval gate.
- Compare `required_agents`, `agent_sequence`, `agent_statuses`, `agent_evidence`, `loaded_state_files`, and `output_artifacts`.
- Reject a verdict that omits any non-chief output artifact from `checked_output_artifacts`.
- Block if `revision/_state/open-source-story-model.json` is required but missing from loaded state or evidence.
- Record a final report that names which specialist evidence was accepted and which blockers were checked.
