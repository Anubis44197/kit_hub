---
name: polish
description: "Polish chapters through book-structure diagnostics, editorial correction, TDK checks, and layout review."
prompt_version: "1.0.0"
---

# Polish Skill

## Purpose
Run systematic editorial correction over existing chapters.

## Pipeline
1. Parallel diagnostics:
   - rule-checker
   - story-analyst
   - book-structure-optimizer
   - developmental-editor
   - continuity-editor
   - context-saliency-gate
   - research-citation-auditor when writing type is nonfiction or fact-bearing
   - alive-enhancer
2. Correction execution (`revision-executor`)
3. Line and copy editing:
   - line-editor
   - copy-editor
4. Turkish language and book-mode polish (`tdk-polisher`, POLISH mode) [mandatory]
   - Optional dictionary verification layer (`tdk_dict_check`) can run after this step
5. Book layout normalization (`tdk-layout-agent`) [mandatory when `book_mode.enabled=true`]
6. Correction review (`revision-reviewer`)
7. Final proof package review (`final-proofreader`) before export
8. Self-loop until chapter batch is complete

## Config Source
- `novel-config.md`

## Language Policy
- Chapter/story content language must be Turkish.
- Skill/agent contracts and tooling instructions remain English.
- Preserve valid UTF-8 Turkish characters; mojibake or unexplained non-Turkish script usage must be reported as a quality issue.

## Security and Privacy Policy
- Apply PII redaction policy to reports/logs: `references/pii-redaction-policy.md`.
- Respect WORK_DIR isolation boundaries: `references/workdir-isolation-policy.md`.
- If boundary violation is detected, block step with `E_WORKDIR_BOUNDARY`.

## Runtime Metadata Contract
- Every polish run must have a `run_id` in format: `RUN-YYYYMMDD-HHMMSS-XXXX`.
- Every pipeline step must have a `step_id` in format: `polish-<step-number>`.
- All generated reports must include `run_id` and `step_id` in header metadata.
- Polish flow must update `{WORK_DIR}/_workspace/run-summary.json` after each step.
- For blocked/failed steps, `error_code` must come from `references/error-code-glossary.md`.
- Polish flow must emit `{WORK_DIR}/_workspace/pipeline-metrics.json`.
- Polish flow must emit `{WORK_DIR}/_workspace/pipeline-bottleneck-report.md`.

## Model Routing Policy
- Model selection must follow:
  - `skills/polish/references/model-capability-matrix.md`
  - `skills/polish/references/model-fallback-timeout-policy.md`
- A/B prompt experiments must follow:
  - `skills/polish/references/prompt-ab-experiment-spec.md`

## Model Adapter Contract
- Shared task envelope must follow:
  - `skills/polish/references/shared-task-schema.md`
- Agent/skill mapping must follow:
  - `skills/polish/references/agent-skill-schema-mapping.md`
- Adapter behavior must follow:
  - `skills/polish/references/adapter-claude-codex.md`
  - `skills/polish/references/adapter-generic-ide-model.md`
- Verdict/report format must follow:
  - `skills/polish/references/verdict-report-standard.md`
  - `skills/polish/references/workflow-report-json-schema.md`
- Inter-agent handoff payload must follow:
  - `skills/polish/references/handoff-contract.md`
- Professional writing behavior must follow:
  - `skills/polish/references/writing-type-profiles.md`
  - `skills/polish/references/genre-structure-templates.md`
  - `skills/polish/references/editorial-quality-scorecard.md`
  - `skills/polish/references/llm-adapter-contract.md`
  - `skills/polish/references/docx-professional-style-contract.md`

## Final Episode Writeback Rule (Mandatory)
- If `book_mode.enabled=true`, canonical final text source is:
  - `{WORK_DIR}/_workspace/09_tdk-layout_bookmode_EP{NNN}.md`
- If `book_mode.enabled=false`, canonical final text source is:
  - `{WORK_DIR}/_workspace/08_tdk-polisher_polished_EP{NNN}.md`
- Orchestrator must write canonical text back to:
  - `episode/epNNN.md`

## Open Source Story Model Contract
- `revision/_state/open-source-story-model.json` is mandatory before polish.
- Polish agents must preserve its outline, character, plot, world, cross-reference, research and export models.
- Any polish change that alters character knowledge, relationship state, plot promises, settings, source claims or scene order must update the matching state ledger in the same phase.

## Context Saliency Contract
- `revision/_state/story-bible.json`, `revision/_state/chapter-continuity-chain.json`, and `revision/_state/context-saliency-map.json` are mandatory before polish.
- `context-saliency-gate` must confirm that polish changes stay inside the visible chapter context.
- Polish may not introduce future-only reveals, unplanned characters, stale sample text, unrelated project content, or character knowledge absent from `knowledge-graph.json`.
- If polish needs new context, update the appropriate state ledger first and explain the reason in the workspace report.

## Mandatory Artifact Gates
- Do not run `revision-reviewer` before `08_tdk-polisher_issues_EP{NNN}.json` and `08_tdk-polisher_report_EP{NNN}.md` exist.
- If `book_mode.enabled=true`, do not run `revision-reviewer` before `09_tdk-layout_issues_EP{NNN}.json` and `09_tdk-layout_report_EP{NNN}.md` exist.
- Do not run export before `revision/_state/open-source-story-model.json`, `revision/_state/writing-type-profile.json`, `revision/_state/genre-structure-template.json`, `revision/_state/editorial-quality-scorecard.json`, and `revision/_state/llm-adapter-contract.json` exist.
- Do not accept `PASS` unless `revision/_workspace/polish_editorial-cycle_EP{RANGE}.json` exists and follows `skills/polish/references/editorial-cycle-schema.md`.
- If any mandatory artifact is missing, stop with explicit artifact-missing error.

## Outputs
- updated episodes
- polish reports in workspace
- mandatory TDK polisher outputs (`08_tdk-polisher_*`)
- optional dictionary verification report (`10_tdk-dictionary-check_<phase>.json`)
- mandatory layout outputs when book mode is enabled (`09_tdk-layout_*`)
- professional editorial reports from developmental, continuity, line, copy, research/citation, and final proof stages
- editorial cycle JSON report (`polish_editorial-cycle_EP{RANGE}.json`)
- professional writing state files in `revision/_state/`
- updated fix plan and trackers
