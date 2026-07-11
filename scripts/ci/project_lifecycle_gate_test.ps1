param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8Json {
  param(
    [string]$Path,
    [object]$Value
  )
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
}

function Write-Utf8Text {
  param(
    [string]$Path,
    [string]$Value
  )
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($false))
}

function Assert-ThrowsLike {
  param(
    [scriptblock]$Action,
    [string]$Pattern,
    [string]$Label
  )
  try {
    & $Action
  }
  catch {
    if ($_.Exception.Message -match $Pattern) {
      Write-Host "[project-lifecycle-test] PASS blocked: $Label"
      return
    }
    throw "Unexpected error for ${Label}: $($_.Exception.Message)"
  }
  throw "Expected failure did not occur: $Label"
}

function Invoke-CheckedPowerShell {
  param([string[]]$Arguments)
  $output = & powershell @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
}

$testRoot = Join-Path $RepoRoot (".tmp/project-lifecycle-gate-test-" + [guid]::NewGuid().ToString("N"))
$project = Join-Path $testRoot "Project"
$externalOutput = Join-Path $testRoot "FinalOutput"

try {
  Write-Utf8Json -Path (Join-Path $project ".kithub-project.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    project_name = "Lifecycle Gate Test"
  })
  Write-Utf8Json -Path (Join-Path $project "runtime/approvals/export-approval.json") -Value ([ordered]@{
    approved = $true
    approved_by = "ci"
  })
  Write-Utf8Json -Path (Join-Path $project "runtime/approvals/cleanup-approval.json") -Value ([ordered]@{
    approved = $false
    final_output_preserved = $false
  })
  Write-Utf8Text -Path (Join-Path $project "revision/export/Lifecycle.docx") -Value "fake docx for lifecycle gate"
  Write-Utf8Text -Path (Join-Path $project "episode/ep001.md") -Value "# Bolum"
  Write-Utf8Text -Path (Join-Path $project "design/01_concept.md") -Value "# Concept"
  Write-Utf8Text -Path (Join-Path $project "revision/_workspace/check.md") -Value "workspace"

  Assert-ThrowsLike `
    -Label "final export into project root" `
    -Pattern "Final export destination must be outside" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/export_final.ps1"), "-ProjectRoot", $project, "-DestinationDirectory", (Join-Path $project "exports"), "-RequireExportApproval")
    }

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/export_final.ps1"), "-ProjectRoot", $project, "-DestinationDirectory", $externalOutput, "-RequireExportApproval") | Out-Null
  $finalPath = Join-Path $externalOutput "Lifecycle.docx"
  if (-not (Test-Path -LiteralPath $finalPath -PathType Leaf)) {
    throw "Expected final DOCX outside project root was not created."
  }

  Assert-ThrowsLike `
    -Label "cleanup without explicit user approval" `
    -Pattern "approved must be true" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/cleanup_project.ps1"), "-ProjectRoot", $project)
    }

  Write-Utf8Json -Path (Join-Path $project "runtime/approvals/cleanup-approval.json") -Value ([ordered]@{
    approved = $true
    final_output_preserved = $false
  })
  Assert-ThrowsLike `
    -Label "cleanup before final output preservation confirmation" `
    -Pattern "final_output_preserved must be true" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/cleanup_project.ps1"), "-ProjectRoot", $project)
    }

  Write-Utf8Json -Path (Join-Path $project "runtime/approvals/cleanup-approval.json") -Value ([ordered]@{
    approved = $true
    final_output_preserved = $true
  })
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/cleanup_project.ps1"), "-ProjectRoot", $project) | Out-Null

  foreach ($removedPath in @("episode", "revision", "design", "runtime/approvals")) {
    if (Test-Path -LiteralPath (Join-Path $project $removedPath)) {
      throw "Cleanup did not remove working path: $removedPath"
    }
  }
  if (-not (Test-Path -LiteralPath $finalPath -PathType Leaf)) {
    throw "Cleanup removed or lost the external final DOCX."
  }
  $statusPath = Join-Path $project "runtime/project-status.json"
  if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
    throw "Cleanup did not write project-status.json."
  }
  Write-Host "[project-lifecycle-test] PASS accepted: external final preserved and working files cleaned"
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
