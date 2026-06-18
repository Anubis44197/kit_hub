# ISBN, Kunye, and Bandrol Checklist

Source basis:
- KYGM/ISBN announcements state that assigned ISBN is an international identity number for the book and that published ISBNs are not casually deleted or discarded.
- The same source notes that imprint/copyright page information and barcode/ISBN consistency matter for book handling.

Primary reference:
- https://ekygm.gov.tr/

## ISBN Rules
- ISBN is optional until the user or publisher assigns one.
- Once assigned for a real publication, ISBN must be treated as a stable identity field.
- Do not generate fake ISBN values.
- Do not mark placeholder ISBN as final.
- For set books, track ISBN at component level and set level when applicable.

## Kunye / Imprint Page Checks
The imprint/copyright page should track:
- title
- author/editor
- publisher/self-publisher
- copyright owner
- publication year
- edition/printing information
- ISBN if assigned
- barcode status if assigned
- cover/design credits when provided
- legal disclaimers or rights text only when supplied or explicitly approved

## Bandrol / Distribution Notes
- The app must not claim bandrol completion.
- It may generate a checklist item saying bandrol/publisher workflow remains external.
- It must not infer official approval from local DOCX generation.

## Required Output
- `revision/_workspace/14_publication-compliance_report_EP{RANGE}.md`
- `revision/_workspace/14_publication-compliance_verdict_EP{RANGE}.json`
