param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [string]$RunId
)

$ErrorActionPreference = "Stop"

function Write-Utf8Bom {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($true))
}

function Assert-InProjectRoot {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd("\") + "\"
  $targetFull = [System.IO.Path]::GetFullPath($Path)
  if (-not ($targetFull.StartsWith($rootFull, [System.StringComparison]::OrdinalIgnoreCase))) {
    throw "Provider phase refused project-external path: $targetFull"
  }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$markerPath = Join-Path $ProjectRoot ".kithub-project.json"
if (-not (Test-Path -LiteralPath $markerPath -PathType Leaf)) {
  throw "Provider phase must run inside a KitHub project created by scripts/new_project.ps1."
}

$promptDir = Join-Path $ProjectRoot "runtime/provider-prompts"
$promptPath = Join-Path $promptDir ("{0}_{1}.md" -f $RunId, $Phase)
$phasePrompt = @"
# KitHub Provider Phase

run_id: $RunId
phase: $Phase
project_root: $ProjectRoot

You are running KitHub in automatic provider mode. Produce the exact artifacts required by:
- runtime/phase-contracts/$Phase.json
- runtime/agent-registry.json
- runtime/agent-status-contract.json
- skills for this phase

Rules:
- Load required state files before writing.
- Follow agent_sequence exactly.
- Write only allowed output roots for the phase.
- Emit runtime/agent-compliance/$Phase.json with concrete agent evidence.
- For create/polish/rewrite, update all required state ledgers.
- For export, do not invent missing manuscript, front matter, cover, or publication data.
- Never claim official TDK/web/source research without source artifacts.
- Never mark the book complete while length fulfillment, chapter coverage, or export gates are under target.

When using direct API mode, return only strict JSON:
{
  "files": [
    { "path": "relative/path/inside/project.ext", "content": "file content" }
  ]
}
No markdown fences. No commentary outside JSON.
"@
Write-Utf8Bom -Path $promptPath -Content $phasePrompt
Assert-InProjectRoot -Root $ProjectRoot -Path $promptPath

function Get-ChatTextFromResponse {
  param([object]$Response, [string]$Provider)
  if ($Provider -eq "anthropic") {
    return (@($Response.content) | ForEach-Object { [string]$_.text }) -join "`n"
  }
  if ($Provider -eq "gemini") {
    return (@($Response.candidates[0].content.parts) | ForEach-Object { [string]$_.text }) -join "`n"
  }
  return [string]$Response.choices[0].message.content
}

function Invoke-DirectProviderApi {
  param([string]$Prompt)
  $provider = if ($env:KITHUB_API_PROVIDER) { [string]$env:KITHUB_API_PROVIDER } else { "openai" }
  $model = [string]$env:KITHUB_API_MODEL
  $apiKey = [string]$env:KITHUB_API_KEY
  $baseUrl = [string]$env:KITHUB_API_BASE_URL
  if (-not $model.Trim()) { throw "Provider phase blocked: KITHUB_API_MODEL is not set." }
  if (-not $apiKey.Trim()) { throw "Provider phase blocked: KITHUB_API_KEY is not set." }

  if (-not $baseUrl.Trim()) {
    if ($provider -eq "anthropic") { $baseUrl = "https://api.anthropic.com/v1/messages" }
    elseif ($provider -eq "gemini") { $baseUrl = "https://generativelanguage.googleapis.com/v1beta" }
    elseif ($provider -eq "openrouter") { $baseUrl = "https://openrouter.ai/api/v1/chat/completions" }
    else { $baseUrl = "https://api.openai.com/v1/chat/completions" }
  }

  if ($provider -eq "anthropic") {
    $headers = @{ "x-api-key" = $apiKey; "anthropic-version" = "2023-06-01"; "content-type" = "application/json" }
    $body = @{ model = $model; max_tokens = 8192; messages = @(@{ role = "user"; content = $Prompt }) } | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method Post -Uri $baseUrl -Headers $headers -Body $body
  }
  if ($provider -eq "gemini") {
    $uri = "$($baseUrl.TrimEnd('/'))/models/$model`:generateContent?key=$apiKey"
    $body = @{ contents = @(@{ parts = @(@{ text = $Prompt }) }) } | ConvertTo-Json -Depth 20
    return Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Body $body
  }

  $headers = @{ Authorization = "Bearer $apiKey"; "content-type" = "application/json" }
  if ($provider -eq "openrouter") {
    $headers["HTTP-Referer"] = "http://127.0.0.1:8765"
    $headers["X-Title"] = "KitHub Studio"
  }
  $body = @{
    model = $model
    temperature = 0.35
    messages = @(
      @{ role = "system"; content = "You are a KitHub phase agent. Return only strict JSON that the runner can parse." },
      @{ role = "user"; content = $Prompt }
    )
  } | ConvertTo-Json -Depth 20
  return Invoke-RestMethod -Method Post -Uri $baseUrl -Headers $headers -Body $body
}

function Write-ProviderFileMap {
  param([string]$JsonText)
  $clean = $JsonText.Trim()
  $clean = $clean -replace "^\s*```(?:json)?\s*", ""
  $clean = $clean -replace "\s*```\s*$", ""
  $obj = $clean | ConvertFrom-Json
  if (-not $obj.files) { throw "Provider API response missing files array." }
  foreach ($file in @($obj.files)) {
    $rel = ([string]$file.path).Replace("/", "\").TrimStart("\")
    if (-not $rel.Trim()) { throw "Provider API response included empty file path." }
    $target = Join-Path $ProjectRoot $rel
    Assert-InProjectRoot -Root $ProjectRoot -Path $target
    Write-Utf8Bom -Path $target -Content ([string]$file.content)
  }
}

$providerArgsTemplate = [string]$env:KITHUB_PROVIDER_ARGS
if (-not $providerArgsTemplate.Trim()) {
  $providerArgsTemplate = "--project-root `"{project_root}`" --phase {phase} --run-id `"{run_id}`" --prompt-file `"{prompt_file}`""
}

$providerArgs = $providerArgsTemplate.Replace("{project_root}", $ProjectRoot).Replace("{phase}", $Phase).Replace("{run_id}", $RunId).Replace("{prompt_file}", $promptPath)

$logDir = Join-Path $ProjectRoot "runtime/provider-logs"
$logPath = Join-Path $logDir ("{0}_{1}.log" -f $RunId, $Phase)
if (-not (Test-Path -LiteralPath $logDir -PathType Container)) {
  New-Item -ItemType Directory -Path $logDir | Out-Null
}

$providerExe = [string]$env:KITHUB_PROVIDER_EXE
if (-not $providerExe.Trim()) {
  Write-Host "[provider-phase] executing direct API provider for phase=$Phase"
  Write-Host "[provider-phase] prompt: $promptPath"
  $response = Invoke-DirectProviderApi -Prompt $phasePrompt
  $providerText = Get-ChatTextFromResponse -Response $response -Provider ([string]$env:KITHUB_API_PROVIDER)
  Write-Utf8Bom -Path $logPath -Content $providerText
  Write-ProviderFileMap -JsonText $providerText
  Write-Host "[provider-phase] completed direct API phase=$Phase log=$logPath"
  exit 0
}

Write-Host "[provider-phase] executing provider for phase=$Phase"
Write-Host "[provider-phase] prompt: $promptPath"

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $providerExe
$psi.Arguments = $providerArgs
$psi.WorkingDirectory = $ProjectRoot
$psi.UseShellExecute = $false
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$process = [System.Diagnostics.Process]::Start($psi)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()
Write-Utf8Bom -Path $logPath -Content ("STDOUT:`r`n$stdout`r`n`r`nSTDERR:`r`n$stderr")

if ($process.ExitCode -ne 0) {
  throw "Provider phase failed for '$Phase' with exit code $($process.ExitCode). See $logPath"
}

Write-Host "[provider-phase] completed phase=$Phase log=$logPath"
