param(
  [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
)

$ErrorActionPreference = "Stop"
. (Join-Path $ProjectRoot "scripts/task_engine.ps1")

$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kithub-task-engine-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $fixtureRoot -Force | Out-Null

try {
  $task = New-TaskItem -ProjectRoot $fixtureRoot -Agent "quality-verifier" -Title "Runtime fixture" -Phase "polish" -Scope ([ordered]@{ kind = "phase"; phase = "polish" })
  if (-not $task.requires_approval -or $task.status -ne "pending") { throw "New task default contract failed." }

  $run = New-AgentRun -ProjectRoot $fixtureRoot -TaskId $task.id -Phase $task.phase -Provider "fixture" -LogOut "out.log" -LogErr "err.log"
  $null = Attach-AgentRunToTask -ProjectRoot $fixtureRoot -TaskId $task.id -RunId $run.runId
  $null = Set-TaskStatus -ProjectRoot $fixtureRoot -TaskId $task.id -Status "in_flight"
  $null = Update-AgentRun -ProjectRoot $fixtureRoot -RunId $run.runId -Status "completed" -ProcessId 4242 -ExitCode 0
  $null = Set-TaskStatus -ProjectRoot $fixtureRoot -TaskId $task.id -Status "completed" -Result ([ordered]@{ summary = "Fixture completed"; verdict = "pass"; issues = @(); artifacts = @() })

  $summary = Get-TaskSummary -ProjectRoot $fixtureRoot
  $savedTask = @($summary.tasks | Where-Object { $_.id -eq $task.id })[0]
  $savedRun = @($summary.runs | Where-Object { $_.runId -eq $run.runId })[0]
  if (-not $savedTask -or $savedTask.run_id -ne $run.runId -or $savedTask.status -ne "completed") { throw "Task/run linkage assertion failed." }
  if (-not $savedRun -or $savedRun.status -ne "completed" -or $savedRun.pid -ne 4242 -or $savedRun.exitCode -ne 0) { throw "Run journal assertion failed." }

  Write-Host "[task-engine-runtime] PASS"
}
finally {
  if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
}
