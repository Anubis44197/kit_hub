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
Export and destructive output operations must require explicit approval artifacts.
Without approval artifact, export status is `blocked`.

## 5) Script vs Agent Responsibility
- Runner scripts orchestrate phases and validate artifacts.
- Agent contracts define generation behavior.
- Passing artifact gate alone does not imply literary quality.

## 6) Mandatory Runtime Outputs
For each run:
- `runtime/runs/<run_id>/run-summary.json`
- `runtime/runs/<run_id>/evidence/<phase>-<index>.json` (one per phase)

## 7) CI Contract Binding
Readiness checks must enforce presence of:
- this policy file
- phase evidence schema file
- runner evidence output logic
