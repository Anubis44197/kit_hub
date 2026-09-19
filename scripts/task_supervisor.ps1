param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [int]$DefaultTimeoutSeconds = 1800
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "task_engine.ps1")

function Get-TaskTimeoutSeconds {
  param([object]$Task)
  $registryPath = Join-Path $ProjectRoot "runtime/agent-registry.json"
  if (Test-Path -LiteralPath $registryPath -PathType Leaf) {
    try {
      $registry = [System.IO.File]::ReadAllText($registryPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
      $entry = @($registry.agents | Where-Object { [string]$_.name -eq [string]$Task.agent } | Select-Object -First 1)[0]
      if ($entry -and [int]$entry.timeout_seconds -gt 0) { return [int]$entry.timeout_seconds }
    } catch {}
  }
  return $DefaultTimeoutSeconds
}

$queue = Get-TaskQueue -ProjectRoot $ProjectRoot
$result = [ordered]@{ ok = $true; checked = 0; alive = 0; failed = 0; timed_out = 0; skipped = 0 }
foreach ($task in @($queue.tasks | Where-Object { [string]$_.status -eq "in_flight" })) {
  if (-not [string]$task.run_id) { $result.skipped++; continue }
  $run = Get-AgentRun -ProjectRoot $ProjectRoot -RunId ([string]$task.run_id)
  if (-not $run) {
    $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId ([string]$task.id) -Status "failed" -ErrorText "AgentRun record is missing."
    $result.failed++; continue
  }
  $result.checked++
  $started = if ($run.startedAt) { [DateTimeOffset]::Parse([string]$run.startedAt) } else { [DateTimeOffset]::Parse([string]$run.createdAt) }
  $elapsed = [int]([DateTimeOffset]::Now - $started).TotalSeconds
  $timeout = Get-TaskTimeoutSeconds -Task $task
  $process = $null
  if ($null -ne $run.pid) { $process = Get-Process -Id ([int]$run.pid) -ErrorAction SilentlyContinue }
  if ($elapsed -gt $timeout) {
    if ($process) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
    $message = "Provider timed out after $elapsed seconds (limit $timeout seconds)."
    $null = Update-AgentRun -ProjectRoot $ProjectRoot -RunId ([string]$run.runId) -Status "failed" -ExitCode 124 -ErrorText $message
    $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId ([string]$task.id) -Status "failed" -ErrorText $message
    $result.timed_out++; continue
  }
  if (-not $process) {
    $message = "Provider process is no longer alive."
    $null = Update-AgentRun -ProjectRoot $ProjectRoot -RunId ([string]$run.runId) -Status "failed" -ExitCode 1 -ErrorText $message
    $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId ([string]$task.id) -Status "failed" -ErrorText $message
    $result.failed++; continue
  }
  $null = Update-AgentRun -ProjectRoot $ProjectRoot -RunId ([string]$run.runId) -Status "running"
  $result.alive++
}

[pscustomobject]$result | ConvertTo-Json -Compress
