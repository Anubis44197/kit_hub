# task_engine.ps1 — İnsan-Ajan İşbirliği Görev Motoru
# Buzz ajan çalışma mantığından esinlenilmiştir (kuyruk, mention, onay->tetikleyici, denetim akışı).
# Studio bridge (studio_bridge.ps1) tarafından dot-source edilir; bağımsız olarak da test edilebilir.

$ErrorActionPreference = "Stop"

function Read-TaskJsonFile {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
  try { return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } catch { return $null }
}

function Write-TaskJsonFile {
  param([string]$Path, [object]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  $json = $Value | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($true))
}

function Get-TaskStateDir {
  param([string]$ProjectRoot)
  return Join-Path $ProjectRoot "revision/_state"
}

function Get-AgentRunDir {
  param([string]$ProjectRoot)
  return Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "agent-runs"
}

function Get-AgentRunPath {
  param([string]$ProjectRoot, [string]$RunId)
  return Join-Path (Get-AgentRunDir -ProjectRoot $ProjectRoot) ("{0}.json" -f $RunId)
}

function Get-AgentRun {
  param([string]$ProjectRoot, [string]$RunId)
  return Read-TaskJsonFile -Path (Get-AgentRunPath -ProjectRoot $ProjectRoot -RunId $RunId)
}

function Save-AgentRun {
  param([string]$ProjectRoot, [object]$Run)
  $runDir = Get-AgentRunDir -ProjectRoot $ProjectRoot
  if (-not (Test-Path -LiteralPath $runDir)) { New-Item -ItemType Directory -Path $runDir -Force | Out-Null }
  Write-TaskJsonFile -Path (Get-AgentRunPath -ProjectRoot $ProjectRoot -RunId ([string]$Run.runId)) -Value $Run
  return $Run
}

function New-AgentRun {
  param(
    [string]$ProjectRoot,
    [string]$TaskId,
    [string]$Phase,
    [string]$Provider,
    [string]$LogOut,
    [string]$LogErr
  )
  $now = (Get-Date).ToString("o")
  $run = [ordered]@{
    runId = "run-" + [Guid]::NewGuid().ToString("N")
    taskId = $TaskId
    phase = $Phase
    provider = $Provider
    status = "starting"
    pid = $null
    createdAt = $now
    startedAt = $null
    heartbeatAt = $now
    finishedAt = $null
    exitCode = $null
    logOut = $LogOut
    logErr = $LogErr
    error = $null
  }
  return Save-AgentRun -ProjectRoot $ProjectRoot -Run $run
}

function Update-AgentRun {
  param(
    [string]$ProjectRoot,
    [string]$RunId,
    [string]$Status,
    [Nullable[int]]$ProcessId = $null,
    [Nullable[int]]$ExitCode = $null,
    [string]$ErrorText = $null
  )
  $run = Get-AgentRun -ProjectRoot $ProjectRoot -RunId $RunId
  if (-not $run) { throw "Agent run not found: $RunId" }
  $now = (Get-Date).ToString("o")
  $run.status = $Status
  $run.heartbeatAt = $now
  if ($null -ne $ProcessId) { $run.pid = $ProcessId.Value }
  if ($Status -eq "running" -and -not $run.startedAt) { $run.startedAt = $now }
  if ($Status -in @("completed", "failed", "cancelled")) { $run.finishedAt = $now }
  if ($null -ne $ExitCode) { $run.exitCode = $ExitCode.Value }
  if ($ErrorText) { $run.error = $ErrorText }
  return Save-AgentRun -ProjectRoot $ProjectRoot -Run $run
}

function Set-AgentRunRuntime {
  param([string]$ProjectRoot, [string]$RunId, [string]$Status, [int]$ProcessId = -1, [int]$ExitCode = -2147483648, [string]$ErrorText = "")
  $run = Get-AgentRun -ProjectRoot $ProjectRoot -RunId $RunId
  if (-not $run) { throw "Agent run not found: $RunId" }
  $now = (Get-Date).ToString("o")
  $run.status = $Status
  $run.heartbeatAt = $now
  if ($ProcessId -ge 0) { $run.pid = $ProcessId }
  if ($Status -eq "running" -and -not $run.startedAt) { $run.startedAt = $now }
  if ($Status -in @("completed", "failed", "cancelled")) { $run.finishedAt = $now }
  if ($ExitCode -ne -2147483648) { $run.exitCode = $ExitCode }
  if ($ErrorText) { $run.error = $ErrorText }
  return Save-AgentRun -ProjectRoot $ProjectRoot -Run $run
}

function Update-AgentRun {
  param(
    [string]$ProjectRoot,
    [string]$RunId,
    [string]$Status,
    [int]$ProcessId = -1,
    [int]$ExitCode = -2147483648,
    [string]$ErrorText = ""
  )
  return Set-AgentRunRuntime -ProjectRoot $ProjectRoot -RunId $RunId -Status $Status -ProcessId $ProcessId -ExitCode $ExitCode -ErrorText $ErrorText
}

function Get-TaskFeed {
  param([string]$ProjectRoot)
  $path = Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "task-feed.json"
  $feed = Read-TaskJsonFile -Path $path
  if (-not $feed) {
    $feed = [ordered]@{ schema_version = "1.0.0"; updated_at = (Get-Date).ToString("o"); max_entries = 500; entries = @() }
  }
  return $feed
}

function Save-TaskFeed {
  param([string]$ProjectRoot, [object]$Feed)
  $path = Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "task-feed.json"
  $Feed.updated_at = (Get-Date).ToString("o")
  $max = if ($Feed.max_entries) { [int]$Feed.max_entries } else { 500 }
  if ($Feed.entries.Count -gt $max) {
    $Feed.entries = @($Feed.entries | Select-Object -Skip ($Feed.entries.Count - $max))
  }
  Write-TaskJsonFile -Path $path -Value $Feed
}

function Add-TaskFeedEntry {
  param(
    [string]$ProjectRoot,
    [string]$ActorType,
    [string]$ActorId,
    [string]$ActorRole,
    [string]$Event,
    [string]$Message,
    [object]$Ref
  )
  $feed = Get-TaskFeed -ProjectRoot $ProjectRoot
  $entries = @($feed.entries)
  $nextNum = 1
  if ($entries.Count -gt 0) {
    $lastId = [string]$entries[$entries.Count - 1].id
    if ($lastId -match '^feed-([0-9]+)$') { $nextNum = [int]$Matches[1] + 1 }
  }
  $entry = [ordered]@{
    id = "feed-{0:D3}" -f $nextNum
    at = (Get-Date).ToString("o")
    actor_type = $ActorType
    actor_id = $ActorId
    actor_role = $ActorRole
    event = $Event
    ref = $Ref
    message = $Message
  }
  $feed.entries = @($entries) + @($entry)
  Save-TaskFeed -ProjectRoot $ProjectRoot -Feed $feed
  return $entry
}

function Get-TaskQueue {
  param([string]$ProjectRoot)
  $path = Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "task-queue.json"
  $queue = Read-TaskJsonFile -Path $path
  if (-not $queue) {
    $queue = [ordered]@{ schema_version = "1.0.0"; updated_at = (Get-Date).ToString("o"); tasks = @() }
  }
  return $queue
}

function Save-TaskQueue {
  param([string]$ProjectRoot, [object]$Queue)
  $path = Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "task-queue.json"
  $Queue.updated_at = (Get-Date).ToString("o")
  Write-TaskJsonFile -Path $path -Value $Queue
}

function Get-TaskTriggers {
  param([string]$ProjectRoot)
  $path = Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "task-triggers.json"
  $triggers = Read-TaskJsonFile -Path $path
  if (-not $triggers) {
    $triggers = [ordered]@{ schema_version = "1.0.0"; updated_at = (Get-Date).ToString("o"); enabled = $false; rules = @() }
  }
  return $triggers
}

function Save-TaskTriggers {
  param([string]$ProjectRoot, [object]$Triggers)
  $path = Join-Path (Get-TaskStateDir -ProjectRoot $ProjectRoot) "task-triggers.json"
  $Triggers.updated_at = (Get-Date).ToString("o")
  Write-TaskJsonFile -Path $path -Value $Triggers
}

function Get-TaskAgentIdentities {
  param([string]$ProjectRoot)
  $stateDir = Get-TaskStateDir -ProjectRoot $ProjectRoot
  $identPath = Join-Path $stateDir "agent-identities.json"
  $registryPath = Join-Path $ProjectRoot "runtime/agent-registry.json"

  $identities = Read-TaskJsonFile -Path $identPath
  $registry = Read-TaskJsonFile -Path $registryPath

  $result = @()
  $seen = @{}
  if ($identities -and $identities.agents) {
    foreach ($a in @($identities.agents)) {
      $seen[[string]$a.id] = $true
      $result += $a
    }
  }
  if ($registry -and $registry.agents) {
    foreach ($ra in @($registry.agents)) {
      if (-not $seen.ContainsKey([string]$ra.name)) {
        $result += [ordered]@{
          id = [string]$ra.name
          label = [string]$ra.name
          group = "duzenleme"
          enabled = $false
          color = "#6b7280"
          short = ([string]$ra.name).Substring(0, [Math]::Min(4, ([string]$ra.name).Length)).ToUpper()
          notes = "Registry'den türetildi; kimlik kartında özelleştirilmedi."
        }
      }
    }
  }
  return $result
}

function Get-TaskNextId {
  param([object]$Tasks, [string]$Prefix)
  $max = 0
  foreach ($t in @($Tasks)) {
    $id = [string]$t.id
    if ($id -match ("^" + $Prefix + "-([0-9]+)$")) {
      $n = [int]$Matches[1]
      if ($n -gt $max) { $max = $n }
    }
  }
  return $max + 1
}

function New-TaskItem {
  param(
    [string]$ProjectRoot,
    [string]$Agent,
    [string]$Title,
    [string]$Phase,
    [object]$Scope,
    [string]$Source = "manual",
    [object]$Mention = $null,
    [string]$Priority = "normal",
    [bool]$RequiresApproval = $true
  )
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $tasks = @($queue.tasks)
  $nextId = Get-TaskNextId -Tasks $tasks -Prefix "task"
  $now = (Get-Date).ToString("o")
  $task = [ordered]@{
    id = "task-{0:D3}" -f $nextId
    title = $Title
    agent = $Agent
    phase = $Phase
    scope = $Scope
    status = "pending"
    priority = $Priority
    source = $Source
    mention = $Mention
    created_at = $now
    started_at = $null
    finished_at = $null
    deadline = $null
    attempts = 0
    max_attempts = 2
    requires_approval = $RequiresApproval
    approval = $null
    result = $null
    error = $null
    run_id = $null
  }
  $queue.tasks = @($tasks) + @($task)
  Save-TaskQueue -ProjectRoot $ProjectRoot -Queue $queue
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "system" -ActorId "system" -ActorRole "task" -Event "task.created" -Message "Görev oluşturuldu: $Title ($Agent)" -Ref ([ordered]@{ task_id = $task.id; phase = $Phase })
  return $task
}

function Set-TaskStatus {
  param(
    [string]$ProjectRoot,
    [string]$TaskId,
    [string]$Status,
    [object]$Result = $null,
    [string]$ErrorText = $null
  )
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $task = $null
  for ($i = 0; $i -lt @($queue.tasks).Count; $i++) {
    if ([string]$queue.tasks[$i].id -eq $TaskId) { $task = $queue.tasks[$i]; break }
  }
  if (-not $task) { throw "Task not found: $TaskId" }
  $now = (Get-Date).ToString("o")
  $task.status = $Status
  if ($Status -eq "in_flight") { $task.started_at = $now }
  if ($Status -in @("completed", "failed", "cancelled", "blocked")) {
    $task.finished_at = $now
    if ($Status -eq "completed" -and $Result) { $task.result = $Result }
    if ($Status -eq "failed" -and $ErrorText) { $task.error = $ErrorText }
  }
  Save-TaskQueue -ProjectRoot $ProjectRoot -Queue $queue
  $event = "task." + $Status
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "system" -ActorId "system" -ActorRole "task" -Event $event -Message "Görev durumu: $TaskId -> $Status" -Ref ([ordered]@{ task_id = $TaskId })
  return $task
}

function Attach-AgentRunToTask {
  param([string]$ProjectRoot, [string]$TaskId, [string]$RunId)
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $task = @($queue.tasks | Where-Object { [string]$_.id -eq $TaskId } | Select-Object -First 1)[0]
  if (-not $task) { throw "Task not found: $TaskId" }
  $task.run_id = $RunId
  Save-TaskQueue -ProjectRoot $ProjectRoot -Queue $queue
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "system" -ActorId "system" -ActorRole "runner" -Event "task.run_attached" -Message "?al??ma kayd? ba?land?: $TaskId -> $RunId" -Ref ([ordered]@{ task_id = $TaskId; run_id = $RunId })
  return $task
}

function Register-TaskAttempt {
  param([string]$ProjectRoot, [string]$TaskId)
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $task = @($queue.tasks | Where-Object { [string]$_.id -eq $TaskId } | Select-Object -First 1)[0]
  if (-not $task) { throw "Task not found: $TaskId" }
  $attempts = [int]$task.attempts
  $maxAttempts = if ([int]$task.max_attempts -gt 0) { [int]$task.max_attempts } else { 2 }
  if ($attempts -ge $maxAttempts) { throw "Retry limit reached for $TaskId ($attempts/$maxAttempts)." }
  $task.attempts = $attempts + 1
  $task.error = $null
  Save-TaskQueue -ProjectRoot $ProjectRoot -Queue $queue
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "system" -ActorId "system" -ActorRole "runner" -Event "task.attempted" -Message "Task attempt $($task.attempts)/${maxAttempts}: $TaskId" -Ref ([ordered]@{ task_id = $TaskId; attempt = $task.attempts; max_attempts = $maxAttempts })
  return $task
}

function Register-TaskAttempt {
  param([string]$ProjectRoot, [string]$TaskId)
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $task = @($queue.tasks | Where-Object { [string]$_.id -eq $TaskId } | Select-Object -First 1)[0]
  if (-not $task) { throw "Task not found: $TaskId" }
  $attempts = [int]$task.attempts
  $maxAttempts = if ([int]$task.max_attempts -gt 0) { [int]$task.max_attempts } else { 2 }
  if ($attempts -ge $maxAttempts) { throw "Retry limit reached for $TaskId ($attempts/$maxAttempts)." }
  $task.attempts = $attempts + 1
  $task.error = $null
  Save-TaskQueue -ProjectRoot $ProjectRoot -Queue $queue
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "system" -ActorId "system" -ActorRole "runner" -Event "task.attempted" -Message "Task attempt $($task.attempts)/${maxAttempts}: $TaskId" -Ref ([ordered]@{ task_id = $TaskId; attempt = $task.attempts; max_attempts = $maxAttempts })
  return $task
}

function Approve-TaskItem {
  param(
    [string]$ProjectRoot,
    [string]$TaskId,
    [string]$Approval = "approved",
    [string]$By = "Yazar"
  )
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $task = $null
  for ($i = 0; $i -lt @($queue.tasks).Count; $i++) {
    if ([string]$queue.tasks[$i].id -eq $TaskId) { $task = $queue.tasks[$i]; break }
  }
  if (-not $task) { throw "Task not found: $TaskId" }
  $task.approval = [ordered]@{
    status = if ($Approval -eq "approved") { "approved" } else { "denied" }
    by = $By
    at = (Get-Date).ToString("o")
  }
  Save-TaskQueue -ProjectRoot $ProjectRoot -Queue $queue
  $event = if ($Approval -eq "approved") { "task.approved" } else { "task.rejected" }
  $msg = if ($Approval -eq "approved") { "Görev onaylandı: $TaskId ($By)" } else { "Görev reddedildi: $TaskId ($By)" }
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "human" -ActorId $By -ActorRole "author" -Event $event -Message $msg -Ref ([ordered]@{ task_id = $TaskId })

  if ($Approval -eq "approved") {
    $proposals = Evaluate-TaskTriggers -ProjectRoot $ProjectRoot -EventName "approval.granted" -Approval $task.phase
    return [ordered]@{ ok = $true; task = $task; triggered = $proposals }
  }
  return [ordered]@{ ok = $true; task = $task; triggered = @() }
}

function Cancel-TaskItem {
  param(
    [string]$ProjectRoot,
    [string]$TaskId,
    [string]$By = "Yazar"
  )
  $task = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "cancelled"
  $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "human" -ActorId $By -ActorRole "author" -Event "task.cancelled" -Message "Görev iptal edildi: $TaskId ($By)" -Ref ([ordered]@{ task_id = $TaskId })
  return [ordered]@{ ok = $true; task = $task }
}

function Resolve-TaskMentions {
  param([string]$Text)
  $matches = [regex]::Matches($Text, "@([A-Za-z0-9_-]+)")
  $names = New-Object System.Collections.Generic.List[string]
  foreach ($m in $matches) {
    $n = $m.Groups[1].Value.ToLowerInvariant()
    if (-not $names.Contains($n)) { [void]$names.Add($n) }
  }
  return @($names)
}

function Evaluate-TaskTriggers {
  param(
    [string]$ProjectRoot,
    [string]$EventName,
    [string]$Phase = $null,
    [string]$Agent = $null,
    [string]$Episode = $null,
    [string]$Approval = $null
  )
  $triggers = Get-TaskTriggers -ProjectRoot $ProjectRoot
  if (-not $triggers.enabled) { return @() }
  $proposals = @()
  foreach ($rule in @($triggers.rules)) {
    if (-not $rule.enabled) { continue }
    if ([string]$rule.on -ne $EventName) { continue }
    $matchOk = $true
    if ($rule.match) {
      if ($rule.match.phase -and ([string]$rule.match.phase -ne $Phase)) { $matchOk = $false }
      if ($rule.match.agent -and ([string]$rule.match.agent -ne $Agent)) { $matchOk = $false }
      if ($rule.match.approval -and ([string]$rule.match.approval -ne $Approval)) { $matchOk = $false }
      if ($rule.match.episode_pattern -and $Episode) {
        $pat = [string]$rule.match.episode_pattern
        if (-not ($Episode -like $pat)) { $matchOk = $false }
      }
    }
    if (-not $matchOk) { continue }
    if ($rule.action.create_task) {
      $ct = $rule.action.create_task
      $newTask = New-TaskItem -ProjectRoot $ProjectRoot -Agent ([string]$ct.agent) -Title ([string]$ct.title) -Phase ([string]$ct.phase) -Scope ([ordered]@{ kind = "phase"; phase = $Phase }) -Source "trigger"
      $proposals += [ordered]@{ rule_id = $rule.id; action = "create_task"; task = $newTask }
    }
    elseif ($rule.action.run_phase) {
      $proposals += [ordered]@{ rule_id = $rule.id; action = "run_phase"; phase = [string]$rule.action.run_phase }
      $null = Add-TaskFeedEntry -ProjectRoot $ProjectRoot -ActorType "system" -ActorId "system" -ActorRole "trigger" -Event "approval.requested" -Message ("Tetikleyici önerisi: '" + [string]$rule.action.run_phase + "' fazı başlatılsın mı?") -Ref ([ordered]@{ phase = [string]$rule.action.run_phase })
    }
  }
  return $proposals
}

function Get-TaskSummary {
  param([string]$ProjectRoot)
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $feed = Get-TaskFeed -ProjectRoot $ProjectRoot
  $tasks = @($queue.tasks)
  $counts = [ordered]@{ pending = 0; in_flight = 0; completed = 0; failed = 0; cancelled = 0; blocked = 0 }
  foreach ($t in $tasks) {
    $s = [string]$t.status
    if ($counts.Contains($s)) { $counts[$s] = [int]$counts[$s] + 1 }
  }
  $feedEntries = @($feed.entries)
  $lastEntries = if ($feedEntries.Count -gt 20) { @($feedEntries | Select-Object -Skip ($feedEntries.Count - 20)) } else { $feedEntries }
  $runs = @()
  $runDir = Get-AgentRunDir -ProjectRoot $ProjectRoot
  if (Test-Path -LiteralPath $runDir -PathType Container) {
    foreach ($runFile in @(Get-ChildItem -LiteralPath $runDir -Filter "*.json" -File | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 30)) {
      $run = Read-TaskJsonFile -Path $runFile.FullName
      if ($run) { $runs += $run }
    }
  }
  return [ordered]@{
    ok = $true
    task_counts = $counts
    tasks = $tasks
    feed = $lastEntries
    agents = (Get-TaskAgentIdentities -ProjectRoot $ProjectRoot)
    triggers_enabled = ([bool](Get-TaskTriggers -ProjectRoot $ProjectRoot).enabled)
    runs = $runs
  }
}
