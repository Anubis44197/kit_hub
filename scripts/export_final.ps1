param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$DestinationDirectory = ([Environment]::GetFolderPath("Desktop")),
  [ValidateSet("docx","pdf","epub","package")][string]$OutputProfile = "docx",
  [switch]$RequireExportApproval
)

$ErrorActionPreference = "Stop"

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$DestinationDirectory = [System.IO.Path]::GetFullPath($DestinationDirectory)
$projectRootPrefix = $ProjectRoot.TrimEnd("\") + "\"
$destinationPrefix = $DestinationDirectory.TrimEnd("\") + "\"
if ($destinationPrefix.StartsWith($projectRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Final export destination must be outside the KitHub project root. Choose Desktop, Documents, or another external folder."
}
$markerPath = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
  throw "Final export must run inside a KitHub project created by scripts/new_project.ps1. Missing .kithub-project.json."
}
if ($RequireExportApproval) {
  $approvalPath = Join-Path $ProjectRoot "runtime/approvals/export-approval.json"
  if (-not (Test-Path -LiteralPath $approvalPath -PathType Leaf)) {
    throw "Missing export approval: runtime/approvals/export-approval.json"
  }
  $approval = Read-Utf8 -Path $approvalPath | ConvertFrom-Json
  if ($approval.approved -ne $true) {
    throw "Export approval is not approved."
  }
}

$exportDir = Join-Path $ProjectRoot "revision/export"
if (-not (Test-Path -LiteralPath $exportDir -PathType Container)) {
  throw "No export directory found: revision/export"
}
$extensions = switch ($OutputProfile) {
  "pdf" { @(".pdf") }
  "epub" { @(".epub") }
  "package" { @(".docx", ".pdf", ".epub") }
  default { @(".docx") }
}
$sourceFiles = @()
foreach ($extension in $extensions) {
  $candidate = @(Get-ChildItem -LiteralPath $exportDir -Filter "*$extension" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
  if ($candidate.Count -lt 1) {
    throw "No $($extension.TrimStart('.').ToUpperInvariant()) export found under revision/export for profile '$OutputProfile'."
  }
  $sourceFiles += $candidate[0]
}
if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
}

$exportedPaths = @()
$collisionRenamed = $false
foreach ($sourceFile in $sourceFiles) {
  $baseName = [System.IO.Path]::GetFileNameWithoutExtension($sourceFile.Name)
  $extension = [System.IO.Path]::GetExtension($sourceFile.Name)
  $destPath = Join-Path $DestinationDirectory $sourceFile.Name
  $collisionIndex = 0
  while (Test-Path -LiteralPath $destPath -PathType Leaf) {
    $collisionIndex++
    $destPath = Join-Path $DestinationDirectory ("{0} ({1}){2}" -f $baseName, $collisionIndex, $extension)
  }
  Copy-Item -LiteralPath $sourceFile.FullName -Destination $destPath
  $exportedPaths += $destPath
  if ($collisionIndex -gt 0) { $collisionRenamed = $true }
}
$destPath = [string]$exportedPaths[0]
$sourceDocx = @($sourceFiles | Where-Object Extension -eq ".docx" | Select-Object -First 1)

$manifest = [ordered]@{
  schema_version = "1.0.0"
  project_root = $ProjectRoot
  output_profile = $OutputProfile
  source_docx = if ($sourceDocx.Count) { $sourceDocx[0].FullName } else { "" }
  source_files = [object[]]@($sourceFiles | ForEach-Object { $_.FullName })
  final_output_path = $destPath
  final_output_paths = [object[]]$exportedPaths
  collision_renamed = $collisionRenamed
  exported_at = (Get-Date).ToString("o")
  cleanup_note = "Final output was copied outside the working project. The user must read/review the book and explicitly approve cleanup before working files are removed."
}
Write-Utf8Bom -Path (Join-Path $ProjectRoot "runtime/final-export-manifest.json") -Content ($manifest | ConvertTo-Json -Depth 10)

$cleanupApprovalPath = Join-Path $ProjectRoot "runtime/approvals/cleanup-approval.json"
$cleanupApproval = [ordered]@{
  approved = $false
  title = "Cleanup Approval"
  approved_by = ""
  approved_at = ""
  final_output_preserved = $true
  final_output_path = $destPath
  final_output_paths = [object[]]$exportedPaths
  collision_renamed = $collisionRenamed
  user_confirmed_book_finished = $false
  user_must_confirm_book_finished = $true
  note = "Do not set approved=true until the user has read/reviewed the final book and explicitly says the book is finished and working files may be removed."
}
Write-Utf8Bom -Path $cleanupApprovalPath -Content ($cleanupApproval | ConvertTo-Json -Depth 10)

$statusPath = Join-Path $ProjectRoot "runtime/project-status.json"
if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
  $status = Read-Utf8 -Path $statusPath | ConvertFrom-Json
}
else {
  $status = [pscustomobject]@{ schema_version = "1.0.0"; project_name = ""; status = "draft"; cleanup_allowed = $false }
}
$status | Add-Member -NotePropertyName status -NotePropertyValue "exported_waiting_user_review" -Force
$status | Add-Member -NotePropertyName final_output_path -NotePropertyValue $destPath -Force
$status | Add-Member -NotePropertyName final_output_paths -NotePropertyValue ([object[]]$exportedPaths) -Force
$status | Add-Member -NotePropertyName exported_at -NotePropertyValue (Get-Date).ToString("o") -Force
$status | Add-Member -NotePropertyName cleanup_allowed -NotePropertyValue $false -Force
$status | Add-Member -NotePropertyName next_user_decision -NotePropertyValue "Read/review the exported book. If revisions are needed, continue rewrite/export. If the book is truly finished, approve runtime/approvals/cleanup-approval.json and run scripts/cleanup_project.ps1." -Force
Write-Utf8Bom -Path $statusPath -Content ($status | ConvertTo-Json -Depth 10)

foreach ($exportedPath in $exportedPaths) { Write-Host "[export-final] copied: $exportedPath" }
Write-Host "[export-final] waiting for user review. Cleanup remains blocked until cleanup-approval.json approved=true after the user says the book is finished."
