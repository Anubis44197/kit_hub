<#
Adapter envanter sozlesme testi.

ONCEKI KURAL: "hicbir adapter acilmamali" (fail-closed varsayimi).
YENI KURAL: "KANITSIZ adapter acilamaz" (kanita dayali aktivasyon).

Plan (2026-09-18) kapsaminda Observer, Hafiza ve Headroom kanitla acildi; bu test artik
acik her adapter icin kanit artefakti arar. Boylece bir adapterin yanlislikla/kanitsiz
acilmasi regresyon olarak yakalanir.
#>
[CmdletBinding()]
param([string]$ProjectRoot = (Get-Location).Path)

$ErrorActionPreference = 'Stop'

$inventory = & (Join-Path $ProjectRoot 'scripts/adapter_inventory_check.ps1') -ProjectRoot $ProjectRoot | ConvertFrom-Json
$expected = @('codebase-memory-mcp', 'observer', 'omniroute', 'headroom')

# Acik her adapter icin beklenen KANIT artefakti (taze olmasa da var olmali ve basarili olmali).
$evidenceRules = @{
  'headroom' = {
    $p = Join-Path $ProjectRoot 'runtime/fixture-reports/headroom-pilot.json'
    if (-not (Test-Path $p)) { return 'headroom-pilot.json yok (pilot kaniti yok)' }
    $r = Get-Content $p -Raw | ConvertFrom-Json
    if (-not $r.pass) { return 'headroom pilot PASS degil' }
    if (-not $r.integrity_ok) { return 'headroom pilot butunluk kontrolu basarisiz' }
    return $null
  }
  'observer' = {
    $runs = @(Get-ChildItem (Join-Path $ProjectRoot 'runtime/agent-runs') -Directory -ErrorAction SilentlyContinue)
    $withSnap = @($runs | Where-Object { Test-Path (Join-Path $_.FullName 'observer.jsonl') })
    if ($withSnap.Count -eq 0) { return 'hicbir agent-run observer.jsonl snapshot kaniti yok' }
    return $null
  }
  'omniroute' = {
    $p = Join-Path $ProjectRoot 'runtime/fixture-reports/adapter-canary-latest.json'
    if (-not (Test-Path $p)) { return 'adapter-canary-latest.json yok' }
    $r = Get-Content $p -Raw | ConvertFrom-Json
    if ($r.omniroute.gateway_canary.status -ne 'pass') { return 'omniroute gateway canary PASS degil' }
    return $null
  }
  'codebase-memory-mcp' = {
    $p = Join-Path $ProjectRoot 'runtime/fixture-reports/codebase-memory-probe.json'
    if (-not (Test-Path $p)) { return 'codebase-memory stdio probe kaniti yok' }
    $r = Get-Content $p -Raw | ConvertFrom-Json
    if (-not $r.ok) { return 'codebase-memory stdio probe PASS degil' }
    return $null
  }
}

foreach ($id in $expected) {
  $row = $inventory | Where-Object { $_.id -eq $id } | Select-Object -First 1
  if (-not $row) { throw "Missing adapter inventory row: $id" }
  if (-not $row.config) { throw "Missing config path for adapter: $id" }

  if ($row.enabled) {
    $violation = & $evidenceRules[$id]
    if ($violation) { throw "Adapter enabled without valid evidence ($id): $violation" }
    Write-Output "[adapter-inventory-contract] enabled with evidence: $id"
  } else {
    Write-Output "[adapter-inventory-contract] disabled (fail-closed): $id"
  }
}

$serialized = $inventory | ConvertTo-Json -Depth 8
foreach ($forbidden in @('api_key', 'credential', 'raw_prompt', 'personal_data')) {
  if ($serialized -match $forbidden) { throw "Forbidden sensitive field leaked in adapter inventory: $forbidden" }
}

Write-Output "[adapter-inventory-contract] PASS adapters=$($expected -join ',')"
