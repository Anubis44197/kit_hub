# Golden Expected Output - publication-compliance-checker

Expected contract for publication-compliance-checker agent outputs.

- Output must be non-empty and specific to the input artifact.
- Output must include run_id, step_id, verdict, print_ready, metadata_placeholders, isbn_status, barcode_status, kunye_status, bandrol_external, and block_reasons.
- Output must block fake ISBN, fake barcode, fake publisher, fake copyright owner, and fake official approval.
- Output must not claim bandrol, ministry approval, publisher approval, or ISBN assignment from local DOCX generation.
