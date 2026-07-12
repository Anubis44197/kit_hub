# Agent Orchestration Architecture

This project uses contract-bound agent orchestration for long-form Turkish book production. Agent prompts are not trusted as the source of truth. The runner validates agents, phases, artifacts, state files, hashes, and statuses.

## Goal

The system must not let an IDE agent or LLM:

- invent a default book topic;
- skip the planning and user approval gate;
- claim agents ran without structured evidence;
- copy stale DOCX/test outputs;
- write manuscript text from the export phase;
- continue after character, plot, or chapter-state contradictions.

## Agent Registry

Canonical file:

```text
runtime/agent-registry.json
```

Every agent declares:

- `name`
- `allowed_phases`
- `required_references`
- `allowed_write_roots`
- `timeout_seconds`
- `max_turns`

The runner rejects a phase if a required agent is missing from the registry or is not allowed in that phase.

## Chief Editor Orchestrator

`chief-editor-orchestrator` is required across phases. It is the supervising editor layer: it does not write the manuscript, but it verifies that the specialist agents produced evidence and that the phase can continue.

Its job is to block:

- unsupported `PASS` claims;
- missing specialist evidence;
- fake official TDK/source verification;
- export claims not proven by DOCX XML;
- stale copied outputs;
- creative writing that bypasses approved plans.

## Status Contract

Canonical file:

```text
runtime/agent-status-contract.json
```

Allowed statuses:

- `completed`
- `failed`
- `blocked`
- `timed_out`
- `invalid_output`

A phase can pass only when every required agent has `completed` in `agent_statuses`.

## Phase Contracts

Canonical directory:

```text
runtime/phase-contracts/
```

Each phase contract declares:

- required agents;
- ordered `agent_sequence`;
- required references;
- required state files;
- required approvals;
- allowed output patterns;
- denied output patterns;
- status contract.

These files replace scattered, prompt-only agent expectations. The runner still performs its existing artifact gates, but the phase contract is now the governance layer above them.

`agent_sequence` is the coordination plan. Specialist agents run first; `chief-editor-orchestrator` must be last when present. The chief editor is not another writer. It is the final phase supervisor that accepts or blocks the specialist work based on evidence, state ledgers, approvals, and output cleanliness.

## User Prompt Flow

1. User gives a simple or detailed book idea.
2. `intake` asks/structures the missing decisions and writes `runtime/book-brief.json`, `runtime/book-dna.json`, and `runtime/layout-profile.json`.
3. The user approves `runtime/approvals/book-brief-approval.json`.
4. `propose` expands the approved brief into options.
5. `design-big` creates the full book plan, chapter plan, layout plan, and state ledgers.
6. The user approves `runtime/approvals/book-plan-approval.json`.
7. `design-small` prepares chapter-range scene plans.
8. `create` writes manuscript chapters from approved state only.
9. `polish` edits language, continuity, structure, TDK, and style.
10. `rewrite` repairs only verified failures.
11. `export` packages the current manuscript into front matter, cover brief, publication checks, and DOCX.

## Run Journal

Every runner execution writes:

```text
runtime/runs/{run_id}/run-journal.jsonl
```

Events include:

- `phase.started`
- `phase.completed`
- `phase.failed`
- `run.completed`

This is the audit trail. It is not a literary output and must not be used as manuscript content.

## Compliance Manifest

Every phase must write:

```text
runtime/agent-compliance/{phase}.json
```

The manifest must include:

- required agents;
- executed agents;
- required references;
- loaded state files;
- output artifacts;
- artifact hashes;
- agent statuses;
- agent evidence;
- phase authority;
- missing items.

The runner rejects `PASS` if any required agent status is not `completed`, or if any required agent lacks an `agent_evidence` record with existing evidence artifacts and checks performed.

Each manifest also carries `contract_hashes` for:

- `runtime/agent-registry.json`
- `runtime/agent-status-contract.json`
- the active `runtime/phase-contracts/{phase}.json`

If any governance contract changes, an old manifest cannot be replayed as a fresh success.

## DeerFlow Adaptation Boundary

The project adapts DeerFlow's useful control ideas:

- registry-bound agents;
- structured statuses;
- fail-closed guardrails;
- event journal;
- contract/catalog hash stamping;
- command and output-budget guardrails;
- phase/tool permission boundaries.

It does not copy DeerFlow as a full FastAPI/LangGraph/Next.js platform. `kit_hub` remains a focused book-production pipeline.
