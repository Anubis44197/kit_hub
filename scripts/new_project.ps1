param(
  [Parameter(Mandatory = $true)]
  [string]$Name,
  [string]$ProjectsRoot = (Join-Path ([Environment]::GetFolderPath("MyDocuments")) "KitHubProjects"),
  [switch]$Force
)

$ErrorActionPreference = "Stop"

function Get-Slug {
  param([string]$Value)
  $slug = $Value.ToLowerInvariant()
  $slug = $slug -replace "[^\p{L}\p{Nd}]+", "-"
  $slug = $slug.Trim("-")
  if (-not $slug) { $slug = "kitap-projesi" }
  return $slug
}

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceRoot = Split-Path -Parent $scriptRoot
$sourceRoot = [System.IO.Path]::GetFullPath($sourceRoot)
$ProjectsRoot = [System.IO.Path]::GetFullPath($ProjectsRoot)
Ensure-Dir $ProjectsRoot

$slug = Get-Slug -Value $Name
$projectRoot = Join-Path $ProjectsRoot $slug
if ((Test-Path -LiteralPath $projectRoot) -and -not $Force) {
  throw "Project already exists: $projectRoot. Choose another name or pass -Force."
}
if (Test-Path -LiteralPath $projectRoot) {
  Remove-Item -LiteralPath $projectRoot -Recurse -Force
}
Ensure-Dir $projectRoot

$excluded = @(
  ".git",
  ".git/*",
  ".tmp",
  ".tmp/*",
  "test-run-*",
  "test-run-*/*",
  "_workspace",
  "_workspace/*",
  "design",
  "design/*",
  "episode",
  "episode/*",
  "revision",
  "revision/*",
  "runtime/runs",
  "runtime/runs/*",
  "runtime/current-run.json",
  "runtime/approvals",
  "runtime/approvals/*",
  "runtime/agent-compliance",
  "runtime/agent-compliance/*",
  "novel-config.md",
  "*.docx",
  "*_proposal.md"
)

function Test-Excluded {
  param([string]$Relative)
  $normalized = $Relative -replace "\\", "/"
  foreach ($pattern in $excluded) {
    if ($normalized -like $pattern) { return $true }
    if ($pattern.EndsWith("/*") -and $normalized.StartsWith($pattern.TrimEnd("*"))) { return $true }
  }
  return $false
}

$sourceFiles = Get-ChildItem -LiteralPath $sourceRoot -Force -Recurse -File
foreach ($file in $sourceFiles) {
  $relative = $file.FullName.Substring($sourceRoot.Length).TrimStart("\")
  if (Test-Excluded -Relative $relative) { continue }
  $target = Join-Path $projectRoot $relative
  $targetDir = Split-Path -Parent $target
  Ensure-Dir $targetDir
  Copy-Item -LiteralPath $file.FullName -Destination $target -Force
}

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot "scripts/install.ps1") -ProjectRoot $projectRoot | Out-Null

$marker = [ordered]@{
  schema_version = "1.0.0"
  project_name = $Name
  project_slug = $slug
  project_root = $projectRoot
  source_engine_root = $sourceRoot
  created_at = (Get-Date).ToString("o")
  status = "draft"
  policy = "Working manuscript files live in this project root, not in the kit_hub application repository. Cleanup requires explicit user approval."
}
Write-Utf8Bom -Path (Join-Path $projectRoot ".kithub-project.json") -Content ($marker | ConvertTo-Json -Depth 10)

$status = [ordered]@{
  schema_version = "1.0.0"
  project_name = $Name
  status = "draft"
  final_output_path = ""
  cleanup_allowed = $false
  cleanup_completed_at = ""
  notes = @("Do not clean working files until the user explicitly approves cleanup after reading/export.")
}
Write-Utf8Bom -Path (Join-Path $projectRoot "runtime/project-status.json") -Content ($status | ConvertTo-Json -Depth 10)

Write-Host "[new-project] created: $projectRoot"
