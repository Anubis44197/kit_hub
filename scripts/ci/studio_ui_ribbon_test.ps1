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
Assert-ContainsText -Text $html -Pattern 'data-support-tab="plan"' -Message "Toolbar must expose compact Plan access."
Assert-ContainsText -Text $html -Pattern 'data-support-tab="revision"' -Message "Toolbar must expose compact Revision access."
Assert-ContainsText -Text $html -Pattern 'renderSupportTab\(nextTab\)' -Message "Toolbar Plan/Revision controls must use the support preview renderer."
Assert-ContainsText -Text $html -Pattern 'class="live-preview-chip"' -Message "Toolbar must show live preview state instead of a redundant preview button."
Assert-NotContainsText -Text $html -Pattern 'id="renderBtn"' -Message "Manual preview button must not return; preview is live."
Assert-ContainsText -Text $html -Pattern 'id="notesPanel"' -Message "Plan/Revision support must open a notes panel instead of replacing manuscript text."
Assert-ContainsText -Text $html -Pattern 'notesPanel\.classList\.add\("open"\)' -Message "Support notes panel must open from Plan/Revision buttons."
Assert-NotContainsText -Text $html -Pattern 'manuscriptText\.readOnly = tab !== "manuscript"' -Message "Plan/Revision must not lock or replace the manuscript editor."
Assert-ContainsText -Text $html -Pattern 'id="processTitle"' -Message "Right side panel must expose a friendly process title."
Assert-ContainsText -Text $html -Pattern 'id="processNote"' -Message "Right side panel must expose a friendly process note."
Assert-ContainsText -Text $html -Pattern 'process-card' -Message "Right side panel missing modern process status card."
Assert-ContainsText -Text $html -Pattern 'processSteps' -Message "Right side panel must map technical agent work to friendly writing steps."

Write-Host "[studio-ui-ribbon-test] PASS"
