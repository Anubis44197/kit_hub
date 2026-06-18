# LLM Adapter Contract

Production AI integrations may use any provider, but they must preserve this contract.

## Required Behavior
- Load the active writing profile before drafting.
- Load longform state before every chapter batch.
- Generate in bounded batches. Default maximum is 3 chapters per batch.
- After every generated chapter, update chapter summary, character state, plot or argument ledger, continuity ledger, and style profile.
- Refuse export when required ledgers are missing or stale.
- Preserve Turkish UTF-8 output for story content.
- Preserve official-rule provenance for TDK and publication-compliance checks; never claim online official verification when provider access is unavailable.

## Long Manuscript Strategy
For 200 to 500+ page books, the model must not attempt a single-pass full manuscript. It must use:
- project bible
- act/chapter plan
- rolling chapter summaries
- character/claim/plot ledgers
- continuity ledger
- style profile
- editorial scorecard after each batch
- TDK/publication compliance check before export

## Required Metadata
Every model step must stamp:
- `run_id`
- `step_id`
- `adapter_id`
- `effective_model`
- `input_state_files`
- `output_artifacts`

## Provider Boundary
This repository ships a deterministic local adapter for validation. Real AI writing requires replacing the command adapter in `runtime/runner-config.json` with a provider-backed command that emits the same artifacts.
