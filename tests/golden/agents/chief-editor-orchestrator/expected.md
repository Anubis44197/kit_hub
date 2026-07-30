# Chief Editor Orchestrator Golden Expected

Expected contract:
- The orchestrator does not write manuscript text.
- The orchestrator checks required phase agents, handoff chain, approvals, target metrics, state ledgers, TDK/layout reports, and quality-verifier evidence.
- Missing handoff evidence, missing state updates, stale design hashes, or unsupported PASS claims must produce `BLOCKED` or `REWRITE`.
- A valid PASS must name checked artifacts and confirm that the chapter remains inside `create-plan.json` target bounds.
