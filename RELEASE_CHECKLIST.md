# Release Checklist

## Versioning
- [ ] Set target version using SemVer.
- [ ] Update `CHANGELOG.md` under a dated version section.
- [ ] Ensure plugin metadata version is consistent (`.claude-plugin/plugin.json`).

## Contract Integrity
- [ ] Run `bash scripts/ci/validate_contracts.sh`.
- [ ] Verify verdict vocabulary (`PASS/REWRITE`) is consistent.
- [ ] Verify language policy constraints are present in core skills.

## Smoke Validation
- [ ] Run `bash scripts/ci/smoke_test.sh`.
- [ ] Confirm fixture paths and required agents/skills exist.

## Export Validation
- [ ] Validate `export-word` pipeline contracts.
- [ ] Verify approval gate and validator gate are mandatory.
- [ ] Verify compatibility test plan is up to date.

## Runtime Observability
- [ ] Verify `run-summary` and metrics contracts are unchanged or intentionally updated.
- [ ] Verify error-code glossary changes are reflected in affected skills/agents.

## Final Review
- [ ] Run `bash scripts/ci/final_readiness_check.sh`.
- [ ] Review `YAPILAN_ISLER.md` for release scope summary.
- [ ] Tag release commit after final verification.
