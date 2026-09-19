# KitHub Agent Runtime Repair Progress

Plan: `2026-09-16_AGENT_RUNTIME_REPAIR_PLAN.md`  
Updated: 2026-09-16

## Completed

- [x] Persistent AgentRun record: run ID, PID, log paths, heartbeat, exit code, terminal timestamp.
- [x] Provider task starts only after configuration validation and a successful local process launch.
- [x] Local no-key provider endpoints are supported; remote providers require a protected key.
- [x] Provider wrapper writes terminal AgentRun state after the worker exits.
- [x] Task defaults to post-result human approval unless explicitly disabled by an API caller.
- [x] Isolated task → run → terminal-state regression fixture.
- [x] PowerShell parser and final-readiness checks after the runtime changes.

## In Progress

- [ ] Watchdog: process liveness, timeout enforcement, bounded retry, cancellation of the child process.
- [ ] Task API regression cases: missing provider, crash, timeout, retry, cancel, verification result.
- [ ] Studio task-card run history, logs, elapsed time, and runtime status presentation.

## Not Started

- [ ] Read-only phase-scoped context pack with source hashes.
- [ ] Planner / executor / independent verifier workflow and `revision_required` result.
- [ ] Provider evaluation with a temporary non-sensitive project.
