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

function Assert-NotContainsText {
  param(
    [string]$Text,
    [string]$Pattern,
    [string]$Message
  )
  if ($Text -match $Pattern) {
    throw $Message
  }
}

$html = Read-Utf8 -RelativePath "index.html"

Assert-NotContainsText -Text $html -Pattern '<section class="ribbon"' -Message "Hidden secondary ribbon must not exist in the authoring UI."
Assert-NotContainsText -Text $html -Pattern 'data-ribbon-tab=' -Message "Hidden ribbon tabs must not remain as dead controls."
Assert-NotContainsText -Text $html -Pattern 'data-ribbon-panel=' -Message "Hidden ribbon panels must not remain as dead controls."
Assert-NotContainsText -Text $html -Pattern 'data-ribbon-action=' -Message "Hidden ribbon actions must not remain as dead controls."
Assert-NotContainsText -Text $html -Pattern '\.ribbon\s*\{' -Message "Hidden ribbon CSS must not remain."
Assert-ContainsText -Text $html -Pattern 'syncFormatButtons' -Message "Editor format synchronization is required."
Assert-ContainsText -Text $html -Pattern '\.tabs\s*\{\s*display:\s*none;' -Message "Workspace tab row must stay hidden to avoid wasting vertical editor space."
Assert-ContainsText -Text $html -Pattern '\.phase-controls\s*\{[\s\S]*?display:\s*none;' -Message "Technical phase selectors must stay hidden in the normal editor flow."
Assert-ContainsText -Text $html -Pattern 'body\.nav-collapsed\s*\{\s*--left-w:\s*0px;' -Message "Collapsed left panel must not leave a vertical strip."
Assert-ContainsText -Text $html -Pattern 'body\.nav-collapsed\s+\.brand\s*\{\s*display:\s*none;' -Message "Collapsed left panel must not leak the brand/logo into the top bar."
Assert-NotContainsText -Text $html -Pattern 'body\.nav-collapsed\s+\.brand\s+strong::after' -Message "Collapsed brand must not synthesize an S logo."
Assert-ContainsText -Text $html -Pattern 'body\.type-collapsed\s*\{\s*--type-h:\s*0px;' -Message "Collapsed typography panel must not leave a bottom strip."
Assert-ContainsText -Text $html -Pattern 'body\.type-collapsed\s+\.typography\s*\{\s*display:\s*none;' -Message "Collapsed typography panel must be fully hidden."
Assert-ContainsText -Text $html -Pattern 'id="toggleWritingTools"' -Message "Top bar must expose a writing tools toggle."
Assert-ContainsText -Text $html -Pattern 'id="settingsMenu"' -Message "Top bar must expose settings as a single gear menu."
Assert-ContainsText -Text $html -Pattern '\.topbar\s*\{[\s\S]*?grid-template-columns:\s*var\(--left-w\) minmax\(0,\s*1fr\) auto;' -Message "Top bar right controls must keep auto width even when the right panel is collapsed."
Assert-ContainsText -Text $html -Pattern '\.topbar\s*\{[\s\S]*?overflow:\s*visible;' -Message "Settings menu must be allowed to overflow above the editor."
Assert-ContainsText -Text $html -Pattern '\.crumbs\s*\{[\s\S]*?grid-column:\s*2;' -Message "Top bar panel controls must stay in the center column."
Assert-ContainsText -Text $html -Pattern '\.top-actions\s*\{[\s\S]*?grid-column:\s*3;' -Message "Top bar settings/export controls must stay in the right auto column."
Assert-ContainsText -Text $html -Pattern '\.settings-panel\s*\{[\s\S]*?z-index:\s*60;' -Message "Settings panel must layer above toolbar and preview."
Assert-ContainsText -Text $html -Pattern '\.settings-panel\s*\{[\s\S]*?top:\s*calc\(100% \+ 16px\);' -Message "Settings panel must open below the top bar button."
Assert-ContainsText -Text $html -Pattern 'id="settingsBridgeStatus"' -Message "Settings must show motor connection status."
Assert-ContainsText -Text $html -Pattern 'id="settingsOutputTarget"' -Message "Settings must include default output target."
Assert-ContainsText -Text $html -Pattern 'data-mode-panel="IDE"' -Message "Settings must explain IDE mode setup."
Assert-ContainsText -Text $html -Pattern 'data-mode-panel="API"' -Message "Settings must expose API mode setup."
Assert-ContainsText -Text $html -Pattern 'id="apiProvider"' -Message "API mode must include provider selection."
Assert-ContainsText -Text $html -Pattern 'id="apiModel"' -Message "API mode must include model selection."
Assert-ContainsText -Text $html -Pattern 'id="apiKeyInput"' -Message "API mode must include API key input."
Assert-ContainsText -Text $html -Pattern 'api/provider-settings' -Message "API settings must persist through Studio Bridge."
Assert-ContainsText -Text $html -Pattern 'configPath:\s*activeMode === "API"' -Message "API mode must run with provider config."
Assert-ContainsText -Text $html -Pattern 'settingsStorageKey' -Message "Settings must persist user choices."
Assert-ContainsText -Text $html -Pattern 'function applyStudioSettings' -Message "Settings must apply to the live editor."
Assert-ContainsText -Text $html -Pattern 'outputTarget' -Message "Export command must receive the selected output target."
Assert-NotContainsText -Text $html -Pattern 'id="settingsApiStatus"' -Message "Settings must not show inactive API status."
Assert-NotContainsText -Text $html -Pattern 'id="settingsProjectFolder"' -Message "Settings must not show inactive project folder controls."
Assert-NotContainsText -Text $html -Pattern 'id="settingsTheme"' -Message "Settings must not show inactive theme controls."
Assert-NotContainsText -Text $html -Pattern 'id="settingsLanguage"' -Message "Settings must not duplicate fixed Turkish language controls."
Assert-NotContainsText -Text $html -Pattern 'id="settingsLayoutProfile"' -Message "Settings must not duplicate typography/layout panel controls."
Assert-NotContainsText -Text $html -Pattern 'class="project-chip" id="projectName"' -Message "Top bar must not show a fake project-title button."
Assert-NotContainsText -Text $html -Pattern '<span>Projeler</span>' -Message "Top bar must not show the old breadcrumb chain."
Assert-NotContainsText -Text $html -Pattern 'id="draftName"' -Message "Top bar must not show the old draft breadcrumb segment."
Assert-NotContainsText -Text $html -Pattern 'Gelişmiş' -Message "Settings must not include an Advanced section."
Assert-ContainsText -Text $html -Pattern 'body\.tools-collapsed\s+\.workspace\s*\{[\s\S]*?grid-template-rows:\s*0 minmax\(0,\s*1fr\) 33px;' -Message "Collapsed writing toolbar must not leave a strip."
Assert-ContainsText -Text $html -Pattern 'body\.tools-collapsed\s+\.toolbar\s*\{\s*display:\s*none;' -Message "Collapsed writing toolbar must be hidden."
Assert-ContainsText -Text $html -Pattern '\.editor-grid\s*\{[\s\S]*?grid-row:\s*2;' -Message "Editor grid must stay in the visible middle row when toolbar is hidden."
Assert-ContainsText -Text $html -Pattern '\.statusbar\s*\{[\s\S]*?grid-row:\s*3;' -Message "Status bar must stay pinned to the bottom row."
Assert-ContainsText -Text $html -Pattern 'id="bookControlMenu"' -Message "Book controls must be grouped into one menu."
Assert-ContainsText -Text $html -Pattern 'data-edit="copy"' -Message "Toolbar must include copy."
Assert-ContainsText -Text $html -Pattern 'data-edit="paste"' -Message "Toolbar must include paste."
Assert-ContainsText -Text $html -Pattern 'data-edit="cut"' -Message "Toolbar must include cut."
Assert-ContainsText -Text $html -Pattern 'data-edit="undo"' -Message "Toolbar must include undo."
Assert-ContainsText -Text $html -Pattern 'data-edit="redo"' -Message "Toolbar must include redo."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="plan"' -Message "Toolbar must expose compact Plan access."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="revision"' -Message "Toolbar must expose compact Revision access."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="versions"' -Message "Toolbar must expose compact Version History access."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="writingCards"' -Message "Toolbar must expose writing cards for controlled scene continuation."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="cards"' -Message "Toolbar must expose a story card board."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="context"' -Message "Toolbar must expose a continuity/context ledger."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="analysis"' -Message "Toolbar must expose repetition/frequency analysis."
Assert-ContainsText -Text $html -Pattern 'id="focusModeBtn"' -Message "Toolbar must expose distraction-free focus writing mode."
Assert-ContainsText -Text $html -Pattern 'renderSupportTab\(nextTab\)' -Message "Toolbar Plan/Revision controls must use the support preview renderer."
Assert-NotContainsText -Text $html -Pattern 'id="genreModeChip"' -Message "Toolbar must not show a redundant genre mode badge."
Assert-NotContainsText -Text $html -Pattern 'class="live-preview-chip"' -Message "Toolbar must not show a redundant live preview badge."
Assert-ContainsText -Text $html -Pattern '<summary>Kontrol</summary>' -Message "Book control menu must use a short label."
Assert-NotContainsText -Text $html -Pattern 'id="renderBtn"' -Message "Manual preview button must not return; preview is live."
Assert-ContainsText -Text $html -Pattern 'id="notesPanel"' -Message "Plan/Revision support must open a notes panel instead of replacing manuscript text."
Assert-ContainsText -Text $html -Pattern 'notesPanel\.classList\.add\("open"\)' -Message "Support notes panel must open from Plan/Revision buttons."
Assert-NotContainsText -Text $html -Pattern 'manuscriptText\.readOnly = tab !== "manuscript"' -Message "Plan/Revision must not lock or replace the manuscript editor."
Assert-ContainsText -Text $html -Pattern 'function renderCardBoard\(\)' -Message "Card board renderer is required for writer planning UX."
Assert-ContainsText -Text $html -Pattern 'draggable="true"' -Message "Story cards must support lightweight drag ordering."
Assert-ContainsText -Text $html -Pattern 'function renderWritingCards\(\)' -Message "Writing cards renderer is required for user-approved writing choices."
Assert-ContainsText -Text $html -Pattern 'function applyWritingCardRequest' -Message "Writing cards must produce a controlled request instead of directly rewriting manuscript text."
Assert-ContainsText -Text $html -Pattern 'data-writing-card-request' -Message "Writing cards must expose an active request action."
Assert-ContainsText -Text $html -Pattern 'bookRequestInput\.value' -Message "Writing card choices must feed the visible book request."
Assert-ContainsText -Text $html -Pattern 'plan-context-boundary' -Message "Writing card request must bind the IDE/API writer to plan and context."
Assert-ContainsText -Text $html -Pattern 'function renderVersionHistory\(\)' -Message "Version history renderer is required for safe revision recovery."
Assert-ContainsText -Text $html -Pattern 'data-version-restore' -Message "Version history must expose a guarded restore action."
Assert-NotContainsText -Text $html -Pattern 'class="run-log"' -Message "Technical run log must not be rendered in the normal authoring surface."
Assert-NotContainsText -Text $html -Pattern 'id="runLogOutput"' -Message "Technical run log output must stay internal, not rendered."
Assert-ContainsText -Text $html -Pattern 'function renderContextLedger\(\)' -Message "Context ledger renderer is required for continuity UX."
Assert-ContainsText -Text $html -Pattern 'function renderTextAnalysis\(\)' -Message "Text analysis renderer is required for repetition checks."
Assert-ContainsText -Text $html -Pattern 'genreBlockOptions' -Message "Genre-specific editor modes must be declared."
Assert-ContainsText -Text $html -Pattern 'function applyGenreMode' -Message "Genre selection must update editor mode controls."
Assert-ContainsText -Text $html -Pattern 'body\.focus-writing' -Message "Focus writing mode must have a dedicated layout state."
Assert-ContainsText -Text $html -Pattern 'previewPageLimit' -Message "Multi-page preview must cap visible pages for performance."
Assert-ContainsText -Text $html -Pattern 'splitPreviewPages' -Message "Preview must split manuscript text into page-like chunks."
Assert-ContainsText -Text $html -Pattern 'Kitap\s+\p{L}ablonu' -Message "Typography panel must present presets as full book templates, not only layout profiles."
Assert-ContainsText -Text $html -Pattern 'id="layoutProfile"' -Message "Typography panel must expose a compact layout profile selector."
Assert-ContainsText -Text $html -Pattern 'layoutProfiles' -Message "Typography panel must define reusable layout profile presets."
Assert-ContainsText -Text $html -Pattern 'function applyLayoutProfile' -Message "Layout profile selector must apply preset values to existing typography controls."
Assert-ContainsText -Text $html -Pattern 'Roman Klasik' -Message "Layout profiles must include a classic novel preset."
Assert-ContainsText -Text $html -Pattern 'publisherA5' -Message "Layout profiles must include a publisher-style A5 preset."
Assert-ContainsText -Text $html -Pattern 'book_template' -Message "Book template selection must be sent to the bridge."
Assert-ContainsText -Text $html -Pattern 'chapter_start_policy' -Message "Book templates must define chapter start behavior."
Assert-ContainsText -Text $html -Pattern 'cover_brief_policy' -Message "Book templates must define cover/package requirements."
Assert-ContainsText -Text $html -Pattern 'page_numbering_policy' -Message "Book templates must define page numbering rules."
Assert-ContainsText -Text $html -Pattern 'id="processTitle"' -Message "Right side panel must expose a friendly process title."
Assert-ContainsText -Text $html -Pattern 'id="processNote"' -Message "Right side panel must expose a friendly process note."
Assert-ContainsText -Text $html -Pattern 'process-card' -Message "Right side panel missing modern process status card."
Assert-ContainsText -Text $html -Pattern 'processSteps' -Message "Right side panel must map technical agent work to friendly writing steps."

Write-Host "[studio-ui-ribbon-test] PASS"
