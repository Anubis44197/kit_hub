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

$tabMatches = [regex]::Matches($html, 'data-ribbon-tab="([^"]+)"')
$tabs = @(
  $tabMatches |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch '^\$' } |
    Sort-Object -Unique
)
$panelMatches = [regex]::Matches($html, 'data-ribbon-panel="([^"]+)"')
$panels = @(
  $panelMatches |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notmatch '^\$' } |
    Sort-Object -Unique
)
$tabPanelMismatch = @($tabs | Where-Object { $_ -notin $panels })
if ($tabPanelMismatch.Count -gt 0) {
  throw "Ribbon tabs without matching panel: $($tabPanelMismatch -join ', ')"
}

Assert-ContainsText -Text $html -Pattern 'role="tablist"' -Message "Ribbon missing tablist role."
Assert-ContainsText -Text $html -Pattern 'role="tabpanel"' -Message "Ribbon missing tabpanel role."
Assert-ContainsText -Text $html -Pattern '\.ribbon\s*\{\s*display:\s*none;' -Message "Secondary ribbon row must stay hidden; the top app bar is the only visible top control bar."
Assert-ContainsText -Text $html -Pattern 'id="ribbonHelp"' -Message "Ribbon missing contextual help line."
Assert-ContainsText -Text $html -Pattern 'class="ribbon-status"' -Message "Ribbon missing compact status strip."
Assert-ContainsText -Text $html -Pattern '\.ribbon-panels\s*\{\s*display:\s*none;' -Message "Ribbon command panels must stay visually hidden to avoid duplicate controls."
Assert-ContainsText -Text $html -Pattern 'id="ribbonLayoutState"' -Message "Ribbon missing active layout state badge."
Assert-ContainsText -Text $html -Pattern 'ribbonLayoutState\.textContent' -Message "Ribbon layout badge must update from typography controls."
Assert-ContainsText -Text $html -Pattern 'const order = \["start", "writing", "plan", "agents", "layout", "publish"\]' -Message "Ribbon missing Alt+1..6 tab order."
Assert-ContainsText -Text $html -Pattern 'syncFormatButtons' -Message "Ribbon missing editor format synchronization."
Assert-ContainsText -Text $html -Pattern 'selectWorkspaceTab\(button\.dataset\.tab, true\)' -Message "Workspace tabs must sync the ribbon tab."
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
Assert-NotContainsText -Text $html -Pattern 'function applyLayoutProfile' -Message "Settings must not secretly override typography/layout controls."
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
Assert-ContainsText -Text $html -Pattern 'function renderContextLedger\(\)' -Message "Context ledger renderer is required for continuity UX."
Assert-ContainsText -Text $html -Pattern 'function renderTextAnalysis\(\)' -Message "Text analysis renderer is required for repetition checks."
Assert-ContainsText -Text $html -Pattern 'genreBlockOptions' -Message "Genre-specific editor modes must be declared."
Assert-ContainsText -Text $html -Pattern 'function applyGenreMode' -Message "Genre selection must update editor mode controls."
Assert-ContainsText -Text $html -Pattern 'body\.focus-writing' -Message "Focus writing mode must have a dedicated layout state."
Assert-ContainsText -Text $html -Pattern 'previewPageLimit' -Message "Multi-page preview must cap visible pages for performance."
Assert-ContainsText -Text $html -Pattern 'splitPreviewPages' -Message "Preview must split manuscript text into page-like chunks."
Assert-ContainsText -Text $html -Pattern 'id="processTitle"' -Message "Right side panel must expose a friendly process title."
Assert-ContainsText -Text $html -Pattern 'id="processNote"' -Message "Right side panel must expose a friendly process note."
Assert-ContainsText -Text $html -Pattern 'process-card' -Message "Right side panel missing modern process status card."
Assert-ContainsText -Text $html -Pattern 'processSteps' -Message "Right side panel must map technical agent work to friendly writing steps."

Write-Host "[studio-ui-ribbon-test] PASS"
