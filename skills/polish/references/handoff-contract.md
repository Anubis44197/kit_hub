# Handoff Contract

Standard contract for inter-agent payload transfer.

## Required Handoff Fields
- `run_id`
- `step_id`
- `from_agent`
- `to_agent`
- `episode`
- `task_id`
- `input_artifacts`
- `output_artifacts`
- `state_artifacts_read`
- `state_artifacts_written`
- `must_verify_before_start`
- `blocking_issues`
- `error_code` (nullable)

## Rules
- No handoff without `output_artifacts`.
- If `blocking_issues` is non-empty, next step must verify before execution.
- `run_id` must remain unchanged within the same pipeline run.
- The receiving agent must not start from memory or conversation context alone; it must read `input_artifacts`, `state_artifacts_read`, and the immediately previous handoff.
- `episode-creator`, `episode-rewriter`, and `revision-executor` must update the relevant state ledgers when their output changes story facts.
- `quality-verifier` and `revision-reviewer` must reject any handoff that lacks concrete state evidence for character, plot, timeline, and chapter progression.

## Required Chain for Chapter Writing
1. `episode-architect` writes the chapter blueprint and target metrics.
2. `continuity-bridge` writes continuity constraints from the approved state ledger and lookback window.
3. `episode-creator` writes only the requested chapter batch.
4. `tdk-polisher` checks Turkish language and encoding.
5. `tdk-layout-agent` normalizes book-mode reader text.
6. `quality-verifier` accepts only when text, metrics, request compliance, and state updates all pass.

Skipping a link in this chain is a hard failure.
