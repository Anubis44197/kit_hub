param(
  [string]$ProjectRoot = (Get-Location).Path
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

function Assert-InProjectRoot {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd("\") + "\"
  $targetFull = [System.IO.Path]::GetFullPath($Path)
  if (-not ($targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "Refusing to clean path outside project root: $targetFull"
  }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
  throw "Cleanup must run inside a KitHub project. Missing .kithub-project.json."
}
$approvalPath = Join-Path $ProjectRoot "runtime/approvals/cleanup-approval.json"
if (-not (Test-Path -LiteralPath $approvalPath -PathType Leaf)) {
  throw "Missing cleanup approval: runtime/approvals/cleanup-approval.json"
}
$approval = Read-Utf8 -Path $approvalPath | ConvertFrom-Json
if ($approval.approved -ne $true) {
  throw "Cleanup blocked: cleanup-approval.json approved must be true."
}
if ($approval.final_output_preserved -ne $true) {
  throw "Cleanup blocked: cleanup-approval.json final_output_preserved must be true."
}

$finalManifestPath = Join-Path $ProjectRoot "runtime/final-export-manifest.json"
if (-not (Test-Path -LiteralPath $finalManifestPath -PathType Leaf)) {
  throw "Cleanup blocked: runtime/final-export-manifest.json is missing. Run scripts/export_final.ps1 first."
}
$finalManifest = Read-Utf8 -Path $finalManifestPath | ConvertFrom-Json
if (-not ($finalManifest.PSObject.Properties.Name -contains "final_output_path") -or -not (Test-Path -LiteralPath ([string]$finalManifest.final_output_path) -PathType Leaf)) {
  throw "Cleanup blocked: final output file is missing."
}
$projectRootPrefix = $ProjectRoot.TrimEnd("\") + "\"
$finalOutputFull = [System.IO.Path]::GetFullPath([string]$finalManifest.final_output_path)
if ($finalOutputFull.StartsWith($projectRootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
  throw "Cleanup blocked: final output must be outside the KitHub project root before working files are removed."
}

$targets = @(
  "episode",
  "revision",
  "design",
  "_workspace",
  "runtime/runs",
  "runtime/current-run.json",
  "runtime/agent-compliance",
  "runtime/approvals",
  "runtime/book-request.md",
  "runtime/book-brief.json",
  "runtime/book-dna.json",
  "runtime/layout-profile.json",
  "novel-config.md"
)

$removed = @()
foreach ($rel in $targets) {
  $target = Join-Path $ProjectRoot $rel
  if (-not (Test-Path -LiteralPath $target)) { continue }
  Assert-InProjectRoot -Root $ProjectRoot -Path $target
  Remove-Item -LiteralPath $target -Recurse -Force
  $removed += $rel
}

$statusPath = Join-Path $ProjectRoot "runtime/project-status.json"
$status = [ordered]@{
  schema_version = "1.0.0"
  status = "cleaned"
  final_output_path = [string]$finalManifest.final_output_path
  cleanup_completed_at = (Get-Date).ToString("o")
  removed_paths = $removed
}
Write-Utf8Bom -Path $statusPath -Content ($status | ConvertTo-Json -Depth 10)
Write-Host "[cleanup] removed working files from: $ProjectRoot"
