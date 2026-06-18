# Publication Metadata Checklist

This checklist defines metadata needed before a book can be described as publication-ready.

Source basis:
- The Turkish Ministry of Culture and Tourism / KYGM ISBN-related notices state that book identity and publication metadata must be handled carefully, including ISBN, barcode, imprint/copyright page, publication year, edition number, and print quantity where applicable.

Primary reference:
- https://ekygm.gov.tr/

## Required Metadata Fields
- title
- subtitle, if any
- author or editor name
- publisher or self-publisher identity
- copyright owner
- publication year
- edition number
- print quantity, when print-run metadata is required
- ISBN, when assigned
- barcode status, when assigned
- imprint/copyright page status
- format: print, e-book, audiobook, or set

## Hard Rules
- Do not invent ISBN.
- Do not invent publisher.
- Do not invent barcode.
- Do not invent copyright owner.
- If ISBN exists, ISBN shown in metadata, copyright/imprint page, and barcode metadata must match.
- If the book is a set or multi-volume work, every component that requires an ISBN/bandrol must be tracked separately.

## Blocking Conditions
- `print_ready=true` with missing title, author/publisher identity, copyright owner, or publication year.
- ISBN/barcode mismatch.
- Missing imprint/copyright page.
- Fake or placeholder ISBN marked as final.
- Set/multi-volume metadata collapsed into one untracked identifier.
