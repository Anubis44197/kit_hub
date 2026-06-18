# Golden Expected Output - developmental-editor

Expected contract for developmental-editor agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, writing_type, score_total, axis scores, blocking issues, and PASS/REWRITE/BLOCKED verdict.
- Output must validate reader promise, act balance, chapter purpose, pacing, and completion criteria.
- Turkish story text must remain valid UTF-8 and must not contain mojibake markers.
