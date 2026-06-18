# Runner Usage

## Purpose
`scripts/run_pipeline.ps1` is a real orchestrator entrypoint for this repository.
It executes the full phase chain with artifact-gate validation:

`propose -> design-big -> design-small -> create -> polish -> rewrite -> export`

Important:
- Runner validates phase artifacts and emits run/evidence logs.
- Runner execution is not equal to literary quality acceptance by itself.
- Phase completion claims are proof-bound by evidence files.

## 1) Install Bootstrap

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

This creates:
- `runtime/runner-config.json` (if missing)
- `runtime/runs/`
- `runtime/approvals/design-freeze.json`
- `runtime/approvals/rewrite-approval.json`
- `runtime/approvals/export-approval.json`

## 2) Manual Mode (Default)

Manual mode still asks the user/IDE to run each phase, but phase transitions and artifact gates are automated and tracked.
Manual mode records `execution_claim_mode=simulated`; use command mode when you need real execution proof.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase export
```

Create the manual IDE config first:

```powershell
Copy-Item runtime/runner-config.ide-manual.template.json runtime/runner-config.ide-manual.json -Force
```

For the current phase, print an IDE-agent task prompt:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ide_phase_prompt.ps1 -Phase design-big
```

Use `-NoWait` to skip enter prompts (useful for prefilled test runs):

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase polish -NoWait
```

## 3) Command Mode

Edit `runtime/runner-config.json` and fill `phase_commands`.
Then set `execution_mode` to `command`.

By default this repository now ships with a local command adapter:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/local_phase.ps1 -ProjectRoot "." -Phase propose -RunId "RUN-LOCAL"
```

For a simple user topic, write the topic into:

```text
runtime/book-request.md
```

If that file is missing or still contains the `Konu Bekleniyor` placeholder, the local adapter must fail before generation. The repository must not silently write a default novel topic.

The local adapter is deterministic and validates the full book-package pipeline; replace it with a real model command when production AI generation is wired.

Important:
- Local adapter mode is for pipeline testing, not literary quality.
- IDE manual mode is for API-free real writing when an IDE agent writes the files.
- Command mode is for automatic CLI/model integrations.

Example:
```json
{
  "execution_mode": "command",
  "phase_commands": {
    "propose": "my-agent-cli run /propose",
    "design-big": "my-agent-cli run /design-big",
    "design-small": "my-agent-cli run /design-small",
    "create": "my-agent-cli run /create",
    "polish": "my-agent-cli run /polish",
    "rewrite": "my-agent-cli run /rewrite",
    "export": "my-agent-cli run /export-word"
  }
}
```

Then run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase propose -ToPhase export -Mode command
```

## 3.1) Optional Dictionary Check Layer

You can enable an additional dictionary-verification pass for Turkish text quality.
This runs automatically after `create`, `polish`, and `rewrite` phases.

In `runtime/runner-config.json`:

```json
{
  "quality_flags": {
    "enable_dictionary_check": true,
    "dictionary_check_command": "powershell -ExecutionPolicy Bypass -File scripts/ci/tdk_dict_check.ps1 -ProjectRoot \"{project_root}\" -Phase {phase} -RunId {run_id} {require_provider_arg}",
    "require_dictionary_provider": true
  }
}
```

Output artifact:
- `revision/_workspace/10_tdk-dictionary-check_<phase>.json`

You can also force-enable from CLI:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -FromPhase create -ToPhase rewrite -EnableDictionaryCheck
```

With `require_dictionary_provider=true`, missing Python or `tdk-py` fails the run instead of writing a skipped report.

## 4) Run Summary

Each run writes:
- `runtime/runs/RUN-YYYYMMDD-HHMMSS/run-summary.json`
- `runtime/runs/RUN-YYYYMMDD-HHMMSS/evidence/<phase>-<index>.json`
- `runtime/current-run.json`

This is the canonical runner execution log.

`runtime/current-run.json` always points to the latest run state and latest evidence file.

## 4.1) Execution Claim Modes

Phase evidence includes:
- `execution_claim_mode=executed`: phase command ran through command mode
- `execution_claim_mode=simulated`: no command execution proof (manual mode or synthetic run)

Do not report an executed run without `executed` evidence records.
To enforce this during the run, set `quality_flags.require_executed_claims_for_critical_phases=true` after command mode is configured.

## 4.2) Retention

Runner can prune old run folders automatically after run completion.

In `runtime/runner-config.json`:

```json
{
  "quality_flags": {
    "retention": {
      "enabled": true,
      "max_runs": 20
    }
  }
}
```

Pruning only affects `runtime/runs/RUN-*` directories.

## 5) Artifact Gates

The runner validates required artifacts per phase before moving forward.
If missing, the run fails immediately with a clear message.

## 5.0) Text And Continuity Gates

When `quality_flags.enable_text_quality_gates=true`, `create`, `polish`, and `rewrite` are blocked if the generated chapters contain reader-facing technical labels, encoding corruption, short chapter bodies, repeated lines, repeated paragraph openings, invalid dialogue ratio, or weak show-dont-tell balance.

Longform continuity gates also compare chapters against each other. The run fails if chapters are too similar, if chapter openings repeat, if `revision/_state/chapter-summaries.json` contains duplicated summaries, if a chapter lacks `new_information`, if `irreversible_change` is missing/repeated, or if `plot-ledger.json` lacks a cause-effect entry for each generated chapter.

Relevant config keys:

```json
{
  "quality_flags": {
    "text_quality_gates": {
      "max_duplicate_line_ratio": 0.28,
      "max_repeated_paragraph_prefix": 1,
      "paragraph_prefix_length": 95
    },
    "cross_chapter_gates": {
      "max_chapter_similarity": 0.72,
      "max_opening_prefix_repeat": 1,
      "min_event_markers_per_chapter": 4
    }
  }
}
```

## 5.1) Approval Gates (Hard)

When `quality_flags.require_user_approvals=true` (default), these gates are mandatory:
- `create` requires `runtime/approvals/design-freeze.json` with `approved=true`
- `rewrite` requires `runtime/approvals/rewrite-approval.json` with `approved=true`
- `export` requires `runtime/approvals/export-approval.json` with `approved=true`

Without approval, phase is blocked.

## 5.2) Phase Contracts (Hard)

When `quality_flags.enforce_phase_contracts=true` (default):
- issue JSON artifacts are schema-validated (required fields + severity enum)
- verdict markdown must include `VERDICT: PASS|FAIL|BLOCKED`
- export requires manifest JSON artifact
- every phase requires `runtime/agent-compliance/{phase}.json`
- agent compliance manifests must include required agents, executed agents, references, state files, output artifacts, `contract_status=PASS`, and empty `missing_items`

Schema mismatch fails the phase.

## 5.3) Negative Enforcement

When `quality_flags.enable_negative_enforcement=true` (default),
runner scans episode outputs and blocks forbidden patterns.

Default patterns are configurable under:
- `quality_flags.forbidden_content_patterns`

## 6) Policy Documents

- `docs/STRICT_EXECUTION_POLICY.md`
- `docs/PHASE_EVIDENCE_SCHEMA.md`
- `docs/WORKSPACE_RETENTION_POLICY.md`
- `docs/IDE_AGENT_WORKFLOW.md`
