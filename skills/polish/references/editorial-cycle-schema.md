# Editorial Cycle Schema

Every create, polish, and rewrite phase must produce a machine-readable editorial cycle report:

```text
revision/_workspace/<phase>_editorial-cycle_EP{RANGE}.json
```

## Required Fields
- `run_id`
- `step_id`
- `phase`
- `writing_type`
- `verdict`: `PASS`, `REWRITE`, or `BLOCKED`
- `threshold_pass`
- `scores`
- `issue_summary`
- `required_fixes`
- `next_action`
- `reviewed_artifacts`

## Required Score Axes
Use the axes from `revision/_state/editorial-quality-scorecard.json`.

Common axes:
- `continuity`
- `progression`
- `character_or_argument_depth`
- `style`
- `language`
- `layout`
- `publication-readiness`
- `type-fit`

## Verdict Rules
- `PASS` requires every required score axis to be at or above `threshold_pass`.
- `PASS` is forbidden when `issue_summary.critical > 0`.
- `PASS` is forbidden when `issue_summary.major > 0`.
- `PASS` is forbidden when `issue_summary.manual_review_required=true`.
- `REWRITE` or `BLOCKED` must include at least one concrete `required_fixes` item.

## Next Action Values
- `continue`
- `rewrite_required`
- `user_review_required`
- `blocked`
