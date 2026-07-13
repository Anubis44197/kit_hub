param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Assert-File {
  param([string]$RelativePath)
  $path = Join-Path $RepoRoot $RelativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Missing required file: $RelativePath"
  }
}

function Assert-Contains {
  param([string]$RelativePath, [string]$Pattern, [string]$Message)
  $path = Join-Path $RepoRoot $RelativePath
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  if ($text -notmatch $Pattern) {
    throw $Message
  }
}

function Assert-NotContains {
  param([string]$RelativePath, [string]$Pattern, [string]$Message)
  $path = Join-Path $RepoRoot $RelativePath
  $text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  if ($text -match $Pattern) {
    throw $Message
  }
}

function Assert-PowerShellParses {
  param([string]$RelativePath)
  $path = Join-Path $RepoRoot $RelativePath
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors -and $errors.Count -gt 0) {
    throw "PowerShell parse failed for ${RelativePath}: $($errors[0].Message)"
  }
}

Assert-File "index.html"
Assert-File "scripts/studio_bridge.ps1"
Assert-File "scripts/start_studio.ps1"

Assert-PowerShellParses "scripts/studio_bridge.ps1"
Assert-PowerShellParses "scripts/start_studio.ps1"

Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/health" -Message "Studio bridge missing health endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/run-pipeline" -Message "Studio bridge missing pipeline endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/project-summary" -Message "Studio bridge missing project summary endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/new-project" -Message "Studio bridge missing new project endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/save-book-request" -Message "Studio bridge missing book request save endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/save-episode" -Message "Studio bridge missing episode save endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/save-layout-plan" -Message "Studio bridge missing layout plan save endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/write-approval" -Message "Studio bridge missing approval write endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/export-final" -Message "Studio bridge missing guarded final export endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/approve-cleanup" -Message "Studio bridge missing cleanup approval endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "/api/cleanup-project" -Message "Studio bridge missing cleanup endpoint."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "new_project.ps1" -Message "Studio bridge must create projects through new_project.ps1."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "export_final.ps1" -Message "Studio bridge must use guarded export_final.ps1."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "cleanup_project.ps1" -Message "Studio bridge must use guarded cleanup_project.ps1."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "Save-LayoutPlan" -Message "Studio bridge missing layout plan writer."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "designDocs" -Message "Studio bridge missing design document summary."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "reports" -Message "Studio bridge missing report summary."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "quality" -Message "Studio bridge missing quality audit summary."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "lifecycle" -Message "Studio bridge missing lifecycle summary."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "Get-ChapterHeatmap" -Message "Studio bridge missing chapter heatmap calculation."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "chapterHeatmap" -Message "Studio bridge missing chapter heatmap summary."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "Get-BookRequestChecklist" -Message "Studio bridge missing book request checklist."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "bookRequestChecklist" -Message "Studio bridge missing checklist in project summary."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "Studio pipeline blocked: book request is incomplete" -Message "Studio bridge must block incomplete wizard requests before advanced phases."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "validPhases" -Message "Studio bridge must validate phase names."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "powershell @args" -Message "Studio bridge must invoke pipeline through an argument array."
Assert-Contains -RelativePath "scripts/studio_bridge.ps1" -Pattern "System.Net.Sockets.TcpListener" -Message "Studio bridge must use the portable TcpListener server."
Assert-NotContains -RelativePath "scripts/studio_bridge.ps1" -Pattern "HttpListener" -Message "Studio bridge must not depend on HttpListener."
Assert-Contains -RelativePath "scripts/start_studio.ps1" -Pattern "studio_bridge.ps1" -Message "Studio starter must launch the bridge."

Assert-Contains -RelativePath "index.html" -Pattern "KitHub Studio" -Message "Studio UI missing product shell."
Assert-Contains -RelativePath "index.html" -Pattern "showDirectoryPicker" -Message "Studio UI missing local project directory binding."
Assert-Contains -RelativePath "index.html" -Pattern "createWritable" -Message "Studio UI missing episode save support."
Assert-Contains -RelativePath "index.html" -Pattern "api/run-pipeline" -Message "Studio UI missing bridge pipeline call."
Assert-Contains -RelativePath "index.html" -Pattern "api/project-summary" -Message "Studio UI missing bridge project summary call."
Assert-Contains -RelativePath "index.html" -Pattern "api/new-project" -Message "Studio UI missing bridge new project call."
Assert-Contains -RelativePath "index.html" -Pattern "api/save-book-request" -Message "Studio UI missing book request save call."
Assert-Contains -RelativePath "index.html" -Pattern "api/save-episode" -Message "Studio UI missing bridge save episode call."
Assert-Contains -RelativePath "index.html" -Pattern "api/save-layout-plan" -Message "Studio UI missing bridge layout save call."
Assert-Contains -RelativePath "index.html" -Pattern "api/write-approval" -Message "Studio UI missing bridge write approval call."
Assert-Contains -RelativePath "index.html" -Pattern "api/export-final" -Message "Studio UI missing guarded final export call."
Assert-Contains -RelativePath "index.html" -Pattern "api/approve-cleanup" -Message "Studio UI missing cleanup approval call."
Assert-Contains -RelativePath "index.html" -Pattern "api/cleanup-project" -Message "Studio UI missing cleanup project call."
Assert-Contains -RelativePath "index.html" -Pattern "newProjectBtn" -Message "Studio UI missing new project button."
Assert-Contains -RelativePath "index.html" -Pattern "bookRequestInput" -Message "Studio UI missing book request input."
Assert-Contains -RelativePath "index.html" -Pattern "runLogOutput" -Message "Studio UI missing run log output."
Assert-Contains -RelativePath "index.html" -Pattern "setRunLog" -Message "Studio UI missing run log update helper."
Assert-Contains -RelativePath "index.html" -Pattern "copyRunLogBtn" -Message "Studio UI missing run log copy button."
Assert-Contains -RelativePath "index.html" -Pattern "renderSupportTab" -Message "Studio UI missing plan/revision tab renderer."
Assert-Contains -RelativePath "index.html" -Pattern "currentDesignDocs" -Message "Studio UI missing design document state."
Assert-Contains -RelativePath "index.html" -Pattern "currentReports" -Message "Studio UI missing report state."
Assert-Contains -RelativePath "index.html" -Pattern "renderQuality" -Message "Studio UI missing book health renderer."
Assert-Contains -RelativePath "index.html" -Pattern "renderLifecycle" -Message "Studio UI missing lifecycle renderer."
Assert-Contains -RelativePath "index.html" -Pattern "finalExportBtn" -Message "Studio UI missing guarded final export button."
Assert-Contains -RelativePath "index.html" -Pattern "cleanupProjectBtn" -Message "Studio UI missing cleanup button."
Assert-Contains -RelativePath "index.html" -Pattern "applyAndSaveTypography" -Message "Studio UI missing persistent typography save action."
Assert-Contains -RelativePath "index.html" -Pattern "agent-evidence" -Message "Studio UI missing visible agent evidence."
Assert-Contains -RelativePath "index.html" -Pattern "risk-chip" -Message "Studio UI missing compact chapter risk marker."
Assert-Contains -RelativePath "index.html" -Pattern "renderChapterAction" -Message "Studio UI missing chapter risk action renderer."
Assert-Contains -RelativePath "index.html" -Pattern "chapterAction" -Message "Studio UI missing compact chapter action status."
Assert-Contains -RelativePath "index.html" -Pattern "wizardType" -Message "Studio UI missing start wizard writing type field."
Assert-Contains -RelativePath "index.html" -Pattern "wizardPages" -Message "Studio UI missing start wizard page target field."
Assert-Contains -RelativePath "index.html" -Pattern "buildWizardRequestText" -Message "Studio UI missing wizard request builder."
Assert-Contains -RelativePath "index.html" -Pattern "saveWizardRequest" -Message "Studio UI missing wizard save action."
Assert-Contains -RelativePath "index.html" -Pattern "fromPhaseSelect" -Message "Studio UI missing from-phase selector."
Assert-Contains -RelativePath "index.html" -Pattern "toPhaseSelect" -Message "Studio UI missing to-phase selector."
Assert-Contains -RelativePath "index.html" -Pattern "refreshProject" -Message "Studio UI missing project refresh action."
Assert-Contains -RelativePath "index.html" -Pattern "approvalDefinitions" -Message "Studio UI missing approval gate definitions."
Assert-Contains -RelativePath "index.html" -Pattern "loadApprovals" -Message "Studio UI missing approval loading."
Assert-Contains -RelativePath "index.html" -Pattern "approveGate" -Message "Studio UI missing approval write action."
Assert-Contains -RelativePath "index.html" -Pattern "book-plan-approval.json" -Message "Studio UI missing book plan approval support."
Assert-Contains -RelativePath "index.html" -Pattern "accepted_targets" -Message "Studio UI must bind book-plan approval to accepted targets."
Assert-Contains -RelativePath "index.html" -Pattern "emptyManuscriptText" -Message "Studio UI must start from a safe empty manuscript state."
Assert-NotContains -RelativePath "index.html" -Pattern "Sis Altında|Pera Palas|Münevver|Dolmabahçe Duvarı|Pera Sisi" -Message "Studio UI must not ship with demo novel content."
Assert-Contains -RelativePath "README.md" -Pattern "KitHub Studio UI" -Message "README missing Studio UI section."
Assert-Contains -RelativePath "README.md" -Pattern "scripts/start_studio.ps1" -Message "README missing Studio start command."

Write-Host "[studio-ui-bridge-test] PASS"
