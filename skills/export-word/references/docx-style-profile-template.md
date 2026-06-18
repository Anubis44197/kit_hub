# DOCX Style Profile Template

Use this profile for deterministic Word export formatting.

```yaml
docx_style_profile:
  name: "novel-book-default"
  page:
    size: "A5"            # A5 | A4 | custom
    margin_top_mm: 20
    margin_bottom_mm: 20
    margin_left_mm: 18
    margin_right_mm: 18
  typography:
    font_family: "Garamond"
    font_size_pt: 11
    line_spacing: 1.3
    paragraph_first_line_indent_cm: 0.6
    paragraph_spacing_after_pt: 4
  headings:
    chapter_prefix: "BÖLÜM"
    chapter_title_style: "Heading1"
    chapter_segmentation: "by_chapter"   # by_chapter | by_part
    scene_break_marker: "***"
  dialogue:
    style: "quote"        # quote | dash
    keep_speaker_turn_new_line: true
  page_end:
    behavior: "chapter_new_page"  # auto | chapter_new_page
  output:
    include_toc: true
    keep_unicode: true
    include_front_matter: true
    require_cover_brief_manifest: true
```

Notes:
- Keep `dialogue.style` aligned with project `book_mode.dialogue_style`.
- If project is print-preview focused, prefer `A5`.
