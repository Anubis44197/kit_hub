# TDK Exception List (Project Baseline)

Use this list to prevent false positives in automated TDK checks.

## Scope
These exceptions are allowed when clearly intentional and contextually valid.

## Exception Categories

### 1) Proper Nouns and Brand Forms
- Character names, place names, and stylized brand strings.
- Do not auto-normalize unless there is a confirmed typo in project canon.

### 2) Deliberate Voice Patterns
- Character-specific dialect flavor and oral rhythm markers.
- Keep if readability remains acceptable and intent is obvious.

### 3) Lexicalized Forms and Fixed Expressions
- Words that should not be split by mechanical heuristics.
- Examples should be maintained in project-level allowlist as needed.

### 4) Poetic/Stylistic Line Breaks
- Intentional short lines for dramatic pacing.
- Do not merge automatically if emotional rhythm is intentional.

### 5) Quoted Foreign Terms
- Foreign terms inside quotes may be kept as-is if meaning is clear.
- Still block disallowed scripts in core story body per language policy.

## Operational Rule
- If a candidate correction matches an exception category, mark as `manual_review` instead of auto-fix.
- Record exception reason in issue metadata for traceability.
