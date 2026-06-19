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
- required references;
- required state files;
- required approvals;
- allowed output patterns;
- denied output patterns;
- status contract.

These files replace scattered, prompt-only agent expectations. The runner still performs its existing artifact gates, but the phase contract is now the governance layer above them.

## User Prompt Flow

1. User gives a simple or detailed book idea.
2. `propose` expands the idea into options.
3. `design-big` creates the full book plan, chapter plan, layout plan, and state ledgers.
4. The user approves `runtime/approvals/book-plan-approval.json`.
5. `design-small` prepares chapter-range scene plans.
6. `create` writes manuscript chapters from approved state only.
7. `polish` edits language, continuity, structure, TDK, and style.
8. `rewrite` repairs only verified failures.
9. `export` packages the current manuscript into front matter, cover brief, publication checks, and DOCX.

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
- phase authority;
- missing items.

The runner rejects `PASS` if any required agent status is not `completed`.

## DeerFlow Adaptation Boundary

The project adapts DeerFlow's useful control ideas:

- registry-bound agents;
- structured statuses;
- fail-closed guardrails;
- event journal;
- phase/tool permission boundaries.

It does not copy DeerFlow as a full FastAPI/LangGraph/Next.js platform. `kit_hub` remains a focused book-production pipeline.
