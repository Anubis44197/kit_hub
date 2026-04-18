---
name: polish
description: "Polish episodes through parallel diagnostics and sequential correction-review loops."
prompt_version: "1.0.0"
---

# Polish Skill

## Purpose
Run systematic editorial correction over existing episodes.

## Pipeline
1. Parallel diagnostics:
   - rule-checker
   - story-analyst
   - platform-optimizer
   - alive-enhancer
2. Correction execution (`revision-executor`)
3. Turkish language and book-mode polish (`tdk-polisher`, POLISH mode) [mandatory]
   - Optional dictionary verification layer (`tdk_dict_check`) can run after this step
4. Book layout normalization (`tdk-layout-agent`) [mandatory when `book_mode.enabled=true`]
5. Correction review (`revision-reviewer`)
6. Self-loop until episode batch is complete

## Config Source
- `novel-config.md`

## Language Policy
- Chapter/story content language must be Turkish.
- Skill/agent contracts and tooling instructions remain English.
- Disallowed scripts in story content: Hangul, Han, Hiragana, Katakana.

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

## Final Episode Writeback Rule (Mandatory)
- If `book_mode.enabled=true`, canonical final text source is:
  - `{WORK_DIR}/_workspace/09_tdk-layout_bookmode_EP{NNN}.md`
- If `book_mode.enabled=false`, canonical final text source is:
  - `{WORK_DIR}/_workspace/08_tdk-polisher_polished_EP{NNN}.md`
- Orchestrator must write canonical text back to:
  - `episode/epNNN.md`

## Mandatory Artifact Gates
- Do not run `revision-reviewer` before `08_tdk-polisher_issues_EP{NNN}.json` and `08_tdk-polisher_report_EP{NNN}.md` exist.
- If `book_mode.enabled=true`, do not run `revision-reviewer` before `09_tdk-layout_issues_EP{NNN}.json` and `09_tdk-layout_report_EP{NNN}.md` exist.
- If any mandatory artifact is missing, stop with explicit artifact-missing error.

## Outputs
- updated episodes
- polish reports in workspace
- mandatory TDK polisher outputs (`08_tdk-polisher_*`)
- optional dictionary verification report (`10_tdk-dictionary-check_<phase>.json`)
- mandatory layout outputs when book mode is enabled (`09_tdk-layout_*`)
- updated fix plan and trackers

