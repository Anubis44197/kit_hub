---
name: design-small
description: "Produce detailed chapter-range design using big-design outputs as prerequisites."
prompt_version: "1.0.0"
---

# Design Small Skill

## Purpose
Generate detailed chapter planning for a bounded range.

## Prerequisite
Big-design outputs must already exist.

## Flow
1. Validate target chapter range.
2. Run focused domain research for this range.
3. Orchestrate:
   - character-architect (detail mode)
   - plot-hook-engineer (detail mode)
4. Validate internal consistency.
5. Save detailed docs and update `novel-config.md` range mapping.

## Outputs
- `design/*_character-detail_{range}.md`
- `design/*_plot-detail_{range}.md`
- updated `novel-config.md`
