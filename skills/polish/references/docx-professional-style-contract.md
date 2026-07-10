# DOCX Professional Style Contract

The DOCX export must be ready for editor review and print/e-book conversion.

## Required Sections
- title page
- copyright page placeholder without invented legal data
- preface or foreword when requested
- table of contents data
- chapters in order
- optional acknowledgements, bibliography, glossary, appendix according to writing type

## Formatting Requirements
- stable chapter starts
- consistent paragraph indentation
- consistent dialogue style
- readable trim-size assumptions
- explicit delivery profile: `publisher_submission` or `print_preview`
- explicit page setup in millimeters and Word twips
- Word paragraph styles for body, chapter title, front matter, and TOC text
- body text justified unless the selected publisher profile says otherwise
- body font, size, line spacing, paragraph spacing, and first-line indentation must come from `runtime/layout-profile.json`
- no mojibake
- no TODO markers
- no unsupported fake ISBN, publisher, citation, or legal claim

## Publisher Submission vs Print Preview
- `publisher_submission`: clean editorial Word file. Prefer minimal decoration, no fake imprint data, and no claims that ISBN/barcode/bandrol are complete.
- `print_preview`: reader-facing A5-style proof. It may include page numbers and book-like section breaks only when the exporter can actually encode them.
- A document can be exported for review while `print_ready=false`, but it must be labeled `READY_WITH_PUBLICATION_REVIEW` and must surface missing ISBN/künye/bandrol items.

## Verification
The export validator must confirm:
- package opens as a valid DOCX zip
- required Word XML entries exist
- Word styles exist and are referenced by the document
- section page size/margins match the layout profile within tolerance
- manifest references existing files
- front matter and cover brief exist
- professional writing profile and quality scorecard exist
