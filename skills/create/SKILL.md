---
name: create
description: "Create book chapters sequentially using mapped design docs, guard rails, continuity tracking, and automated quality gates."
prompt_version: "1.0.0"
---

# Create Skill

## Purpose
Write book chapters with a multi-agent pipeline and strict validation. Legacy file ids still use `episode/epNNN.md`; reader-facing output must treat them as chapters.

## Pipeline
1. Chapter blueprint (`episode-architect`)
2. Continuity report (`continuity-bridge`)
3. Chapter context selection (`context-saliency-gate`)
4. Draft writing (`episode-creator`)
5. Turkish language and book-mode polish (`tdk-polisher`, CREATE mode) [mandatory]
6. Book layout normalization (`tdk-layout-agent`) [mandatory when `book_mode.enabled=true`]
7. Validation (`quality-verifier`, CREATE mode)
8. Retry loop on REWRITE verdict (bounded)

## Upstream Parity Notes
- This create contract intentionally follows stricter upstream-style guardrails:
  - measurable target checks
  - explicit request compliance
  - bounded retry with fail-safe rewrite

## Config Source
- `novel-config.md` is required.
- `revision/_state/open-source-story-model.json` is required and governs chapter/scene cards, character depth, plot progression, world continuity, cross-references, and reader-output cleanup.
- `revision/_state/story-bible.json`, `revision/_state/chapter-continuity-chain.json`, and `revision/_state/context-saliency-map.json` are required and govern what story context the writer agent may see for each chapter.

## Create Target Contract (Mandatory)
If `novel-config.md` includes a `create_quality` block, the values below are mandatory gates:
- `min_characters`
- `max_characters`
- `min_scene_blocks`
- `dialogue_ratio_min`
- `dialogue_ratio_max`

If `create_quality` is not present, use defaults:
- `min_characters=6500`
- `max_characters=14000`
- `min_scene_blocks=4`
- `dialogue_ratio_min=0.35`
- `dialogue_ratio_max=0.65`

Create flow must fail to `REWRITE` when any mandatory target is outside range.

## Request Compliance Contract (Mandatory)
If `novel-config.md` includes `request_contract`, treat it as a hard user-constraint block.
Example keys:
- `content_objective`
- `min_output_length`
- `must_include`
- `must_avoid`

Rule:
- if `request_contract` exists, `quality-verifier` must evaluate it as a dedicated axis (`REQUEST_COMPLIANCE`)
- unresolved request mismatch => `REWRITE`

## Language Policy
- Chapter/story content language must be Turkish.
- Skill/agent contracts and tooling instructions remain English.
- Preserve valid UTF-8 Turkish characters; mojibake or unexplained non-Turkish script usage must be reported as a quality issue.

## Security and Privacy Policy
- Apply PII redaction policy to reports/logs: `references/pii-redaction-policy.md`.
- Respect WORK_DIR isolation boundaries: `references/workdir-isolation-policy.md`.
- If boundary violation is detected, block step with `E_WORKDIR_BOUNDARY`.

## Runtime Metadata Contract
- Every create run must have a `run_id` in format: `RUN-YYYYMMDD-HHMMSS-XXXX`.
- Every pipeline step must have a `step_id` in format: `create-<step-number>`.
- All generated reports must include `run_id` and `step_id` in header metadata.
- Create flow must update `{WORK_DIR}/_workspace/run-summary.json` after each step.
- For blocked/failed steps, `error_code` must come from `references/error-code-glossary.md`.
- Create flow must emit `{WORK_DIR}/_workspace/pipeline-metrics.json`.
- Create flow must emit `{WORK_DIR}/_workspace/pipeline-bottleneck-report.md`.

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

## Final Episode Writeback Rule (Mandatory)
- If `book_mode.enabled=true`, canonical final text source is:
  - `{WORK_DIR}/_workspace/09_tdk-layout_bookmode_EP{NNN}.md`
- If `book_mode.enabled=false`, canonical final text source is:
  - `{WORK_DIR}/_workspace/08_tdk-polisher_polished_EP{NNN}.md`
- Orchestrator must write canonical text back to:
  - `episode/epNNN.md`

## Mandatory Artifact Gates
- Do not run `quality-verifier` before `08_tdk-polisher_issues_EP{NNN}.json` and `08_tdk-polisher_report_EP{NNN}.md` exist.
- If `book_mode.enabled=true`, do not run `quality-verifier` before `09_tdk-layout_issues_EP{NNN}.json` and `09_tdk-layout_report_EP{NNN}.md` exist.
- Do not accept `PASS` if create target contract metrics are missing in verifier report.
- Do not accept `PASS` unless `revision/_workspace/create_editorial-cycle_EP{RANGE}.json` exists and follows `skills/polish/references/editorial-cycle-schema.md`.
- If any mandatory artifact is missing, stop with explicit artifact-missing error.

## Longform Progression State Contract
Every created chapter must update `revision/_state/chapter-summaries.json` with:
- `id`
- `summary`
- `previous_chapter_result`
- `new_event`
- `new_information`
- `irreversible_change`
- `next_causal_link`
- `state_updates`

The next chapter's `previous_chapter_result` must connect to the previous chapter's `next_causal_link`. Repeating the same event, summary, or irreversible change is a hard failure.

## Length Fulfillment Contract
Target length is variable. A user may request 10, 50, 245, 500, or more pages. Do not collapse the request into a fixed three-part story.

Before drafting, load `revision/_state/longform-plan.json`, `revision/_state/volume-plan.json`, and `revision/_state/chapter-plan.json`. Treat these as the production contract:
- `target_pages` defines the requested book scale.
- `target_words` defines the minimum manuscript mass needed for that scale.
- `target_chapters` defines how many reader-facing chapters must exist before export.
- each chapter `target_words` defines the chapter budget.
- `max_chapters_per_batch` defines how many chapters may be written before state ledgers must be updated and reloaded.

If the model cannot finish the whole target in one response, write only the approved batch, update all state ledgers, and continue with the next batch. Never mark the book complete, request export, or claim final delivery while planned chapters are missing or total words/pages are under target.

## Context Saliency Contract
Before `episode-creator` writes a chapter batch, `context-saliency-gate` must produce:
- `revision/_workspace/context-saliency-gate_EP{RANGE}.json`
- `revision/_workspace/context-saliency-gate_EP{RANGE}.md`

The writer agent may use only:
- the current chapter card from `chapter-plan.json`
- prior chapter dependency from `chapter-continuity-chain.json`
- visible items selected in `context-saliency-map.json`
- approved user constraints from `book-brief.json` and `book-dna.json`

The writer agent must not load stale projects, sample manuscripts, unrelated DOCX files, hidden future reveals, or the full raw Story Bible. If chapter context selection is missing or ambiguous, stop with `BLOCKED` instead of drafting.

## Macro Continuity Audit Contract
Read `revision/_state/volume-plan.json.audit_schedule`. When generated chapters reach a scheduled marker such as `EP010`, emit:
- `revision/_workspace/macro-continuity-audit_EP010.json`
- `revision/_workspace/macro-continuity-audit_EP010.md`

The JSON must include `run_id`, `through_chapter`, `verdict`, `checked_ledgers`, `open_risks`, and `required_fixes`. `verdict` must be `PASS` before the run can continue, and `checked_ledgers` must include every longform state ledger.

## Outputs
- `episode/epNNN.md` (legacy storage path for chapter NNN)
- workspace reports under `{work_dir}/_workspace/`
- context saliency gate reports for every generated chapter batch
- mandatory TDK polisher outputs (`08_tdk-polisher_*`)
- mandatory layout outputs when book mode is enabled (`09_tdk-layout_*`)
- verifier report with explicit target metrics and request compliance result
- editorial cycle JSON report (`create_editorial-cycle_EP{RANGE}.json`)
- updated create progress plan
