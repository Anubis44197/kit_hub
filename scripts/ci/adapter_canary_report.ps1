[CmdletBinding()]
param([string]$ProjectRoot=(Get-Location).Path)
$ErrorActionPreference='Stop'
$ts=(Get-Date).ToUniversalTime().ToString('o')
$obsRun='canary-'+[guid]::NewGuid().ToString('N')
& (Join-Path $ProjectRoot 'scripts/run_observer_snapshot.ps1') -ProjectRoot $ProjectRoot -RunId $obsRun -TaskId 'adapter-canary' | Out-Null
$obsPath=Join-Path $ProjectRoot "runtime/agent-runs/$obsRun/observer.jsonl"
$obs=Get-Content $obsPath -Raw | ConvertFrom-Json
$mem='{"project_id":"canary","book_id":"fixture","run_id":"'+$obsRun+'","phase":"propose","source_hash":"fixture","summary":"canary"}'
$memResult=& (Join-Path $ProjectRoot 'scripts/validate_memory_record.ps1') -RecordJson $mem | ConvertFrom-Json
$omni=& (Join-Path $ProjectRoot 'scripts/omniroute_health_check.ps1') -ProjectRoot $ProjectRoot | ConvertFrom-Json
$omniGateway=$null
try {
  $omniGateway=& (Join-Path $ProjectRoot 'scripts/ci/omniroute_gateway_canary.ps1') -ProjectRoot $ProjectRoot -TimeoutSeconds 90 | ConvertFrom-Json
} catch {
  $omniGateway=[pscustomobject]@{status='fail'; error=$_.Exception.Message}
}
$hr=& (Join-Path $ProjectRoot 'scripts/headroom_policy_check.ps1') -ContentType creative_text -Bytes 2000000 | ConvertFrom-Json
$omniStatus=if($omni.status -eq 'healthy'){'healthy'}elseif($omniGateway.status -eq 'pass'){'healthy_local_canary'}else{'blocked_disabled'}
# Headroom: politika kapisi yaratici metin icin HER ZAMAN excluded doner (dogru davranis).
# Gercek durumu gostermek icin pilot A/B kaniti da rapora girer.
$hrCfg=Get-Content (Join-Path $ProjectRoot 'runtime/adapters/headroom.json') -Raw | ConvertFrom-Json
$hrPilotPath=Join-Path $ProjectRoot 'runtime/fixture-reports/headroom-pilot.json'
$hrPilot=$null
if(Test-Path $hrPilotPath){ $hrPilot=Get-Content $hrPilotPath -Raw | ConvertFrom-Json }
$hrBest=$null; $hrPass=$false
if($hrPilot){ $reduced=@($hrPilot.cases | Where-Object { $_.status -eq 'reduced' }); if($reduced.Count -gt 0){ $hrBest=($reduced | Measure-Object -Property reductionRatio -Maximum).Maximum }; $hrPass=[bool]$hrPilot.pass }
$hrStatus='disabled_fallback_raw'
if([bool]$hrCfg.enabled){ if($hrPass){ $hrStatus='enabled_pilot_proven' } else { $hrStatus='enabled_without_pilot_evidence' } }
$report=[ordered]@{schema_version='1.0.0';generatedAt=$ts;runId=$obsRun;baseline='filesystem-context-pack';observer=[ordered]@{status=$(if($obs.timedOut){'timeout_fail_open'}else{'completed'});path=$obsPath};memory=[ordered]@{status=$(if($memResult.valid){'pass'}else{'fail'})};omniroute=[ordered]@{status=$omniStatus;enabled=$omni.enabled;gateway_canary=$omniGateway};headroom=[ordered]@{status=$hrStatus;enabled=[bool]$hrCfg.enabled;creative_text_eligible=$hr.eligible;policy='creative_text_excluded_raw_content';pilot_pass=$hrPass;best_reduction_ratio=$hrBest;size_floor_bytes=$hr.size_floor_bytes};rollout='evidence_gated_activation'}
$out=Join-Path $ProjectRoot 'runtime/fixture-reports/adapter-canary-latest.json'; $report | ConvertTo-Json -Depth 12 | Set-Content -Path $out -Encoding UTF8; $report | ConvertTo-Json -Depth 12
