---
name: design-small
description: "Produce detailed chapter-range design using big-design outputs as prerequisites."
prompt_version: "1.1.0"
---

# Design Small Skill

## Purpose
Generate detailed chapter planning for a bounded range.

## Prerequisite
Big-design outputs must already exist and `runtime/approvals/book-plan-approval.json` must be approved by the user. Do not proceed from `design-big` to `design-small` without this approval.

## Flow
1. Validate target chapter range against `revision/_state/chapter-plan.json`.
2. Load and obey `revision/_state/book-plan.json`, `revision/_state/open-source-story-model.json`, `revision/_state/layout-plan.json`, `revision/_state/longform-plan.json`, `revision/_state/character-state.json`, `revision/_state/plot-ledger.json`, and `revision/_state/continuity-ledger.json`.
3. Run focused domain research only when source artifacts will be recorded; otherwise do not claim research.
4. Orchestrate:
   - character-architect (detail mode)
   - plot-hook-engineer (detail mode)
5. Validate internal consistency and cause-effect continuity.
6. Save detailed docs and update `novel-config.md` range mapping.

## Hard Rules
- `runtime/approvals/book-plan-approval.json` must be approved before this phase.
- Do not write manuscript chapters in this phase.
- Do not use placeholder language such as `plan_required`, `to_be_confirmed`, `TBD`, `TODO`, or "fill in later".
- Every scene/chapter detail must advance plot, character, or theme.
- No reader-facing title may be `EP001`, `Scene 1`, `Sahne 1`, or another technical label.
- Character knowledge must not exceed `character-state.json`.
- Scene cards must obey `open-source-story-model.json` outline, character, plot, world, cross-reference, and export models.

## Outputs
- `design/*_character-detail_{range}.md`
- `design/*_plot-detail_{range}.md`
- `design/*scene_plan*.md`
- updated `novel-config.md`
