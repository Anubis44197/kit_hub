# Core Regression Test Spec

Validate critical narrative stability across revisions.

## Coverage
- timeline consistency
- numeric consistency
- voice drift detection

## Required Artifacts
- `tests/regression/core/<case-id>/input.md`
- `tests/regression/core/<case-id>/expected.json`

## Expected JSON Fields
- `timeline_ok` (bool)
- `numbers_ok` (bool)
- `voice_drift_score` (0-100)
- `pass` (bool)

## Fail Rules
- timeline mismatch => fail
- numeric mismatch => fail
- voice_drift_score above project threshold => fail
