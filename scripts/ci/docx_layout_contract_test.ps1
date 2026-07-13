param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$RelativePath)
  $path = Join-Path $RepoRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing required file: $RelativePath"
  }
  return [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
}

function Assert-ContainsText {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Message
  )
  if ($Text -notmatch $Pattern) {
    throw $Message
  }
}

$localPhase = Read-Utf8 -RelativePath "scripts/local_phase.ps1"
$verifier = Read-Utf8 -RelativePath "scripts/ci/verify_docx_layout_profile.ps1"
$styleTemplate = Read-Utf8 -RelativePath "skills/export-word/references/docx-style-profile-template.md"
$professionalContract = Read-Utf8 -RelativePath "skills/polish/references/docx-professional-style-contract.md"

Assert-ContainsText -Text $localPhase -Pattern 'font_family\s*=\s*"Garamond"' -Message "Local adapter must default fiction print preview to Garamond."
Assert-ContainsText -Text $localPhase -Pattern 'font_size_pt\s*=\s*11\.5' -Message "Local adapter must default fiction body font to 11.5 pt."
Assert-ContainsText -Text $localPhase -Pattern 'margin_top_mm\s*=\s*18' -Message "Local adapter missing A5 top margin default."
Assert-ContainsText -Text $localPhase -Pattern 'margin_bottom_mm\s*=\s*20' -Message "Local adapter missing A5 bottom margin default."
Assert-ContainsText -Text $localPhase -Pattern 'margin_inside_mm\s*=\s*20' -Message "Local adapter missing inside margin default."
Assert-ContainsText -Text $localPhase -Pattern 'margin_outside_mm\s*=\s*16' -Message "Local adapter missing outside margin default."
Assert-ContainsText -Text $localPhase -Pattern 'paragraph_first_line_indent_cm\s*=\s*0\.55' -Message "Local adapter missing first-line indent default."
Assert-ContainsText -Text $localPhase -Pattern 'paragraph_spacing_after_pt\s*=\s*0' -Message "Local adapter must avoid blank-line paragraph spacing in prose body."
Assert-ContainsText -Text $localPhase -Pattern 'KitHubBodyFirst' -Message "DOCX exporter must encode first-paragraph-after-title style."
Assert-ContainsText -Text $localPhase -Pattern 'w:firstLine="0"' -Message "DOCX exporter must encode unindented first paragraph after chapter title."
Assert-ContainsText -Text $localPhase -Pattern 'KitHubChapterTitle' -Message "DOCX exporter must encode chapter title style."
Assert-ContainsText -Text $localPhase -Pattern 'w:footerReference' -Message "DOCX exporter must be able to encode footer/page number references."
Assert-ContainsText -Text $localPhase -Pattern 'PAGE' -Message "DOCX exporter must be able to encode Word PAGE field."

Assert-ContainsText -Text $verifier -Pattern 'KitHubBodyFirst' -Message "DOCX layout verifier must check first paragraph style."
Assert-ContainsText -Text $verifier -Pattern 'chapter_start=new_page' -Message "DOCX layout verifier must enforce chapter new-page profile."
Assert-ContainsText -Text $verifier -Pattern 'page_numbers' -Message "DOCX layout verifier must enforce page-number profile."
Assert-ContainsText -Text $verifier -Pattern 'word/footer1.xml' -Message "DOCX layout verifier must inspect footer XML."
Assert-ContainsText -Text $verifier -Pattern 'w:pgSz' -Message "DOCX layout verifier must inspect page size."
Assert-ContainsText -Text $verifier -Pattern 'w:pgMar' -Message "DOCX layout verifier must inspect page margins."

foreach ($required in @(
  'font_family: "Garamond"',
  'font_size_pt: 11.5',
  'line_spacing: 1.15',
  'paragraph_first_line_indent_cm: 0.55',
  'paragraph_spacing_after_pt: 0',
  'first_paragraph_after_chapter_indent_cm: 0',
  'chapter_start: "new_page"',
  'page_numbers: "allowed_when_encoded"'
)) {
  Assert-ContainsText -Text $styleTemplate -Pattern ([regex]::Escape($required)) -Message "DOCX style template missing required print-preview setting: $required"
}

foreach ($required in @(
  'consistent paragraph indentation',
  'Word paragraph styles',
  'body font, size, line spacing',
  'trade fiction print preview',
  'no mojibake',
  'no unsupported fake ISBN'
)) {
  Assert-ContainsText -Text $professionalContract -Pattern ([regex]::Escape($required)) -Message "Professional style contract missing rule: $required"
}

Write-Host "[docx-layout-contract-test] PASS"
