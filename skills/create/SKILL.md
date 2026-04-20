---
name: create
description: "Create episode manuscripts sequentially using mapped design docs, guard rails, and automated quality gates."
prompt_version: "1.0.0"
---

# Create Skill

## Purpose
Write episodes with a multi-agent pipeline and strict validation.

## Pipeline
1. Episode blueprint (`episode-architect`)
2. Continuity report (`continuity-bridge`)
3. Draft writing (`episode-creator`)
4. Turkish language and book-mode polish (`tdk-polisher`, CREATE mode) [mandatory]
5. Book layout normalization (`tdk-layout-agent`) [mandatory when `book_mode.enabled=true`]
6. Validation (`quality-verifier`, CREATE mode)
7. Retry loop on REWRITE verdict (bounded)

## Upstream Parity Notes
- This create contract intentionally follows stricter upstream-style guardrails:
  - measurable target checks
  - explicit request compliance
  - bounded retry with fail-safe rewrite

## Config Source
- `novel-config.md` is required.

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
- Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana.

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
- If any mandatory artifact is missing, stop with explicit artifact-missing error.

## Outputs
- `episode/epNNN.md`
- workspace reports under `{work_dir}/_workspace/`
- mandatory TDK polisher outputs (`08_tdk-polisher_*`)
- mandatory layout outputs when book mode is enabled (`09_tdk-layout_*`)
- verifier report with explicit target metrics and request compliance result
- updated create progress plan

