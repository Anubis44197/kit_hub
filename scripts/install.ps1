param(
  [string]$ProjectRoot = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateSource = Join-Path (Split-Path -Parent $scriptRoot) "runtime/runner-config.template.json"

$runtimeDir = Join-Path $ProjectRoot "runtime"
$runsDir = Join-Path $runtimeDir "runs"
$approvalsDir = Join-Path $runtimeDir "approvals"
$statusPath = Join-Path $runtimeDir "project-status.json"
$templatePath = Join-Path $runtimeDir "runner-config.template.json"
$configPath = Join-Path $runtimeDir "runner-config.json"

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

function ConvertTo-HashtableDeep {
  param([object]$Value)

  if ($null -eq $Value) {
    return $null
  }

  if ($Value -is [System.Collections.IDictionary]) {
    $out = @{}
    foreach ($k in $Value.Keys) {
      $out[$k] = ConvertTo-HashtableDeep -Value $Value[$k]
    }
    return $out
  }

  if ($Value -is [System.Management.Automation.PSCustomObject]) {
    $out = @{}
    foreach ($p in $Value.PSObject.Properties) {
      $out[$p.Name] = ConvertTo-HashtableDeep -Value $p.Value
    }
    return $out
  }

  if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
    $list = New-Object System.Collections.ArrayList
    foreach ($item in $Value) {
      [void]$list.Add((ConvertTo-HashtableDeep -Value $item))
    }
    return $list
  }

  return $Value
}

function Merge-ConfigDefaults {
  param(
    [hashtable]$BaseDefaults,
    [hashtable]$CurrentConfig
  )

  $merged = @{}
  foreach ($k in $BaseDefaults.Keys) {
    $merged[$k] = ConvertTo-HashtableDeep -Value $BaseDefaults[$k]
  }

  foreach ($k in $CurrentConfig.Keys) {
    if ($merged.ContainsKey($k) -and ($merged[$k] -is [hashtable]) -and ($CurrentConfig[$k] -is [hashtable])) {
      $merged[$k] = Merge-ConfigDefaults -BaseDefaults $merged[$k] -CurrentConfig $CurrentConfig[$k]
    }
    else {
      $merged[$k] = ConvertTo-HashtableDeep -Value $CurrentConfig[$k]
    }
  }

  return $merged
}

if (-not (Test-Path -LiteralPath $runtimeDir -PathType Container)) {
  New-Item -ItemType Directory -Path $runtimeDir | Out-Null
}

if (-not (Test-Path -LiteralPath $runsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $runsDir | Out-Null
}

if (-not (Test-Path -LiteralPath $approvalsDir -PathType Container)) {
  New-Item -ItemType Directory -Path $approvalsDir | Out-Null
}

if (-not (Test-Path -LiteralPath $templateSource -PathType Leaf)) {
  throw "Missing template source: $templateSource"
}

if ([System.IO.Path]::GetFullPath($templateSource) -ne [System.IO.Path]::GetFullPath($templatePath)) {
  Copy-Item -LiteralPath $templateSource -Destination $templatePath -Force
}

if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
  Copy-Item -LiteralPath $templatePath -Destination $configPath -Force
  Write-Host "[install] created $configPath"
}
else {
  $templateObj = Read-Utf8 -Path $templatePath | ConvertFrom-Json
  $currentObj = Read-Utf8 -Path $configPath | ConvertFrom-Json
  $templateHash = ConvertTo-HashtableDeep -Value $templateObj
  $currentHash = ConvertTo-HashtableDeep -Value $currentObj
  $mergedHash = Merge-ConfigDefaults -BaseDefaults $templateHash -CurrentConfig $currentHash
  Write-Utf8Bom -Path $configPath -Content ($mergedHash | ConvertTo-Json -Depth 20)
  Write-Host "[install] config migrated with missing defaults: $configPath"
}

function Ensure-ApprovalFile {
  param(
    [string]$Path,
    [string]$Title,
    [hashtable]$ExtraFields = @{}
  )
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    $payload = [ordered]@{
      approved = $false
      title = $Title
      approved_by = ""
      approved_at = ""
      note = "Set approved=true only after explicit user confirmation."
    }
    foreach ($key in $ExtraFields.Keys) {
      $payload[$key] = $ExtraFields[$key]
    }
    $payloadJson = $payload | ConvertTo-Json -Depth 5
    Write-Utf8Bom -Path $Path -Content $payloadJson
    Write-Host "[install] created approval file: $Path"
  }
}

Ensure-ApprovalFile -Path (Join-Path $approvalsDir "design-freeze.json") -Title "Design Freeze Approval"
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "story-choice.json") -Title "Story Choice Approval" -ExtraFields @{ selected_option = ""; note = "Set approved=true and selected_option to 1, 2, or 3 only after the user chooses the story direction." }
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "book-plan-approval.json") -Title "Book Plan Approval" -ExtraFields @{ approved_plan_id = ""; accepted_plan_summary = ""; accepted_writing_type = ""; accepted_genre = ""; accepted_targets = @{ target_pages = 0; target_words = 0; target_chapters = 0 }; note = "Set approved=true only after the user reviews design/04_book_plan.md, design/05_chapter_plan.md, design/06_layout_plan.md and the matching revision/_state plan JSON files. accepted_targets and accepted_writing_type/genre must match the approved plan." }
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "length-depth-approval.json") -Title "Length Depth Approval" -ExtraFields @{ risk_acknowledged = $false; note = "Set approved=true and risk_acknowledged=true only when the user accepts that the requested page count may limit character depth, pacing, or genre complexity." }
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "rewrite-approval.json") -Title "Rewrite Approval"
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "export-approval.json") -Title "Export Approval"
Ensure-ApprovalFile -Path (Join-Path $approvalsDir "cleanup-approval.json") -Title "Cleanup Approval" -ExtraFields @{ final_output_preserved = $false; user_confirmed_book_finished = $false; note = "Set approved=true, final_output_preserved=true, and user_confirmed_book_finished=true only after the user explicitly says the book is finished and working files should be removed. This is not implied by export approval." }

if (-not (Test-Path -LiteralPath $statusPath -PathType Leaf)) {
  $status = [ordered]@{
    schema_version = "1.0.0"
    status = "draft"
    final_output_path = ""
    cleanup_allowed = $false
    cleanup_completed_at = ""
    note = "The app must not clean working files until cleanup-approval.json is explicitly approved by the user."
  }
  Write-Utf8Bom -Path $statusPath -Content ($status | ConvertTo-Json -Depth 10)
  Write-Host "[install] created project status: $statusPath"
}

Write-Host "[install] runtime bootstrap complete."
