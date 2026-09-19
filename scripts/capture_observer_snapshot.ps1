# Observer tek atımlık kullanım anlık görüntüsü (fail-open).
# Görev koşularının sonunda çağrılır; HİÇBİR hata görevi düşürmez.
# - status --json: hızlı, her koşuda yazılır.
# - usage --json: yavaş olabilir; DB boşken atlanır (KITHUB_OBSERVER_FORCE_USAGE=1 ile zorlanır).
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [string]$Phase = "",
  [string]$TaskId = ""
)

$ErrorActionPreference = "Stop"

function Write-ObserverLine {
  param([string]$Path, [object]$Record)
  $line = $Record | ConvertTo-Json -Depth 12 -Compress
  if ($line.Length -gt 200000) { $line = $line.Substring(0, 200000) }
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::AppendAllText($Path, $line + "`n", $utf8NoBom)
}

function Invoke-WithTimeout {
  # PS 5.1 uyumlu: komutu job icinde calistirir, sureyi asarsa durdurur ve $null doner.
  param([string]$Exe, [string[]]$ExeArgs, [int]$TimeoutSeconds)
  $job = Start-Job -ScriptBlock {
    param($exe, $args2)
    & $exe @args2 2>&1 | Out-String
  } -ArgumentList $Exe, $ExeArgs
  if (Wait-Job $job -Timeout $TimeoutSeconds) {
    $out = Receive-Job $job | Out-String
    Remove-Job $job -Force
    return $out
  }
  Stop-Job $job
  Remove-Job $job -Force
  return $null
}

try {
  $adapterPath = Join-Path $ProjectRoot "runtime/adapters/observer.json"
  if (-not (Test-Path $adapterPath)) { Write-Host "[observer] adapter config yok, atlandi."; exit 0 }
  $cfg = Get-Content $adapterPath -Raw | ConvertFrom-Json
  if (-not $cfg.enabled) { Write-Host "[observer] adapter disabled, atlandi."; exit 0 }

  $binary = [string]$cfg.binary
  if (-not [IO.Path]::IsPathRooted($binary)) { $binary = Join-Path $ProjectRoot $binary }
  $binary = [System.IO.Path]::GetFullPath($binary)
  if (-not (Test-Path $binary)) {
    # Izole/test projelerinde .tools tasinmaz; repo kokune geri dus (fail-open).
    $repoFallback = Join-Path (Split-Path $PSScriptRoot -Parent) ([string]$cfg.binary)
    if (Test-Path $repoFallback) { $binary = [System.IO.Path]::GetFullPath($repoFallback) }
  }
  if (-not (Test-Path $binary)) { Write-Host "[observer] binary bulunamadi: $binary"; exit 0 }

  $runDir = Join-Path $ProjectRoot (Join-Path "runtime/agent-runs" $RunId)
  New-Item -ItemType Directory -Path $runDir -Force | Out-Null
  $outPath = Join-Path $runDir "observer.jsonl"
  $timeout = if ($cfg.output.timeout_seconds) { [int]$cfg.output.timeout_seconds } else { 30 }

  $base = [ordered]@{
    ts = (Get-Date).ToString("o")
    runId = $RunId
    phase = $Phase
    taskId = $TaskId
    source = "observer"
  }

  # 1) Durum anlık görüntüsü (hızlı, kritik kanıt)
  $statusJson = $null
  $statusOut = Invoke-WithTimeout -Exe $binary -ExeArgs @("status", "--json") -TimeoutSeconds ([Math]::Min($timeout, 20))
  $rec = [ordered]@{}; foreach ($k in $base.Keys) { $rec[$k] = $base[$k] }
  $rec["kind"] = "status"
  if ($statusOut) {
    try {
      $statusJson = $statusOut | ConvertFrom-Json
      $rec["counts"] = $statusJson.counts
    } catch { $rec["error"] = "parse hatasi" }
  } else {
    $rec["error"] = "timeout"
  }
  Write-ObserverLine -Path $outPath -Record $rec

  # 2) Kullanım anlık görüntüsü: yavaş olabilir (boşta 30s+ sürer).
  #    Observer DB boşken atlanır; veri varsa veya KITHUB_OBSERVER_FORCE_USAGE=1 ise çalışır.
  $sessionCount = 0
  try { $sessionCount = [int]$statusJson.counts.sessions } catch { $sessionCount = 0 }
  $forceUsage = ($env:KITHUB_OBSERVER_FORCE_USAGE -eq "1")

  if (($sessionCount -gt 0) -or $forceUsage) {
    $usageOut = Invoke-WithTimeout -Exe $binary -ExeArgs @("usage", "--json", "--no-progress", "--since", "30d") -TimeoutSeconds $timeout
    $rec = [ordered]@{}; foreach ($k in $base.Keys) { $rec[$k] = $base[$k] }
    $rec["kind"] = "usage"
    if ($usageOut) {
      $trimmed = $usageOut.Trim()
      if ($trimmed.Length -gt 100000) {
        $rec["truncated"] = $true; $rec["size"] = $trimmed.Length
        $rec["excerpt"] = $trimmed.Substring(0, 8000)
      } else {
        try { $rec["data"] = ($trimmed | ConvertFrom-Json) }
        catch { $rec["raw"] = $trimmed }
      }
    } else {
      $rec["error"] = "timeout"
    }
    Write-ObserverLine -Path $outPath -Record $rec
  } else {
    $rec = [ordered]@{}; foreach ($k in $base.Keys) { $rec[$k] = $base[$k] }
    $rec["kind"] = "usage"; $rec["skipped"] = "observer_db_empty"
    Write-ObserverLine -Path $outPath -Record $rec
  }

  Write-Host "[observer] snapshot yazildi: $outPath"
  exit 0
}
catch {
  Write-Host "[observer] snapshot atlandi (fail-open): $($_.Exception.Message)"
  exit 0
}
