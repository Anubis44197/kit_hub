# Golden Expected Output - continuity-editor

Expected contract for continuity-editor agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, contradiction list, timeline table, ledger update requirements, and PASS/REWRITE/BLOCKED verdict.
- Output must flag character knowledge leaks, timeline contradictions, object-state conflicts, and unresolved promise drift.
- Turkish story text must remain valid UTF-8 and must not contain mojibake markers.
