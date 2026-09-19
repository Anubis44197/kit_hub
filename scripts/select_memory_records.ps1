[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$RecordsPath,
  [Parameter(Mandatory=$true)][string]$ProjectId,
  [Parameter(Mandatory=$true)][string]$BookId,
  [Parameter(Mandatory=$true)][string]$Phase,
  # -1 = oto: sema story_state taniliyor + story_state_recent_count varsa o deger, yoksa 0 (kapali).
  # 0 = kapali (eski davranis). >0 = ayni proje+kitabin son N story_state kaydi (faz fark etmeksizin, ts'e gore).
  [int]$RecentStoryStateCount = -1
)

$ErrorActionPreference='Stop'

if (-not (Test-Path -LiteralPath $RecordsPath -PathType Leaf)) {
  throw "Memory records file not found: $RecordsPath"
}

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$schemaPath = Join-Path $ProjectRoot 'runtime/memory/schema.json'
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
$records = @()
$conflicts = @()
$storyState = @()
if ($RecentStoryStateCount -lt 0) {
  $RecentStoryStateCount = 0
  if (@($schema.record_types) -contains 'story_state' -and $null -ne $schema.story_state_recent_count) {
    $RecentStoryStateCount = [int]$schema.story_state_recent_count
  }
}

Get-Content -LiteralPath $RecordsPath | ForEach-Object {
  if ([string]::IsNullOrWhiteSpace($_)) { return }
  $record = $_ | ConvertFrom-Json
  $missing = @($schema.required_fields | Where-Object { [string]::IsNullOrWhiteSpace([string]$record.$_) })
  $forbidden = @($schema.forbidden_fields | Where-Object { $null -ne $record.$_ })
  if ($missing.Count -gt 0 -or $forbidden.Count -gt 0) {
    $conflicts += [pscustomobject]@{ reason='schema_violation'; missing=$missing; forbidden=$forbidden; summary=$record.summary }
    return
  }
  if ($record.record_type -eq 'story_state' -and $record.project_id -eq $ProjectId -and $record.book_id -eq $BookId) {
    # Hikâye durumu: fazdan bagimsiz toplanir, asagida son N tanesi secilir.
    $storyState += $record
  } elseif ($record.project_id -eq $ProjectId -and $record.book_id -eq $BookId -and $record.phase -eq $Phase) {
    $records += $record
  } elseif ($record.project_id -eq $ProjectId -and $record.book_id -ne $BookId) {
    $conflicts += [pscustomobject]@{ reason='cross_book_excluded'; book_id=$record.book_id; phase=$record.phase; summary=$record.summary }
  } elseif ($record.project_id -ne $ProjectId) {
    $conflicts += [pscustomobject]@{ reason='cross_project_excluded'; project_id=$record.project_id; book_id=$record.book_id; summary=$record.summary }
  }
}

$recentStoryState = @()
if ($RecentStoryStateCount -gt 0 -and $storyState.Count -gt 0) {
  $recentStoryState = @($storyState | Sort-Object -Property ts -Descending | Select-Object -First $RecentStoryStateCount)
}

[ordered]@{
  schema_version = '1.0.0'
  selector = 'same_project_same_book_relevant_phase'
  project_id = $ProjectId
  book_id = $BookId
  phase = $Phase
  selected_count = $records.Count
  conflict_count = $conflicts.Count
  records = $records
  conflicts = $conflicts
  story_state_count = $recentStoryState.Count
  story_state = $recentStoryState
} | ConvertTo-Json -Depth 12
