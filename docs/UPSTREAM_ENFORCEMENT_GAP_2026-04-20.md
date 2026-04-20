# Upstream vs kit_hub Enforcement Gap (2026-04-20)

## Why It Behaved as "Advisory"
The main issue was not missing phase names, but weak runtime enforcement.

Observed gaps before this hardening:
- Phase transitions accepted artifact presence only, without strict contract schema checks.
- Approval gates were strict only around export; create/rewrite had no mandatory approval file gate.
- Negative behavior patterns were not runtime-blocked (only prompt-level guidance).
- Common contracts were highly shortened versus upstream in many skill/agent files.
- Runner accepted manual progression without verifying strict phase contract outputs.

## What Was Hardened
1. Hard Contract:
- Runner now enforces issue JSON and verdict markdown contract checks.
- Export requires manifest JSON as hard gate.

2. Deterministic Gate Chain:
- Existing phase chain preserved.
- Contract validation now executes after artifact collection and before phase completion.

3. Forced Approval Checkpoints:
- `create` requires `runtime/approvals/design-freeze.json`
- `rewrite` requires `runtime/approvals/rewrite-approval.json`
- `export` requires `runtime/approvals/export-approval.json`

4. Negative Enforcement:
- Runner blocks forbidden patterns in episode outputs for `create/polish/rewrite`.

5. Proof over Self-Claim:
- Existing evidence chain kept and extended with stricter completion checks.

## Files Updated
- `scripts/run_pipeline.ps1`
- `runtime/runner-config.template.json`
- `scripts/install.ps1`
- `docs/STRICT_EXECUTION_POLICY.md`
- `docs/RUNNER_USAGE.md`
- `README.md`
- `scripts/ci/final_readiness_check.ps1`
- `scripts/ci/validate_contracts.sh`
