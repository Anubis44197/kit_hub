# WORK_DIR Isolation Policy

This policy defines project/user isolation boundaries.

## Core Rule
- Every run must operate inside its assigned `{WORK_DIR}`.
- No read/write outside `{WORK_DIR}` except approved shared references.

## Write Scope
- Allowed: `{WORK_DIR}/_workspace/`, `{WORK_DIR}/export/`, project-local episode/design/revision paths.
- Blocked: parent directories, sibling project directories, user home paths outside project scope.

## Multi-Project Safety
- Each project must have unique `WORK_DIR`.
- `run_id` must be unique per `WORK_DIR`.
- Never merge artifacts from different `WORK_DIR` roots in one run.

## Violation Handling
- On boundary violation attempt, mark step as `blocked`.
- Use error code: `E_WORKDIR_BOUNDARY`.
