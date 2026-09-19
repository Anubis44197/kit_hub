[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$ProjectRoot,
  [Parameter(Mandatory=$true)][string]$RunId,
  [string]$TaskId = '',
  [int]$TimeoutSeconds = 30
)
$ErrorActionPreference = 'Stop'
$adapter = Join-Path $ProjectRoot 'runtime/adapters/observer.json'
$cfg = Get-Content $adapter -Raw | ConvertFrom-Json
$exe = Join-Path $ProjectRoot ([string]$cfg.binary)
$runDir = Join-Path $ProjectRoot ("runtime/agent-runs/{0}" -f $RunId)
New-Item -ItemType Directory -Force -Path $runDir | Out-Null
$out = Join-Path $runDir 'observer.raw.json'
$err = Join-Path $runDir 'observer.stderr.log'
$jsonl = Join-Path $runDir 'observer.jsonl'
$started = Get-Date
$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $exe
$startInfo.Arguments = 'usage --json --no-progress --since 30d'
$startInfo.WorkingDirectory = $ProjectRoot
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$p = [System.Diagnostics.Process]::Start($startInfo)
$timedOut = $false
try { if(-not $p.WaitForExit($TimeoutSeconds * 1000)){ $timedOut=$true; Stop-Process -Id $p.Id -Force } } catch { $timedOut=$true }
$stdoutText = $p.StandardOutput.ReadToEnd()
$stderrText = $p.StandardError.ReadToEnd()
Set-Content -LiteralPath $out -Value $stdoutText -Encoding UTF8
Set-Content -LiteralPath $err -Value $stderrText -Encoding UTF8
$finished = Get-Date
$record = [ordered]@{ schema_version='1.0.0'; runId=$RunId; taskId=$TaskId; startedAt=$started.ToUniversalTime().ToString('o'); finishedAt=$finished.ToUniversalTime().ToString('o'); timedOut=$timedOut; exitCode=$(if($timedOut){124}else{$p.ExitCode}); source='observer-usage-one-shot' }
if(Test-Path $out){ try { $payload=Get-Content $out -Raw | ConvertFrom-Json; $record.payload=$payload } catch { $record.parseError=$_.Exception.Message } }
$record | ConvertTo-Json -Depth 20 -Compress | Add-Content -Path $jsonl -Encoding UTF8
$record | ConvertTo-Json -Depth 20
if($timedOut -or $record.exitCode -ne 0){ exit 0 }
