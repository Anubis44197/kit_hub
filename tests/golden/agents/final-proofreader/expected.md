# Golden Expected Output - final-proofreader

Expected contract for final-proofreader agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, package checklist, blocking issues, and PASS/REWRITE/BLOCKED verdict.
- Output must verify title page, copyright placeholder, preface, TOC, chapter order, cover brief, and manifest references.
- Output must block invented ISBN, publisher, legal claim, fake citation, TODO marker, or malformed DOCX readiness.
