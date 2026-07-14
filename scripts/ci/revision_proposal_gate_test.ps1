param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8Json {
  param([string]$Path, [object]$Value)
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($true))
}

function Write-Utf8Text {
  param([string]$Path, [string]$Value)
  [System.IO.Directory]::CreateDirectory((Split-Path -Parent $Path)) | Out-Null
  [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($true))
}

function Invoke-CheckedPowerShell {
  param([string[]]$Arguments)
  $output = & powershell @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
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
      Write-Host "[revision-proposal-gate-test] PASS blocked: $Label"
      return
    }
    throw "Unexpected error for ${Label}: $($_.Exception.Message)"
  }
  throw "Expected failure did not occur: $Label"
}

$testRoot = Join-Path $RepoRoot (".tmp/revision-proposal-gate-test-" + [guid]::NewGuid().ToString("N"))
$project = Join-Path $testRoot "Project"

try {
  Write-Utf8Json -Path (Join-Path $project ".kithub-project.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    project_name = "Revision Proposal Gate Test"
  })
  Write-Utf8Text -Path (Join-Path $project "episode/ep001.md") -Value "# Bolum Bir`n`nBu cok kisa bir bolumdur. EP001 etiketi okuyucuya sizar."

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/revision_proposals.ps1"), "-ProjectRoot", $project) | Out-Null

  foreach ($required in @("revision/_workspace/draft-v1-lock.json", "revision/_workspace/revision-proposals.json", "revision/_workspace/revision-proposals.md")) {
    if (-not (Test-Path -LiteralPath (Join-Path $project $required) -PathType Leaf)) {
      throw "Missing revision proposal artifact: $required"
    }
  }

  $proposalSet = Get-Content -LiteralPath (Join-Path $project "revision/_workspace/revision-proposals.json") -Raw | ConvertFrom-Json
  $firstProposal = @($proposalSet.proposals | Where-Object { [string]$_.id -eq "REV-001" } | Select-Object -First 1)[0]
  if (-not $firstProposal) {
    throw "Expected REV-001 proposal was not generated."
  }

  Assert-ThrowsLike `
    -Label "apply without revision proposal approval" `
    -Pattern "revision-proposals-approval\.json|approved_proposal_ids" `
    -Action {
      Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/apply_revision.ps1"), "-ProjectRoot", $project, "-ProposalId", "REV-001")
    }

  Write-Utf8Text -Path (Join-Path $project "revision/_workspace/proposed/REV-001-ep001.md") -Value "# Bolum Bir`n`nOnayli revizyon metni teknik etiket olmadan bu bolumu yeniler."
  Write-Utf8Json -Path (Join-Path $project "runtime/approvals/revision-proposals-approval.json") -Value ([ordered]@{
    approved = $true
    approved_by = "ci"
    approved_proposal_ids = @("REV-001")
  })

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/apply_revision.ps1"), "-ProjectRoot", $project, "-ProposalId", "REV-001") | Out-Null
  $updatedText = Get-Content -LiteralPath (Join-Path $project "episode/ep001.md") -Raw
  if ($updatedText -notmatch "Onayli revizyon") {
    throw "Approved revision was not applied to episode/ep001.md."
  }
  if (-not (Test-Path -LiteralPath (Join-Path $project "revision/_workspace/applied") -PathType Container)) {
    throw "Revision apply did not leave backup/audit directory."
  }

  Write-Host "[revision-proposal-gate-test] PASS"
}
finally {
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
