param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

$RepoRoot = [System.IO.Path]::GetFullPath($RepoRoot)
$marker = Join-Path $RepoRoot ".kithub-project.json"
if (Test-Path -LiteralPath $marker -PathType Leaf) {
  throw "App root cleanliness test must run against the kit_hub application repository, not a book project root."
}

$forbiddenDirectories = @(
  "episode",
  "revision",
  "design",
  "_workspace"
)

$violations = New-Object System.Collections.Generic.List[string]
foreach ($rel in $forbiddenDirectories) {
  $path = Join-Path $RepoRoot $rel
  if (Test-Path -LiteralPath $path -PathType Container) {
    $violations.Add($rel)
  }
}

$testRuns = @(Get-ChildItem -LiteralPath $RepoRoot -Directory -Force -Filter "test-run-*" -ErrorAction SilentlyContinue)
foreach ($dir in $testRuns) {
  $violations.Add($dir.Name)
}

$rootDocx = @(Get-ChildItem -LiteralPath $RepoRoot -File -Force -Filter "*.docx" -ErrorAction SilentlyContinue)
foreach ($file in $rootDocx) {
  $violations.Add($file.Name)
}

if ($violations.Count -gt 0) {
  throw "Application root is not clean. Move or remove book/test artifacts from app root: $($violations -join ', ')"
}

Write-Host "[app-root-cleanliness-test] PASS"
