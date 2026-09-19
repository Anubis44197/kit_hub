# KitHub - paylasilan MCP stdio istemci yardimcilari (dot-source edilir).
#
# Neden var: codebase-memory-mcp once bir "daemon" sureci baslatir ve stdio'yu
# ona aktarir. Peek() ile yoklama yapan eski yaklasim ikinci yaniti (tools/list)
# kaciriyordu; bu yuzden tum ciktilar OLAY TABANLI (BeginOutputReadLine) okunur.
#
# Kullanim:
#   . (Join-Path $PSScriptRoot 'lib_mcp_stdio.ps1')
#   $s = New-McpSession -Binary $exe -CacheDir $cache -WorkingDirectory $repo
#   $r = Invoke-Mcp -Session $s -Id 2 -Method 'tools/list'
#   Close-McpSession -Session $s

function New-McpSession {
  param(
    [Parameter(Mandatory)][string]$Binary,
    [string]$CacheDir = "",
    [string]$WorkingDirectory = "",
    [int]$InitTimeoutSeconds = 90,
    [string]$ClientName = "kithub-mcp-client"
  )

  if (-not (Test-Path -LiteralPath $Binary -PathType Leaf)) { throw "Binary not found: $Binary" }
  if ($CacheDir) {
    New-Item -ItemType Directory -Path $CacheDir -Force | Out-Null
    $env:CBM_CACHE_DIR = (Resolve-Path -LiteralPath $CacheDir).Path
  }

  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = (Resolve-Path -LiteralPath $Binary).Path
  $psi.Arguments = ""
  $psi.UseShellExecute = $false
  if ($WorkingDirectory) { $psi.WorkingDirectory = $WorkingDirectory }
  $psi.RedirectStandardInput = $true
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $psi

  $session = [pscustomobject]@{
    Binary    = (Resolve-Path -LiteralPath $Binary).Path
    Process   = $process
    OutQueue  = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
    ErrQueue  = New-Object System.Collections.Concurrent.ConcurrentQueue[string]
    Lines     = New-Object System.Collections.Generic.List[string]
    Stderr    = New-Object System.Collections.Generic.List[string]
    InitMs    = -1
    Version   = ""
    Subscribers = @()
    Sw        = [System.Diagnostics.Stopwatch]::StartNew()
  }

  $session.Subscribers = @(
    (Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($EventArgs.Data) { $Event.MessageData.Enqueue($EventArgs.Data) }
      } -MessageData $session.OutQueue),
    (Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) { $Event.MessageData.Enqueue($EventArgs.Data) }
      } -MessageData $session.ErrQueue)
  ) | ForEach-Object { $_ }

  [void]$process.Start()
  $process.BeginOutputReadLine()
  $process.BeginErrorReadLine()

  $init = @{
    jsonrpc = '2.0'
    id      = 1
    method  = 'initialize'
    params  = @{
      protocolVersion = '2024-11-05'
      capabilities    = @{}
      clientInfo      = @{ name = $ClientName; version = '0.1' }
    }
  }
  $session.Process.StandardInput.WriteLine(($init | ConvertTo-Json -Depth 8 -Compress))
  $session.Process.StandardInput.Flush()

  $initMsg = Wait-McpResponse -Session $session -Id 1 -TimeoutSeconds $InitTimeoutSeconds
  $session.InitMs = [int]$session.Sw.Elapsed.TotalMilliseconds
  if ($initMsg -and $initMsg.result -and $initMsg.result.serverInfo) {
    $session.Version = [string]$initMsg.result.serverInfo.version
    $session.Process.StandardInput.WriteLine('{"jsonrpc":"2.0","method":"notifications/initialized"}')
    $session.Process.StandardInput.Flush()
  }
  return $session
}

function Read-McpPending {
  param([Parameter(Mandatory)]$Session)
  $line = $null
  while ($Session.OutQueue.TryDequeue([ref]$line)) { [void]$Session.Lines.Add($line) }
  while ($Session.ErrQueue.TryDequeue([ref]$line)) { [void]$Session.Stderr.Add($line) }
  return $Session.Lines
}

function Wait-McpResponse {
  param(
    [Parameter(Mandatory)]$Session,
    [Parameter(Mandatory)][int]$Id,
    [int]$TimeoutSeconds = 120
  )
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    foreach ($line in (Read-McpPending -Session $Session)) {
      try { $msg = $line | ConvertFrom-Json } catch { continue }
      if ($msg.id -eq $Id) { return $msg }
    }
    if ($Session.Process.HasExited) { return $null }
    Start-Sleep -Milliseconds 100
  }
  return $null
}

function Invoke-Mcp {
  param(
    [Parameter(Mandatory)]$Session,
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][string]$Method,
    $Params = $null,
    [int]$TimeoutSeconds = 120
  )
  $req = @{ jsonrpc = '2.0'; id = $Id; method = $Method }
  if ($null -ne $Params) { $req.params = $Params }
  $Session.Process.StandardInput.WriteLine(($req | ConvertTo-Json -Depth 20 -Compress))
  $Session.Process.StandardInput.Flush()
  return (Wait-McpResponse -Session $Session -Id $Id -TimeoutSeconds $TimeoutSeconds)
}

function Invoke-McpTool {
  param(
    [Parameter(Mandatory)]$Session,
    [Parameter(Mandatory)][int]$Id,
    [Parameter(Mandatory)][string]$Name,
    $Arguments = $null,
    [int]$TimeoutSeconds = 240
  )
  $params = @{ name = $Name }
  if ($null -ne $Arguments) { $params.arguments = $Arguments }
  $resp = Invoke-Mcp -Session $Session -Id $Id -Method 'tools/call' -Params $params -TimeoutSeconds $TimeoutSeconds
  if ($null -eq $resp) { return $null }
  $text = ""
  if ($resp.result -and $resp.result.content) {
    $text = (@($resp.result.content | ForEach-Object { $_.text }) -join "`n")
  }
  return [pscustomobject]@{
    Raw     = $resp
    IsError = [bool]$resp.result.isError
    Text    = $text
  }
}

function Get-McpStderr {
  param([Parameter(Mandatory)]$Session)
  [void](Read-McpPending -Session $Session)
  return ($Session.Stderr -join "`n")
}

function Close-McpSession {
  param([Parameter(Mandatory)]$Session)
  try { $Session.Process.CancelOutputRead() } catch {}
  try { $Session.Process.CancelErrorRead() } catch {}
  try { $Session.Process.Kill() } catch {}
  foreach ($sub in @($Session.Subscribers)) {
    try { Unregister-Event -SourceIdentifier $sub.Name -ErrorAction SilentlyContinue } catch {}
  }
  Start-Sleep -Milliseconds 200
}
