param(
  [string]$ProjectRoot = (Get-Location).Path,
  [string[]]$RequiredPhases = @("create","polish","rewrite","export")
)

$ErrorActionPreference = "Stop"

function Ensure-File {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Missing required file: $Path"
  }
}

function Ensure-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw $Message
  }
}

$pointerPath = Join-Path $ProjectRoot "runtime\current-run.json"
Ensure-File $pointerPath
$pointer = Get-Content -LiteralPath $pointerPath -Raw | ConvertFrom-Json

Ensure-True -Condition ($pointer.PSObject.Properties.Name -contains "run_id") -Message "current-run.json missing run_id"
Ensure-True -Condition ($pointer.PSObject.Properties.Name -contains "summary_path") -Message "current-run.json missing summary_path"

$summaryPath = Join-Path $ProjectRoot $pointer.summary_path
Ensure-File $summaryPath
$summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json

Ensure-True -Condition ($summary.status -eq "completed") -Message "Run is not completed. status=$($summary.status)"
Ensure-True -Condition ($summary.PSObject.Properties.Name -contains "steps") -Message "run-summary missing steps"
Ensure-True -Condition ($summary.steps.Count -gt 0) -Message "run-summary has no steps"

foreach ($phase in $RequiredPhases) {
  $phaseStep = $summary.steps | Where-Object { $_.phase -eq $phase } | Select-Object -Last 1
  Ensure-True -Condition ($null -ne $phaseStep) -Message "Required phase missing in run summary: $phase"
  Ensure-True -Condition ($phaseStep.status -eq "completed") -Message "Required phase not completed: $phase"
  Ensure-True -Condition ($phaseStep.PSObject.Properties.Name -contains "evidence_path") -Message "Phase step missing evidence_path: $phase"

  $evidencePath = Join-Path $ProjectRoot $phaseStep.evidence_path
  Ensure-File $evidencePath
  $evidence = Get-Content -LiteralPath $evidencePath -Raw | ConvertFrom-Json

  Ensure-True -Condition ($evidence.status -eq "completed") -Message "Phase evidence status is not completed: $phase"
  Ensure-True -Condition ($evidence.artifact_gate_passed -eq $true) -Message "artifact_gate_passed is false: $phase"
  Ensure-True -Condition ($evidence.execution_claim_mode -eq "executed") -Message "execution_claim_mode is not executed: $phase"
  Ensure-True -Condition ($evidence.output_artifacts.Count -gt 0) -Message "No output_artifacts recorded for phase: $phase"

  foreach ($artifact in $evidence.output_artifacts) {
    $artifactPath = Join-Path $ProjectRoot $artifact
    Ensure-File $artifactPath
  }
}

Write-Host "[verify-real-run] PASS"
Write-Host "[verify-real-run] run_id=$($pointer.run_id)"
Write-Host "[verify-real-run] summary=$($pointer.summary_path)"

