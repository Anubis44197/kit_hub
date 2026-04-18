# TDK Regression Test Spec

Validate repeated correctness on Turkish rule-sensitive patterns.

## Coverage
- `de/da` separation and suffix handling
- `ki` usage
- question particle `mi/mi/mu/mu`
- apostrophe and punctuation spacing
- optional dictionary verification consistency (`tdk_dict_check`)

## Required Artifacts
- `tests/regression/tdk/<case-id>/input.md`
- `tests/regression/tdk/<case-id>/expected_issues.json`

## Pass Rules
- no unresolved critical TDK issue
- expected issue types are detected
- no forbidden script detected
- dictionary-check findings (if present) are auto-resolved or flagged for manual review
