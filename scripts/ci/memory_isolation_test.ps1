[CmdletBinding()]
param([string]$ProjectRoot=(Get-Location).Path)

$ErrorActionPreference='Stop'

$fixtureDir = Join-Path $ProjectRoot 'runtime/fixture-reports'
New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
$fixturePath = Join-Path $fixtureDir 'memory-isolation-fixture.jsonl'

$records = @(
  @{project_id='kithub'; book_id='book-a'; run_id='run-1'; phase='propose'; source_hash='hash-a'; summary='selected decision'; record_type='decision'},
  @{project_id='kithub'; book_id='book-b'; run_id='run-2'; phase='propose'; source_hash='hash-b'; summary='other book decision'; record_type='decision'},
  @{project_id='other-project'; book_id='book-a'; run_id='run-3'; phase='propose'; source_hash='hash-c'; summary='other project decision'; record_type='decision'},
  @{project_id='kithub'; book_id='book-a'; run_id='run-4'; phase='polish'; source_hash='hash-d'; summary='other phase decision'; record_type='decision'}
)

$records | ForEach-Object { $_ | ConvertTo-Json -Compress } | Set-Content -LiteralPath $fixturePath -Encoding UTF8

$result = & (Join-Path $ProjectRoot 'scripts/select_memory_records.ps1') -RecordsPath $fixturePath -ProjectId 'kithub' -BookId 'book-a' -Phase 'propose' | ConvertFrom-Json

if ($result.selected_count -ne 1) { throw "Expected 1 selected memory record, got $($result.selected_count)" }
if ($result.records[0].summary -ne 'selected decision') { throw 'Selected wrong memory record' }
$crossBook = @($result.conflicts | Where-Object { $_.reason -eq 'cross_book_excluded' })
$crossProject = @($result.conflicts | Where-Object { $_.reason -eq 'cross_project_excluded' })
if ($crossBook.Count -lt 1) { throw 'Cross-book exclusion was not reported' }
if ($crossProject.Count -lt 1) { throw 'Cross-project exclusion was not reported' }

Write-Output "[memory-isolation] PASS selected=$($result.selected_count) conflicts=$($result.conflict_count)"
