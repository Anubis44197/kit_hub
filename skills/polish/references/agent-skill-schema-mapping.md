# Agent/Skill Schema Mapping

This mapping binds current flows to the shared task schema.

## Create Flow
- `episode-architect` -> `create.blueprint_build`
- `continuity-bridge` -> `create.continuity_build`
- `episode-creator` -> `create.episode_draft`
- `tdk-polisher` -> `validate.tdk_polish`
- `tdk-layout-agent` -> `validate.layout_polish`
- `quality-verifier` -> `validate.quality_gate`

## Polish Flow
- `rule-checker` -> `polish.rule_diagnose`
- `story-analyst` -> `polish.story_diagnose`
- `platform-optimizer` -> `polish.platform_diagnose`
- `alive-enhancer` -> `polish.alive_diagnose`
- `revision-executor` -> `polish.revision_apply`
- `tdk-polisher` -> `validate.tdk_polish`
- `tdk-layout-agent` -> `validate.layout_polish`
- `revision-reviewer` -> `validate.revision_gate`

## Rewrite Flow
- `revision-analyst` -> `rewrite.drift_analyze`
- `character-sculptor` -> `rewrite.character_analyze`
- `episode-rewriter` -> `rewrite.episode_rebuild`
- `tdk-polisher` -> `validate.tdk_polish`
- `tdk-layout-agent` -> `validate.layout_polish`
- `quality-verifier` -> `validate.quality_gate`

## Export Flow
- `export-approval-gate` -> `export.approval_gate`
- `export-validator` -> `export.readiness_validate`
- `book-exporter` -> `export.word_docx`
