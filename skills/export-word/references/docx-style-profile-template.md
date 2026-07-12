# DOCX Style Profile Template

Use this profile for deterministic Word export formatting.

```yaml
docx_style_profile:
  name: "novel-book-default"
  delivery_profiles:
    publisher_submission:
      enabled: true
      purpose: "clean Word file for editor/publisher review"
      page_numbers: "omit_or_editor_added"
      decoration: "minimal"
    print_preview:
      enabled: true
      purpose: "book-like A5 proof for reading and layout inspection"
      page_numbers: "allowed_when_encoded"
      chapter_start: "new_page"
  page:
    size: "A5"            # A5 | A4 | custom
    width_mm: 148
    height_mm: 210
    margin_top_mm: 18
    margin_bottom_mm: 20
    margin_inside_mm: 20
    margin_outside_mm: 16
  typography:
    font_family: "Garamond"
    font_size_pt: 11.5
    line_spacing: 1.15
    paragraph_first_line_indent_cm: 0.55
    paragraph_spacing_after_pt: 0
    justification: "both"
    first_paragraph_after_chapter_indent_cm: 0
  headings:
    chapter_prefix: ""
    chapter_title_style: "KitHubChapterTitle"
    chapter_segmentation: "by_chapter"   # by_chapter | by_part
    scene_break_marker: "***"
  dialogue:
    style: "dash"        # quote | dash
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
- If the target is a publisher submission, keep the Word file clean and do not invent final publisher metadata.
- If the target is print preview, encode page size, margins, paragraph styles, and chapter start behavior in the DOCX.
