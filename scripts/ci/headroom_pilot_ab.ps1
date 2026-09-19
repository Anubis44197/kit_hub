<#
.SYNOPSIS
  Headroom pilot A/B: GERCEK depo dosyalari uzerinde kisaltma orani + alan butunlugu kaniti.

.NE YAPAR
  1. Gercek fixture'lari (buyuk log/JSON) motorun uzerinden gecirir.
  2. Her vaka icin: girdi bayti, cikti bayti, oran, uygulandi/fallback, butunluk kontrolu.
  3. Ozeti runtime/fixture-reports/headroom-pilot.json dosyasina yazar.

  Pilot, adapter'i GERCEKTEN acmadan olcmek icin gecici bir yapilandirma kullanir
  (enabled=true kopyasi); gercek yapilandirmaya dokunmaz.

.KABUL
  En az bir vakada uygulandi=true ve oran >= min_reduction_ratio olmali; hicbir vakada
  butunluk kontrolu basarisiz olmamali.
#>
[CmdletBinding()]
param(
  [string]$OutPath
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
if (-not $OutPath) { $OutPath = Join-Path $repoRoot 'runtime/fixture-reports/headroom-pilot.json' }

$configPath = Join-Path $repoRoot 'runtime/adapters/headroom.json'
$reduce = Join-Path $repoRoot 'scripts/headroom_reduce.ps1'
$cfg = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$minRatio = [double]$cfg.min_reduction_ratio

# Gecici pilot yapilandirmasi (yalnizca enabled alani true yapilir)
$tmpConfig = Join-Path $env:TEMP ('headroom-pilot-config-' + [guid]::NewGuid().ToString('N') + '.json')
$cfg.enabled = $true
$cfg | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $tmpConfig -Encoding UTF8

$work = Join-Path $env:TEMP ('headroom-pilot-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null

$cases = @(
  @{ file = 'runtime/omniroute-data/logs/application/app.log'; type = 'repeated_log' }
  @{ file = 'runtime/run-integrity-report.json'; type = 'large_json' }
  @{ file = 'runtime/browser-e2e-report-deepcheck.json'; type = 'large_json' }
  @{ file = 'runtime/provider-fixture-reports/ollama-36-agent-report.json'; type = 'large_json' }
)

$results = @()
$anyPass = $false
$integrityOk = $true

foreach ($c in $cases) {
  $p = Join-Path $repoRoot $c.file
  if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
    $results += [ordered]@{ path = $c.file; contentType = $c.type; status = 'fixture_missing' }
    continue
  }
  $out = Join-Path $work (([System.IO.Path]::GetFileName($c.file)) + '.reduced')
  $json = & $reduce -Path $p -ContentType $c.type -ConfigPath $tmpConfig -OutPath $out | ConvertFrom-Json

  $valid = $true
  $note = ''
  if ($json.applied) {
    if ($c.type -eq 'large_json' -or $c.type -eq 'tool_output') {
      try { $null = Get-Content -LiteralPath $out -Raw | ConvertFrom-Json } catch { $valid = $false; $note = 'reduced_json_unparseable' }
    } else {
      if (-not (Test-Path -LiteralPath $out) -or (Get-Item $out).Length -eq 0) { $valid = $false; $note = 'reduced_empty' }
    }
  }
  if (-not $valid) { $integrityOk = $false }
  if ($json.applied -and -not $json.preserveOk) { $integrityOk = $false }

  if ($json.applied -and $json.reductionRatio -ge $minRatio -and $valid) { $anyPass = $true }

  $results += [ordered]@{
    path           = $c.file
    contentType    = $c.type
    status         = $(if ($json.applied) { 'reduced' } else { 'fallback_raw' })
    reason         = $json.reason
    inputBytes     = $json.inputBytes
    outputBytes    = $json.outputBytes
    reductionRatio = $json.reductionRatio
    preserveOk     = $json.preserveOk
    validOutput    = $valid
    note           = $note
  }
}

Remove-Item $tmpConfig -Force -ErrorAction SilentlyContinue
Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

$report = [ordered]@{
  schema_version    = '1.0.0'
  generatedAt       = (Get-Date).ToString('s')
  engine            = 'scripts/headroom_reduce.ps1'
  config            = $configPath
  pilotConfigNote   = 'enabled=true gecici kopya ile olculdu; gercek yapilandirma degismedi'
  min_reduction_ratio = $minRatio
  size_floor_bytes  = [int]$cfg.max_input_bytes
  cases             = $results
  integrity_ok      = $integrityOk
  at_least_one_reduced = $anyPass
  pass              = ($anyPass -and $integrityOk)
}
$dir = Split-Path -Parent $OutPath
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutPath -Encoding UTF8

Write-Output ('[headroom-pilot] vaka: ' + @($results).Count + ' | butunluk: ' + $integrityOk + ' | en az bir kisaltma: ' + $anyPass)
foreach ($r in $results) {
  if ($r.status -eq 'fixture_missing') { Write-Output ('  - ' + $r.path + ' -> fixture yok'); continue }
  Write-Output ('  - ' + $r.path + ' [' + $r.contentType + '] ' + $r.status + ' | ' + $r.inputBytes + ' -> ' + $r.outputBytes + ' B | oran ' + $r.reductionRatio + ' | ' + $r.reason)
}
Write-Output ('[headroom-pilot] rapor: ' + $OutPath)
if ($report.pass) { Write-Output '[headroom-pilot] SONUC: PASS'; exit 0 } else { Write-Output '[headroom-pilot] SONUC: FAIL'; exit 2 }
