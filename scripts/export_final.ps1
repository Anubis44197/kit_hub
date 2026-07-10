param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string]$DestinationDirectory = ([Environment]::GetFolderPath("Desktop")),
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
$docx = @(Get-ChildItem -LiteralPath $exportDir -Filter "*.docx" -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1)
if ($docx.Count -lt 1) {
  throw "No DOCX export found under revision/export."
}
if (-not (Test-Path -LiteralPath $DestinationDirectory -PathType Container)) {
  New-Item -ItemType Directory -Path $DestinationDirectory | Out-Null
}

$destPath = Join-Path $DestinationDirectory $docx[0].Name
Copy-Item -LiteralPath $docx[0].FullName -Destination $destPath -Force

$manifest = [ordered]@{
  schema_version = "1.0.0"
  project_root = $ProjectRoot
  source_docx = $docx[0].FullName
  final_output_path = $destPath
  exported_at = (Get-Date).ToString("o")
  cleanup_note = "Final output was copied outside the working project. Cleanup still requires cleanup-approval.json."
}
Write-Utf8Bom -Path (Join-Path $ProjectRoot "runtime/final-export-manifest.json") -Content ($manifest | ConvertTo-Json -Depth 10)

$statusPath = Join-Path $ProjectRoot "runtime/project-status.json"
if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
  $status = Read-Utf8 -Path $statusPath | ConvertFrom-Json
}
else {
  $status = [pscustomobject]@{ schema_version = "1.0.0"; project_name = ""; status = "draft"; cleanup_allowed = $false }
}
$status | Add-Member -NotePropertyName status -NotePropertyValue "exported" -Force
$status | Add-Member -NotePropertyName final_output_path -NotePropertyValue $destPath -Force
$status | Add-Member -NotePropertyName exported_at -NotePropertyValue (Get-Date).ToString("o") -Force
Write-Utf8Bom -Path $statusPath -Content ($status | ConvertTo-Json -Depth 10)

Write-Host "[export-final] copied: $destPath"
