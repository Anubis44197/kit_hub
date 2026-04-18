# Copyright Compliance Checklist

Use this checklist when source-based or attribution-based generation is enabled.

## Pre-Generation
- Confirm source usage mode is explicitly enabled in config.
- Record source list and usage scope.
- Ensure no full-text copy behavior is requested.

## During Generation
- Prefer transformation/summarization over verbatim reuse.
- Keep direct quotes minimal and attributed when required.
- Do not embed copyrighted third-party passages as manuscript body text.

## Pre-Export
- Verify attribution notes exist when required by source policy.
- Verify no long verbatim extraction appears in generated outputs.
- Block export if unresolved copyright risk is detected.

## Required Report Fields
- `source_mode_enabled`
- `source_list`
- `attribution_required`
- `copyright_risk` (`none` | `low` | `medium` | `high`)
- `export_blocked` (bool)
