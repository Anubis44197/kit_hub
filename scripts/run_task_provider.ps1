param(
  [Parameter(Mandatory = $true)][string]$ProviderScript,
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$Phase,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$TaskId
)

$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "task_engine.ps1")

try {
  # Provider ayrı bir alt süreçte çalışır; provider_phase.ps1'in exit kodları
  # bu süreci sonlandırmadan verifier'ın çalışmasına izin vermelidir.
  & powershell -NoProfile -ExecutionPolicy Bypass -File $ProviderScript -ProjectRoot $ProjectRoot -Phase $Phase -RunId $RunId -TaskId $TaskId
  $exitCode = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
  if ($exitCode -ne 0) { throw "Provider process exited with code $exitCode." }
  # Not: verifier ve snapshot AYRI alt süreçte çağrılmalı; onların exit kodları bu süreci
  # sonlandırır (PowerShell'de içteki script'in exit'i tüm süreci bitirir) ve sonraki
  # adımlar (Update-AgentRun) hiç çalışmaz.
  $verifier = Join-Path $PSScriptRoot "verify_agent_run.ps1"
  & powershell -NoProfile -ExecutionPolicy Bypass -File $verifier -ProjectRoot $ProjectRoot -RunId $RunId -Phase $Phase -TaskId $TaskId | Out-Null
  $verifierExit = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
  if ($verifierExit -ne 0) { throw "Independent verifier returned revision_required (exit=$verifierExit)." }

  # Observer snapshot (fail-open): her koşudan kullanım/durum kanıtı; hata görevi asla etkilemez.
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "capture_observer_snapshot.ps1") -ProjectRoot $ProjectRoot -RunId $RunId -Phase $Phase -TaskId $TaskId | Out-Null
  } catch { Write-Host "[runner] observer snapshot atlandi: $($_.Exception.Message)" }

  # Hafıza kaydı: başarılı koşudan schema-uyumlu verification kaydı. Şema ihlali (exit 2)
  # görevi düşürmez; kanıt kaybı olarak loglanır.
  $memoryScript = Join-Path $PSScriptRoot "save_memory_record.ps1"
  $verificationFile = Join-Path $ProjectRoot ("runtime/agent-runs/{0}/verification.json" -f $RunId)
  & powershell -NoProfile -ExecutionPolicy Bypass -File $memoryScript -ProjectRoot $ProjectRoot -RunId $RunId -TaskId $TaskId -Phase $Phase -VerificationPath $verificationFile | Out-Null
  $memoryExit = if ($LASTEXITCODE -is [int]) { $LASTEXITCODE } else { 0 }
  if ($memoryExit -ne 0) { Write-Host "[runner] uyari: hafıza kaydi yazilamadi (exit=$memoryExit) - kanit kaybi, gorev etkilenmedi." }

  # Hikâye durum kaydı (story_state): bölüm arttıkça karakter/olay/süreklilik özetini hafızaya tası
  # (fail-open; hata görevi asla etkilemez).
  try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "save_story_state_record.ps1") -ProjectRoot $ProjectRoot -RunId $RunId -TaskId $TaskId -Phase $Phase | Out-Null
  } catch { Write-Host "[runner] story-state kaydi atlandi: $($_.Exception.Message)" }

  $null = Update-AgentRun -ProjectRoot $ProjectRoot -RunId $RunId -Status "completed" -ExitCode 0
  exit 0
}
catch {
  $message = $_.Exception.Message
  $null = Update-AgentRun -ProjectRoot $ProjectRoot -RunId $RunId -Status "failed" -ExitCode 1 -ErrorText $message
  exit 1
}
