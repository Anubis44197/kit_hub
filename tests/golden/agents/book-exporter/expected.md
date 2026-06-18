# Golden Expected Output - book-exporter

Expected contract for $agent agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must not contain placeholder text, TODO markers, or simulated completion claims.
- Required metadata, verdict tokens, issue arrays, manifests, or report sections must follow the agent/skill contract for this role.
- Turkish story text must remain valid UTF-8 and must not contain mojibake markers.
- Any blocking condition must be explicit and include the relevant error code when the role contract defines one.
