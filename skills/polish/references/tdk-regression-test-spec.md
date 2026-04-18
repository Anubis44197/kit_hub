# TDK Regression Test Spec

Validate repeated correctness on Turkish rule-sensitive patterns.

## Coverage
- `de/da` separation and suffix handling
- `ki` usage
- question particle `mi/mı/mu/mü`
- apostrophe and punctuation spacing

## Required Artifacts
- `tests/regression/tdk/<case-id>/input.md`
- `tests/regression/tdk/<case-id>/expected_issues.json`

## Pass Rules
- no unresolved critical TDK issue
- expected issue types are detected
- no forbidden script detected
