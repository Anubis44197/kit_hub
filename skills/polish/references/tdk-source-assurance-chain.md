# TDK Source Assurance Chain

This document defines the publication-grade verification chain for Turkish spelling and writing mechanics.

## Layer 1: Official Rule Authority (Primary)
- Source: `tdk-official-baseline.md`
- Purpose: normative writing and punctuation rules.

## Layer 2: Dictionary Verification (Optional but Recommended)
- Provider: `tdk-py` integration via `scripts/ci/tdk_dict_check.py`
- Purpose: detect probable misspellings and unknown forms using TDK-backed dictionary queries.
- Policy:
  - Dictionary output is advisory unless confidence is high.
  - Unknown words are `manual_review` by default.

## Layer 3: Exception Governance
- Source: `tdk-exception-list.md`
- Purpose: avoid false positives for proper nouns, dialect voice, poetic breaks, and canon-specific terms.

## Layer 4: Regression Safety
- Source: `tdk-regression-test-spec.md`
- Purpose: ensure repeated consistency on `de/da`, `ki`, question particles, apostrophes, and punctuation spacing.

## Layer 5: Human Editorial Review (Final)
- Mandatory for publication-grade release.
- Focus:
  - narrative tone preservation
  - intentional voice vs mechanical error
  - unresolved ambiguity from automated layers

## Decision Policy
- Auto-fix only for deterministic and high-confidence issues.
- Route uncertain corrections to manual review.
- Final canonical episode writeback must happen only after quality gates pass.
