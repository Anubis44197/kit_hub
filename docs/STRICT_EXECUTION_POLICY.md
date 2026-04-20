# Strict Execution Policy

This repository uses a proof-first execution policy.

## 1) Completion Claim Rule
A phase or run **must not** be declared completed unless evidence artifacts exist and pass schema checks.

Mandatory for each phase:
- phase evidence json
- artifact gate status
- execution claim mode (`executed` or `simulated`)
- output file references

If any mandatory evidence field is missing, the phase is `failed`.

## 2) Execution Claim Integrity
Only two execution claim modes are allowed:
- `executed`: phase command actually ran through orchestrator in command mode
- `simulated`: command did not run through orchestrator (manual mode or synthetic replay)

Forbidden behavior:
- claiming `executed` while orchestrator did not run the phase command
- claiming phase completion with missing evidence

## 3) User Instruction Compliance
If user requirements are measurable (length, range, language constraints, export approval),
quality gates must check these requirements explicitly and fail when unmet.

## 4) Approval Gates
Runner requires explicit approval artifacts for:
- `create` phase: `runtime/approvals/design-freeze.json`
- `rewrite` phase: `runtime/approvals/rewrite-approval.json`
- `export` phase: `runtime/approvals/export-approval.json`

Without `approved=true`, phase status is `blocked`.

## 5) Hard Contract Validation
Phase outputs are validated with strict contracts:
- issue JSON artifacts must include mandatory keys and allowed severity enums
- verdict markdown artifacts must include `VERDICT` with `PASS|FAIL|BLOCKED`
- export phase must include manifest JSON artifact

If contract validation fails, phase is `failed`.

## 6) Negative Enforcement
For `create/polish/rewrite`, runner blocks forbidden content patterns
from canonical episode outputs.

Default blocked patterns include:
- `TL;DR`
- `Özet:`
- `Summary:`
- `[TODO]`
- `lorem ipsum`

## 7) Script vs Agent Responsibility
- Runner scripts orchestrate phases and validate artifacts.
- Agent contracts define generation behavior.
- Passing artifact gate alone does not imply literary quality.

## 8) Mandatory Runtime Outputs
For each run:
- `runtime/runs/<run_id>/run-summary.json`
- `runtime/runs/<run_id>/evidence/<phase>-<index>.json` (one per phase)
- `runtime/current-run.json`

## 9) CI Contract Binding
Readiness checks must enforce presence of:
- this policy file
- phase evidence schema file
- runner evidence output logic
