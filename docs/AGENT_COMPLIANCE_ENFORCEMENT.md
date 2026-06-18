# Agent Compliance Enforcement

The application now treats agent compliance as a runtime contract.

## Why

LLMs can ignore prompts, skip agents, or claim work that was not done. The fix is not stronger wording alone. The workflow must require structured outputs, state files, and validation gates.

## Enforcement Model

Every phase must write:

```text
runtime/agent-compliance/{phase}.json
```

The runner validates:
- required agents are listed;
- every required agent appears in `agents_executed`;
- required references and state files are recorded;
- output artifacts are listed;
- `contract_status` is `PASS`;
- `missing_items` is empty.

If this fails, the phase fails.

## IDE Agent Mode

When using an IDE agent without an API key, the agent must still write the compliance manifest. Manual mode only means a human/IDE writes files before pressing Enter. It does not disable validation.

Use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ide_phase_prompt.ps1 -Phase create
```

The prompt tells the IDE agent which files and agents are mandatory.

## Real LLM Adapter Mode

A real LLM adapter must emit the same compliance manifest. If using an API with strict structured output, bind the manifest to a JSON schema and use strict mode where the provider supports it.

## Current Limitation

The runner can prove that required files exist and manifests pass. It cannot prove a closed-source IDE agent internally reasoned exactly as instructed. This is why artifacts, schema checks, text gates, state ledgers, and export validators are mandatory.
