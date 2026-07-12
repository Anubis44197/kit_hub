param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"

function Write-Utf8BomText {
  param([string]$Path, [string]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($true))
}

function Write-Utf8BomJson {
  param([string]$Path, [object]$Value)
  Write-Utf8BomText -Path $Path -Value ($Value | ConvertTo-Json -Depth 30)
}

function Read-Utf8Json {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Invoke-CheckedPowerShell {
  param([string[]]$Arguments)
  $output = & powershell @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
}

function Assert-ManifestMatchesContract {
  param(
    [string]$ProjectRoot,
    [string]$Phase,
    [string]$ManifestPath
  )
  $contract = Read-Utf8Json -Path (Join-Path $ProjectRoot "runtime/phase-contracts/$Phase.json")
  $manifest = Read-Utf8Json -Path $ManifestPath
  foreach ($stateFile in @($contract.required_state_files | ForEach-Object { [string]$_ })) {
    if (@($manifest.loaded_state_files | ForEach-Object { [string]$_ }) -notcontains $stateFile) {
      throw "Agent compliance loaded_state_files omits phase-contract state '$stateFile' for phase '$Phase'."
    }
  }
  foreach ($ref in @($contract.required_references | ForEach-Object { [string]$_ })) {
    if (@($manifest.required_references | ForEach-Object { [string]$_ }) -notcontains $ref) {
      throw "Agent compliance required_references omits phase-contract reference '$ref' for phase '$Phase'."
    }
  }
}

$projectsRoot = Join-Path $RepoRoot ".tmp/agent-compliance-story-model-gate"
$projectRoot = Join-Path $projectsRoot "agent-compliance-model-test"

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", "Agent Compliance Model Test", "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null

  $request = "Kitap Adi: Uyku Saatinde Rıhtım. Tur: kısa roman. Hedef Uzunluk: 30 sayfa. Konu: Bir rıhtım bekçisi eski bir defter bulur. Karakter Sayisi: 3."
  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value $request

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "intake", "-ToPhase", "intake") | Out-Null

  $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
  $briefApproval = Read-Utf8Json -Path $briefApprovalPath
  $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
    writing_type = "novella"
    premise = "Bir rıhtım bekçisi eski bir defterle geçmişte saklanan bir suçu çözer."
    target_length = "30 sayfa"
    target_pages = "30"
    target_reader = "Yetiskin okur"
    genre = "gizem"
    character_policy = "3 ana karakter"
    setting_period = "Belirsiz liman kasabası"
    pov_tense = "Ucuncu tekil, gecmis zaman"
    style_tone = "Edebi ve sakin gerilim"
    boundaries = "Teknik etiket yok"
    publication_package = "A5 DOCX"
  }) -Force
  Write-Utf8BomJson -Path $briefApprovalPath -Value $briefApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "propose", "-ToPhase", "propose") | Out-Null
  $storyChoicePath = Join-Path $projectRoot "runtime/approvals/story-choice.json"
  $storyChoice = Read-Utf8Json -Path $storyChoicePath
  $storyChoice | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $storyChoice | Add-Member -NotePropertyName selected_option -NotePropertyValue 1 -Force
  Write-Utf8BomJson -Path $storyChoicePath -Value $storyChoice

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null

  Write-Utf8BomText -Path (Join-Path $projectRoot "episode/ep001.md") -Value "# Rıhtım Defteri`n`nBekçi defteri buldu ve olay başladı."
  Write-Utf8BomJson -Path (Join-Path $projectRoot "runtime/approvals/design-freeze.json") -Value ([ordered]@{ approved = $true; note = "Compliance gate test." })

  $blockedWithoutChiefEvidence = $false
  try {
    Invoke-CheckedPowerShell -Arguments @(
      "-ExecutionPolicy", "Bypass",
      "-File", (Join-Path $RepoRoot "scripts/ci/write_agent_compliance.ps1"),
      "-ProjectRoot", $projectRoot,
      "-Phase", "create",
      "-RunId", "RUN-COMPLIANCE-STORY-MODEL",
      "-RequiredAgents", "episode-creator",
      "-RequiredReferences", "skills/create/SKILL.md",
      "-LoadedStateFiles", "revision/_state/book-plan.json",
      "-OutputArtifacts", "episode/ep001.md",
      "-PhaseAuthority", "manual_ide_agent"
    ) | Out-Null
  }
  catch {
    if ($_.Exception.Message -match "chief-editor-orchestrator") {
      $blockedWithoutChiefEvidence = $true
    }
    else {
      throw
    }
  }
  if (-not $blockedWithoutChiefEvidence) {
    throw "Compliance writer accepted create phase without dedicated chief-editor-orchestrator evidence."
  }

  $chiefReportRel = "runtime/agent-compliance/chief-editor-orchestrator_report_create.md"
  $chiefVerdictRel = "runtime/agent-compliance/chief-editor-orchestrator_verdict_create.json"
  $secondaryArtifactRel = "revision/_workspace/secondary_create_artifact.json"
  Write-Utf8BomText -Path (Join-Path $projectRoot $chiefReportRel) -Value "# Chief Editor Orchestrator`n`nverdict: PASS`n"
  Write-Utf8BomJson -Path (Join-Path $projectRoot $secondaryArtifactRel) -Value ([ordered]@{ note = "Must be covered by chief editor checked_output_artifacts." })
  Write-Utf8BomJson -Path (Join-Path $projectRoot $chiefVerdictRel) -Value ([ordered]@{
    run_id = "RUN-COMPLIANCE-STORY-MODEL"
    phase = "create"
    agent = "chief-editor-orchestrator"
    verdict = "PASS"
    checked_output_artifacts = @("episode/ep001.md")
  })

  Write-Utf8BomJson -Path (Join-Path $projectRoot $chiefVerdictRel) -Value ([ordered]@{
    run_id = "RUN-COMPLIANCE-STORY-MODEL"
    phase = "create"
    agent = "chief-editor-orchestrator"
    verdict = "BLOCKED"
    checked_output_artifacts = @("episode/ep001.md")
  })
  $blockedChiefVerdict = $false
  try {
    Invoke-CheckedPowerShell -Arguments @(
      "-ExecutionPolicy", "Bypass",
      "-File", (Join-Path $RepoRoot "scripts/ci/write_agent_compliance.ps1"),
      "-ProjectRoot", $projectRoot,
      "-Phase", "create",
      "-RunId", "RUN-COMPLIANCE-STORY-MODEL",
      "-RequiredAgents", "episode-creator",
      "-RequiredReferences", "skills/create/SKILL.md",
      "-LoadedStateFiles", "revision/_state/book-plan.json",
      "-OutputArtifacts", "episode/ep001.md,$chiefReportRel,$chiefVerdictRel",
      "-AgentEvidence", "chief-editor-orchestrator=$chiefReportRel|$chiefVerdictRel",
      "-PhaseAuthority", "manual_ide_agent"
    ) | Out-Null
  }
  catch {
    if ($_.Exception.Message -match "Chief editor verdict blocks") {
      $blockedChiefVerdict = $true
    }
    else {
      throw
    }
  }
  if (-not $blockedChiefVerdict) {
    throw "Compliance writer accepted a BLOCKED chief-editor-orchestrator verdict."
  }

  Write-Utf8BomJson -Path (Join-Path $projectRoot $chiefVerdictRel) -Value ([ordered]@{
    run_id = "RUN-COMPLIANCE-STORY-MODEL"
    phase = "create"
    agent = "chief-editor-orchestrator"
    verdict = "PASS"
    checked_output_artifacts = @("episode/ep001.md")
  })
  $blockedUncheckedArtifact = $false
  try {
    Invoke-CheckedPowerShell -Arguments @(
      "-ExecutionPolicy", "Bypass",
      "-File", (Join-Path $RepoRoot "scripts/ci/write_agent_compliance.ps1"),
      "-ProjectRoot", $projectRoot,
      "-Phase", "create",
      "-RunId", "RUN-COMPLIANCE-STORY-MODEL",
      "-RequiredAgents", "episode-creator",
      "-RequiredReferences", "skills/create/SKILL.md",
      "-LoadedStateFiles", "revision/_state/book-plan.json",
      "-OutputArtifacts", "episode/ep001.md,$secondaryArtifactRel,$chiefReportRel,$chiefVerdictRel",
      "-AgentEvidence", "chief-editor-orchestrator=$chiefReportRel|$chiefVerdictRel",
      "-PhaseAuthority", "manual_ide_agent"
    ) | Out-Null
  }
  catch {
    if ($_.Exception.Message -match "did not check output artifacts") {
      $blockedUncheckedArtifact = $true
    }
    else {
      throw
    }
  }
  if (-not $blockedUncheckedArtifact) {
    throw "Compliance writer accepted an unchecked phase output artifact."
  }

  Write-Utf8BomJson -Path (Join-Path $projectRoot $chiefVerdictRel) -Value ([ordered]@{
    run_id = "RUN-COMPLIANCE-STORY-MODEL"
    phase = "create"
    agent = "chief-editor-orchestrator"
    verdict = "PASS"
    checked_output_artifacts = @("episode/ep001.md", $secondaryArtifactRel)
  })

  Invoke-CheckedPowerShell -Arguments @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $RepoRoot "scripts/ci/write_agent_compliance.ps1"),
    "-ProjectRoot", $projectRoot,
    "-Phase", "create",
    "-RunId", "RUN-COMPLIANCE-STORY-MODEL",
    "-RequiredAgents", "episode-creator",
    "-RequiredReferences", "skills/create/SKILL.md",
    "-LoadedStateFiles", "revision/_state/book-plan.json",
    "-OutputArtifacts", "episode/ep001.md,$secondaryArtifactRel,$chiefReportRel,$chiefVerdictRel",
    "-AgentEvidence", "chief-editor-orchestrator=$chiefReportRel|$chiefVerdictRel",
    "-PhaseAuthority", "manual_ide_agent"
  ) | Out-Null

  $manifestPath = Join-Path $projectRoot "runtime/agent-compliance/create.json"
  $manifest = Read-Utf8Json -Path $manifestPath
  if (@($manifest.loaded_state_files | ForEach-Object { [string]$_ }) -notcontains "revision/_state/open-source-story-model.json") {
    throw "Compliance writer did not merge open-source-story-model.json from phase contract."
  }
  Assert-ManifestMatchesContract -ProjectRoot $projectRoot -Phase "create" -ManifestPath $manifestPath

  $badManifest = $manifest | ConvertTo-Json -Depth 30 | ConvertFrom-Json
  $badManifest.loaded_state_files = @($badManifest.loaded_state_files | Where-Object { [string]$_ -ne "revision/_state/open-source-story-model.json" })
  $badPath = Join-Path $projectRoot "runtime/agent-compliance/create.bad.json"
  Write-Utf8BomJson -Path $badPath -Value $badManifest
  $failed = $false
  try {
    Assert-ManifestMatchesContract -ProjectRoot $projectRoot -Phase "create" -ManifestPath $badPath
  }
  catch {
    if ($_.Exception.Message -match "open-source-story-model\.json") {
      $failed = $true
    }
    else {
      throw
    }
  }
  if (-not $failed) {
    throw "Bad manifest without open-source-story-model.json was not rejected."
  }

  Write-Host "[agent-compliance-story-model-gate] PASS"
}
finally {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
