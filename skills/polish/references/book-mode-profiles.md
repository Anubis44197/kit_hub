# Book Mode Profile Set

Use one of these presets in `novel-config.md` for consistent output behavior.

## 1) `web_novel`
- Goal: fast mobile readability
- Paragraph density: lower
- Dialogue separation: strong
- Page-end behavior: `auto`
- Recommended for serialized platform publishing

## 2) `print_preview`
- Goal: print-like visual rhythm
- Page size: A5 preferred
- Heading discipline: strict chapter formatting
- Page-end behavior: `chapter_new_page`
- Recommended before physical print preparation

## 3) `ebook`
- Goal: reflow-safe e-book export
- Typography constraints: moderate, device-friendly
- Scene-break markers: explicit and consistent
- Page-end behavior: `auto`
- Recommended for EPUB/MOBI conversion pipelines

## Required Mapping
Each profile must define:
- `dialogue_style`
- `chapter_heading_style`
- `chapter_segmentation`
- `page_end_behavior`
- `paragraph_max_lines_hint`
