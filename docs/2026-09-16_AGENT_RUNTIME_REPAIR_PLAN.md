# KitHub Agent Runtime Repair Plan

**Date:** 2026-09-16

## Purpose

Make KitHub's visible agent workflow truthful, observable, and safely connected to the existing contract-bound book-production pipeline. This plan does not replace the pipeline with Mercury or Hermes. Those products may be provider or design references; KitHub remains the authority for phase contracts, approvals, artifacts, and publication validation.

## Confirmed Current Architecture

```text
Studio UI (index.html + source bundles)
  -> Studio Bridge (scripts/studio_bridge.ps1)
    -> Pipeline Runner (scripts/run_pipeline.ps1)
      -> phase contracts / agent registry / approval files
        -> project artifacts, compliance manifests, run journal, exports
```

The task panel uses a parallel collaboration layer:

```text
Professional Tools > Agents
  -> task_engine.ps1 task queue and feed
  -> optional provider_phase.ps1 process
```

The two paths currently do not share one authoritative run lifecycle.

## Verified Findings

1. `runtime/runner-config.json` is currently configured with `execution_claim_mode=simulated`, and its phase command fields are blank. This is correct for manual/IDE evidence, but it is not proof of a live provider agent.
2. `/api/task-run` changes a task to `in_flight` before it knows whether a provider process was started. When no provider is configured, it reports `launched=false` but does not convert the task to a truthful blocked/manual state.
3. A provider process launched by the task panel has output/error log paths, but the task queue stores no PID, heartbeat, exit code, timeout result, or supervisor result.
4. Task records declare `deadline`, `attempts`, and `max_attempts`, but there is no active timeout/retry worker that consumes them.
5. The task queue and the pipeline run journal/compliance manifests are separate sources of progress. A task can look completed even when a pipeline phase has not supplied its normal evidence chain.
6. The current task panel has demo history and enabled identity cards; it is a usable collaboration UI but not yet a supervised autonomous runtime.
7. Existing readiness checks pass for the present contract/catalog structure. They do not prove the task lifecycle under provider start, provider crash, timeout, completion, and verification.

## Non-Goals

- Do not add unrestricted shell access, desktop automation, Telegram/Discord channels, or a general personal-assistant memory.
- Do not enable a provider or send an API credential without separate explicit approval.
- Do not claim a model executed when only local/manual artifacts exist.
- Do not weaken current approval, artifact hash, contract hash, or publication gates.

## Target Runtime Model

Every agent task becomes an `AgentRun` with exactly one lifecycle:

```text
queued -> awaiting_approval -> launching -> running -> verifying
                                      |                 |
                                      v                 v
                                   blocked        completed / revision_required / failed / timed_out
```

Manual checklist tasks remain possible, but are explicitly typed as `manual`; they cannot be displayed as provider-executed work.

## Phase 0 - Safety and Regression Baseline

### Work

- Add isolated tests for the task API: create, approval semantics, no-provider launch, provider launch, crash, timeout, retry, cancel, and verification result.
- Add a temporary-project test fixture; do not mutate the application repo's demo task history.
- Record the current runtime contract hashes before behavior changes.

### Success Criteria

- A failed provider start cannot leave a task shown as running.
- A provider crash and timeout produce explicit terminal states.
- Existing final-readiness and governance checks remain green.

## Phase 1 - Single Source of Truth for Agent Execution

### Work

- Create `runtime/runs/<run-id>/agent-runs/<task-id>.json` as the execution record.
- Store task type, phase, scope, provider/model identifier, run id, process id when present, timestamps, heartbeat, retry count, logs, evidence paths, and final verdict.
- Make the task panel read this execution record for provider-backed tasks.
- Preserve `task-feed.json` as an activity stream, not a competing completion authority.

### Success Criteria

- The Studio state shows the same result as the run journal and compliance manifest.
- Every provider-backed task can be traced from UI card to logs, evidence, and phase output.

## Phase 2 - Provider Supervisor and Truthful State

### Work

- Replace fire-and-forget provider launching with a supervisor.
- Capture PID, exit code, stderr summary, elapsed time, and heartbeat updates.
- Enforce bounded timeout and retry policy per agent registry entry.
- Mark missing provider configuration as `blocked` with a human-readable action, not `in_flight`.
- Mark a provider result `verifying` until current pipeline evidence validates it.

### Success Criteria

- No task remains indefinitely in `running` after a process exits or times out.
- Retry is bounded and visible.
- A task cannot become `completed` merely because a process was launched.

## Phase 3 - Context Pack Instead of Generic Personal Memory

### Work

- Build a read-only, phase-scoped context pack from existing project state: book DNA, writing type, chapter plan, character state, timeline, continuity ledger, promise/payoff ledger, knowledge graph, style profile, and relevant chapter text.
- Hash and record the selected inputs in the AgentRun record.
- Enforce the existing agent registry `allowed_write_roots` before any provider output is applied.

### Success Criteria

- A chapter agent receives only relevant approved project context.
- The same input state generates an auditable context fingerprint.
- No user-wide or cross-book personal memory is introduced.

## Phase 4 - Planner, Executor, Verifier Separation

### Work

- Use the existing phase contracts to separate plan, generation/editing, and validation responsibilities.
- Keep quality-verifier, TDK, continuity, and export validation independent from the executor result.
- Route failed verification into `revision_required`, with named issues and linked artifacts.

### Success Criteria

- An agent cannot approve its own unverified output.
- The UI shows why a task failed and which artifact requires attention.

## Phase 5 - Studio UX and Operational Clarity

### Work

- Show execution type: `manual`, `provider`, or `simulated`.
- Show status, elapsed time, current step, retry count, provider/model label, and evidence link on each task.
- Separate human approval of a result from permission to perform a destructive or publishing action.
- Add empty/error states for missing provider, inactive trigger, and unavailable model.

### Success Criteria

- "Running" always means a supervised process is alive.
- "Completed" always explains whether it is manual completion or evidence-verified provider completion.
- The user can cancel or inspect every live task without reading logs manually.

## Phase 6 - Provider Evaluation and Rollout

### Work

- Add provider-neutral fixtures for DeepSeek, Hermes-compatible OpenAI endpoints, and local Ollama/LM Studio.
- Test only with a dedicated temporary book project and non-sensitive configuration.
- Measure completion accuracy, invalid output rate, timeout rate, retry rate, token/cost estimate, and human correction rate by phase.
- Enable one low-risk analysis phase first; do not begin with manuscript overwrite or export.

### Success Criteria

- Provider adoption is based on measured phase results, not model marketing.
- Manuscript-writing and export remain behind explicit approvals until the evaluation passes.

## Proposed Implementation Order

1. Phase 0 and the no-provider/provider-crash state fixes.
2. Phase 1 AgentRun record and UI read model.
3. Phase 2 supervisor, timeout, and bounded retry.
4. Phase 3 context pack.
5. Phase 4 verifier integration.
6. Phase 5 UI polish.
7. Phase 6 provider evaluation.

## Approval Gates

Approval is required before:

1. Saving or testing any external provider/API key.
2. Enabling a model to modify manuscript files.
3. Enabling automatic retries beyond the configured safe bound.
4. Running an end-to-end provider test against a real book project.
5. Publishing, exporting, or pushing any changes remotely.

## Recommended First Change

Implement Phase 0 plus the small truthful-state repair in Phase 2:

- no-provider task -> `blocked` with a clear reason;
- provider process -> supervised AgentRun record;
- process failure/timeout -> `failed` or `timed_out`;
- completion -> `verifying` until existing evidence gates pass.

This improves truthfulness and safety without changing the current book-production contract or connecting any provider.
