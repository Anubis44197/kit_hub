# LLM Agent Compliance Policy

This policy makes agent instructions enforceable by artifacts, not trust.

Source basis:
- OpenAI Structured Outputs recommends schema-bound outputs over plain JSON mode because schema adherence is enforced when `strict: true` is used.
- OpenAI function calling strict mode recommends `strict: true` for reliable schema adherence and requires all fields to be required with `additionalProperties=false`.
- Agent workflows should use orchestration, handoffs, guardrails, results/state, and evaluation when workflows become complex.
- Claude tool use supports strict tool use and hard tool choice when tool/schema adherence is required.

## Mandatory Rule
Every phase must produce an agent compliance manifest:

```text
runtime/agent-compliance/{phase}.json
```

The runner must fail the phase when this manifest is missing, malformed, incomplete, or marked anything other than `PASS`.

## Required Manifest Fields
- `run_id`
- `phase`
- `required_agents`
- `agents_executed`
- `required_references`
- `loaded_state_files`
- `output_artifacts`
- `contract_status`
- `missing_items`

## Hard Requirements
- `required_agents` must be non-empty.
- Every `required_agents[]` item must appear in `agents_executed[]`.
- `contract_status` must be `PASS`.
- `missing_items` must be empty.
- If a phase uses state, `loaded_state_files` must list the state files used.
- If a phase writes outputs, `output_artifacts` must list the produced artifacts.

## LLM / IDE Agent Instructions
An LLM or IDE agent must:
- read the phase prompt;
- read the relevant agent files under `agents/`;
- read the relevant skill and reference files under `skills/`;
- read required state files under `revision/_state/`;
- write the required artifacts;
- write the compliance manifest last.

If the LLM cannot satisfy a required agent, reference, state file, or output artifact, it must write `contract_status: "BLOCKED"` with explicit `missing_items`.

## Non-Negotiable
The runner must not accept a phase merely because the model says it is done. Only files and manifest validation count.
