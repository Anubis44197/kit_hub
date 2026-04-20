# Execution Plan - 2026-04-20

## Context
- Base repo: `kit_hub` (current HEAD)
- Upstream reference: `MJbae/awesome-novel-studio` (`upstream/main`)
- Goal: enforce instruction compliance and proof-based phase completion.

## Upstream Comparison Anchors
1. Upstream has stronger procedural detail in `skills/create/SKILL.md` and verifier contracts.
2. Upstream does not include `scripts/run_pipeline.ps1`; kit_hub adds orchestration and must enforce evidence gates explicitly.
3. kit_hub has added TDK/layout/export layers; these must remain but become harder to bypass.

## Priority Plan

### P0 - Reliability Hardening (Start Immediately)
1. Add strict execution policy document.
   - File: `docs/STRICT_EXECUTION_POLICY.md`
   - Status: DONE
2. Add phase evidence schema document.
   - File: `docs/PHASE_EVIDENCE_SCHEMA.md`
   - Status: DONE
3. Enforce evidence-gate in runner.
   - File: `scripts/run_pipeline.ps1`
   - Status: DONE
4. Add CI/readiness checks for evidence documents/contracts.
   - Files:
     - `scripts/ci/final_readiness_check.ps1`
     - `scripts/ci/validate_contracts.sh`
   - Status: DONE
5. Update operator docs to avoid script-vs-agent confusion.
   - File: `docs/RUNNER_USAGE.md`
   - Status: DONE

### P1 - Content Quality Contract Tightening
6. Strengthen create contract with measurable targets (length/scene/ratio).
   - File: `skills/create/SKILL.md`
   - Status: DONE
7. Add hard self-check constraints to episode creator.
   - File: `agents/episode-creator.md`
   - Status: DONE
8. Add request-compliance axis in quality verifier.
   - File: `agents/quality-verifier.md`
   - Status: DONE

### P2 - Workspace and Traceability
9. Add workspace retention policy and current-run pointer contract.
   - Files:
     - `docs/WORKSPACE_RETENTION_POLICY.md`
     - `scripts/run_pipeline.ps1` (pointer output)
   - Status: TODO
10. Add CI validation for run evidence schema references.
   - Files:
     - `scripts/ci/final_readiness_check.ps1`
     - `scripts/ci/validate_contracts.sh`
   - Status: TODO

## Do Not Touch (Current Session)
- User-generated test artifacts under `design/`, `episode/`, `revision/`, `novel-config.md`, `dag_evinde_bir_saat.md`.
- These remain as-is unless explicitly requested.

## Execution Log
- [2026-04-20] Plan file created and locked for implementation tracking.
- [2026-04-20] P0 completed: strict policy, phase evidence schema, runner evidence gate, readiness checks, runner docs updated.
- [2026-04-20] P1 completed: create contract metrics, episode creator self-check hardening, quality verifier request-compliance axis.
