# Golden Expected Output - front-matter-editor

Expected contract for `front-matter-editor` agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must not contain placeholder text, TODO markers, or simulated completion claims except explicit print metadata placeholders.
- Required metadata, verdict tokens, issue arrays, manifests, or report sections must follow the agent/skill contract for this role.
- Turkish front matter must remain valid UTF-8 and must not contain mojibake markers.
- Missing legal/publisher metadata must be explicit and must not be invented.

