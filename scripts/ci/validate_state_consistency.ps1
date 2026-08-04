param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path $ProjectRoot).Path
$stateRoot = Join-Path $ProjectRoot "revision/_state"
if (-not (Test-Path -LiteralPath $stateRoot -PathType Container)) { throw "Missing state root: $stateRoot" }
$files = @(Get-ChildItem -LiteralPath $stateRoot -Filter "*.json" -File)
$runIds = @{}
$issues = @()
foreach ($file in $files) {
  try { $obj = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json } catch { $issues += "$($file.Name): invalid JSON"; continue }
  if ($obj.PSObject.Properties.Name -contains "run_id" -and [string]$obj.run_id) {
    $runIds[[string]$obj.run_id] = @($runIds[[string]$obj.run_id]) + $file.Name
  }
}
if ($runIds.Keys.Count -gt 1) {
  $issues += "State run_id mismatch: " + (($runIds.Keys | Sort-Object) -join ", ")
}
$episodeTexts = @(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "episode") -Filter "*.md" -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw })
$stateTexts = @($files | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw })
$variants = @("Koparölmüş","Koparılmış")
$present = @($variants | Where-Object { (($episodeTexts + $stateTexts) -join [Environment]::NewLine) -match [regex]::Escape($_) })
if ($present.Count -gt 1) { $issues += "Inconsistent event wording variants: $($present -join ', ')" }
$report = [ordered]@{ schema_version = "1.0.0"; checked_at = (Get-Date).ToString("o"); project_root = $ProjectRoot; state_files = $files.Count; run_ids = @($runIds.Keys); issues = @($issues); verdict = if ($issues.Count -eq 0) { "PASS" } else { "BLOCKED" } }
$reportPath = Join-Path $ProjectRoot "runtime/state-consistency-report.json"
[IO.File]::WriteAllText($reportPath, ($report | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($true))
if ($issues.Count -gt 0) { Write-Error ($issues -join "; "); exit 1 }
Write-Host "[state-consistency] PASS"
