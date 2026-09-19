[CmdletBinding()]
param([string]$ProjectRoot = (Get-Location).Path)
$ErrorActionPreference='Stop'
$runId='observer-fixture-'+[guid]::NewGuid().ToString('N')
$r=& (Join-Path $ProjectRoot 'scripts/run_observer_snapshot.ps1') -ProjectRoot $ProjectRoot -RunId $runId -TaskId 'fixture' 2>&1 | Out-String
$path=Join-Path $ProjectRoot "runtime/agent-runs/$runId/observer.jsonl"
if(-not (Test-Path $path)){ throw 'observer.jsonl missing' }
$line=Get-Content $path -Raw | ConvertFrom-Json
if($line.source -ne 'observer-usage-one-shot'){ throw 'source mismatch' }
Write-Output "[observer-adapter] PASS runId=$runId exitCode=$($line.exitCode)"
