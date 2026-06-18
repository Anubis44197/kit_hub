# TDK Source and Citation Style Contract

Source basis:
- TDK publication rules provide sample source-list and in-text citation patterns for books, institutional publications, chapters/papers, articles, and theses.

Primary reference:
- https://tdk.gov.tr/yayinlar/yayinlar-yayinlar/basilmak-uzere-verilecek-eserlerde-uyulmasi-gerekli-kurallar/

## Required for Fact-Bearing Works
Apply this contract to:
- essay
- biography
- memoir with verifiable third-party claims
- research_book
- academic
- history/historical nonfiction
- business/self-help when factual claims, statistics, or case claims are used

## Required Checks
- Every factual claim that needs support must map to a source placeholder or citation.
- In-text citation format must be consistent inside the manuscript.
- Source list must include only sources cited in the text.
- Unsourced medical, legal, financial, biographical, historical, or academic claims are blockers.
- Fictional examples must be labeled as fictional examples when placed inside nonfiction.
- Footnotes should not be used as the primary citation method when the active TDK institutional profile requires in-text citation.

## Required Artifacts
- `revision/_state/source-citation-profile.json`
- `revision/_workspace/07_research-citation-auditor_report_EP{NNN}.md`

## Required Report Fields
- `claim_count`
- `supported_claim_count`
- `unsupported_claim_count`
- `citation_style`
- `source_list_status`
- `high_stakes_claims`
- `verdict`
