# TDK Official Writing Rules Contract

Source basis:
- Turkish Language Association publication rules state that spelling and punctuation, including abbreviations, must follow the latest TDK Writing Guide.
- TDK online dictionaries are the official lookup source for current Turkish spelling and vocabulary decisions.

Primary references:
- https://tdk.gov.tr/yayinlar/yayinlar-yayinlar/basilmak-uzere-verilecek-eserlerde-uyulmasi-gerekli-kurallar/
- https://sozluk.gov.tr/

## Mandatory Checks
- Turkish story/body text must use valid UTF-8 Turkish characters.
- Mojibake markers such as `Ã`, `Ä`, `Å` must block export.
- Punctuation, abbreviations, capitalization, compound-word decisions, proper names, and foreign-origin words must be checked against TDK references when the relevant checker has online/provider access.
- When online lookup is unavailable, the checker must record `provider_status: unavailable` and must not claim official dictionary verification.
- Creative style is allowed only where it does not contradict spelling, punctuation, or clear-reader requirements.

## Required Report Fields
- `run_id`
- `step_id`
- `source_basis`
- `provider_status`
- `checked_categories`
- `critical_issues`
- `warnings`
- `verdict`: `PASS`, `REWRITE`, or `BLOCKED`

## Blocking Conditions
- Encoding corruption.
- Unresolved critical spelling or punctuation errors.
- Official-source verification claimed without provider evidence.
- Non-Turkish body text where the project requires Turkish.
