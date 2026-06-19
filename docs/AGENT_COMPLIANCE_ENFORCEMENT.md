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
- output artifacts are listed as concrete files;
- every output artifact exists and has a matching SHA-256 entry in `artifact_hashes`;
- artifact hashes match the actual file bytes at validation time;
- `contract_hashes` match the current agent registry, status contract, and phase contract;
- every required agent has an `agent_statuses` entry;
- every required agent status is `completed`;
- required agents, references, and loaded state files satisfy `runtime/phase-contracts/{phase}.json`;
- `phase_authority` is one of the accepted execution authorities;
- `completed_at` is a valid timestamp;
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

Use `scripts/ci/write_agent_compliance.ps1` to write the manifest. It computes artifact hashes and contract hashes, then prevents wildcard artifact paths.

## Real LLM Adapter Mode

A real LLM adapter must emit the same compliance manifest. If using an API with strict structured output, bind the manifest to a JSON schema and use strict mode where the provider supports it.

## Current Limitation

The runner can prove that required files exist, hashes match, manifests pass, and exported DOCX content matches the current manuscript. It cannot prove a closed-source IDE agent internally reasoned exactly as instructed. This is why artifacts, schema checks, hash gates, text gates, state ledgers, and export validators are mandatory.

## Agent Governance

The canonical orchestration files are:

```text
runtime/agent-registry.json
runtime/agent-status-contract.json
runtime/phase-contracts/{phase}.json
runtime/runs/{run_id}/run-journal.jsonl
```

Use `scripts/ci/validate_agent_governance.ps1` to verify that the registry, status contract, and phase contracts agree.

## Command and Output Guardrails

Command-mode phases pass a fail-closed command safety gate before execution. Nested `Invoke-Expression`, destructive deletion, destructive git cleanup, remote-download-to-shell patterns, system-changing commands, `file://` indirection, and absolute paths outside the project root are blocked.

Text, Markdown, JSON, YAML, and CSV artifacts also pass a bounded-size gate. This stops an agent from hiding unreviewable bulk output inside evidence files instead of writing the required structured artifacts.
