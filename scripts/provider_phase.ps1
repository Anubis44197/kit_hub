param(
  [string]$ProjectRoot = (Get-Location).Path,
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [string]$RunId,
  [string]$TaskId = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "book_contract.ps1")

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
$bookRequestPath = Join-Path $ProjectRoot "runtime/book-request.md"
$bookRequestText = if (Test-Path -LiteralPath $bookRequestPath -PathType Leaf) { [System.IO.File]::ReadAllText($bookRequestPath, [System.Text.Encoding]::UTF8).Trim() } else { "" }
$bookContractPath = Join-Path $ProjectRoot "runtime/book-contract.json"
$bookContract = if (Test-Path -LiteralPath $bookContractPath -PathType Leaf) { [System.IO.File]::ReadAllText($bookContractPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json } elseif ($bookRequestText) { Save-KitHubBookContract -ProjectRoot $ProjectRoot -Text $bookRequestText -RunId $RunId } else { $null }
$bookContractJson = if ($bookContract) { $bookContract | ConvertTo-Json -Depth 20 } else { "{}" }

# --- Görev modu (task_engine ile entegrasyon) ---
$isTaskMode = -not [string]::IsNullOrWhiteSpace($TaskId)
$script:TaskWrittenPaths = @()
$script:TaskDroppedPaths = @()
$script:PhaseAllowedPatterns = @()
$taskHeader = ""
$taskArtifactHint = ""
if ($isTaskMode) {
  . (Join-Path $PSScriptRoot "task_engine.ps1")
  $queue = Get-TaskQueue -ProjectRoot $ProjectRoot
  $foundTask = $null
  foreach ($t in @($queue.tasks)) { if ([string]$t.id -eq $TaskId) { $foundTask = $t; break } }
  if (-not $foundTask) { throw "Task not found in task-queue.json: $TaskId" }
  $taskAgent = [string]$foundTask.agent
  $taskTitle = [string]$foundTask.title
  $taskScope = ""
  $taskEpisode = ""
  if ($foundTask.scope) {
    if ($foundTask.scope.episode) { $taskEpisode = [string]$foundTask.scope.episode; $taskScope = "episode: $taskEpisode" }
    elseif ($foundTask.scope.kind -eq "phase") { $taskScope = "phase: $([string]$foundTask.scope.phase)" }
    else { $taskScope = [string]$foundTask.scope.kind }
  }
  if (-not $Phase.Trim()) { $Phase = [string]$foundTask.phase }
  if (-not $RunId.Trim()) { $RunId = "task-$TaskId" }
  try {
    $pcScopePath = Join-Path $ProjectRoot ("runtime/phase-contracts/{0}.json" -f $Phase)
    if (Test-Path -LiteralPath $pcScopePath -PathType Leaf) {
      $pcScope = [System.IO.File]::ReadAllText($pcScopePath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
      $script:PhaseAllowedPatterns = @($pcScope.allowed_output_patterns | Where-Object { $_ })
    }
  } catch { $script:PhaseAllowedPatterns = @() }
  # Few-shot ornek yolu: ilk izinli desenden somut bir dosya adi turet.
  $script:PhaseExamplePath = "_workspace/phase-deliverable.md"
  if (@($script:PhaseAllowedPatterns).Count -gt 0) {
    $p0 = [string]$script:PhaseAllowedPatterns[0]
    $example = $p0.Replace("*", "")
    if ($example -notmatch "/") { $example = "_workspace/" + $example.TrimStart("/") }
    $script:PhaseExamplePath = $example
  }
  $promptPath = Join-Path $promptDir ("{0}_{1}_{2}.md" -f $RunId, $Phase, $TaskId)
  $taskHeader = @"
task_id: $TaskId
agent_role: $taskAgent
task_title: $taskTitle
task_scope: $taskScope

GÖREV MODU: Yalnızca bu görevin kapsamındaki ürünü üret. Fazı bir bütün olarak yeniden üretme.
Ajan rolüne uygun davran: $taskAgent
"@
  if ($taskEpisode) { $taskArtifactHint = "Bu görevin kapsamı $taskEpisode dosyasıdır; çıktılarını bu dosya/raporlarla sınırlı tut." }
  $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "in_flight"
}

$contextPackText = "{}"
if ($RunId.Trim()) {
  $contextBuilder = Join-Path $PSScriptRoot "build_context_pack.ps1"
  $null = & $contextBuilder -ProjectRoot $ProjectRoot -RunId $RunId -Phase $Phase -Episode $taskEpisode
  $contextPath = Join-Path $ProjectRoot ("runtime/agent-runs/{0}/context-pack.json" -f $RunId)
  if (-not (Test-Path -LiteralPath $contextPath -PathType Leaf)) { throw "Context pack could not be created." }
  $contextPackFull = [System.IO.File]::ReadAllText($contextPath, [System.Text.Encoding]::UTF8)
  # Prompta kisaltilmis onizleme gir: buyuk ic ice JSON echo'larini ve kacis hatlarini azaltir.
  # Diskteki tam pack (dogrulama hash'leri icin) oldugu gibi kalir.
  try {
    $packObj = $contextPackFull | ConvertFrom-Json
    $displayFiles = @()
    foreach ($f in @($packObj.files)) {
      $c = [string]$f.content
      if ($c.Length -gt 1200) { $c = $c.Substring(0, 1200) + "`n...[preview truncated; full approved state lives at this path]" }
      $displayFiles += @{ path = [string]$f.path; sha256 = [string]$f.sha256; bytes = [int]$f.bytes; content_preview = $c }
    }
    $memoryPreview = @()
    foreach ($m in @($packObj.memory)) {
      if ($m -and [string]$m.summary) {
        $s = [string]$m.summary; if ($s.Length -gt 240) { $s = $s.Substring(0, 240) }
        $memoryPreview += @{ ts = [string]$m.ts; record_type = [string]$m.record_type; phase = [string]$m.phase; summary = $s }
      }
    }
    $contextPackText = @{ files = $displayFiles; memory = $memoryPreview } | ConvertTo-Json -Depth 6
  } catch { $contextPackText = $contextPackFull }
}
$phaseContractOutput = ""
$phaseContractPath = Join-Path $ProjectRoot ("runtime/phase-contracts/{0}.json" -f $Phase)
if (Test-Path -LiteralPath $phaseContractPath -PathType Leaf) {
  try {
    $pc = [System.IO.File]::ReadAllText($phaseContractPath, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
    $allowedPatterns = @($pc.allowed_output_patterns) | Where-Object { $_ }
    $deniedPatterns = @($pc.denied_output_patterns) | Where-Object { $_ }
    if ($allowedPatterns.Count) {
      $phaseContractOutput = (@"

## Output Policy (STRICT)

Allowed output path patterns for this run (write ONLY files matching these):
$($allowedPatterns | ForEach-Object { "- $_" })

Forbidden output paths:
$($deniedPatterns | ForEach-Object { "- $_" })

Any write outside the allowed list is rejected by KitHub and fails the task.

Phase scope: this run produces ONLY the phase deliverable(s) that match the allowed patterns.
Files named in writing_contract.required_planning_artifacts (for example character-state.json, plot-ledger.json) belong to LATER phases; do NOT create them in this run.
Produce one complete, self-contained document per deliverable: full Turkish content, proper headings, no placeholder text.
"@ -join "`n")
    }
  } catch { $phaseContractOutput = "" }
}

$phasePrompt = @"

# KitHub Provider Phase

run_id: $RunId
phase: $Phase
project_root: $ProjectRoot

$taskHeader
$taskArtifactHint

## User Book Request

The user-facing KitHub map has already converted the selections into runtime/book-request.md.
Treat this as the source of truth:

```text
$bookRequestText
```

## Writing Contract

runtime/book-contract.json contains the normalized writing family. Every AI output must obey it:

```json
$bookContractJson
```

## Approved Context Pack

The following JSON is the phase-scoped project state selected by KitHub. Use it as reference only; do not invent files or claim state not present in the pack.

```json
$contextPackText
```

You are running KitHub in automatic provider mode.

## Read-only references (NEVER write these files)
- runtime/phase-contracts/$Phase.json
- runtime/agent-registry.json
- runtime/agent-status-contract.json
- skills for this phase

Rules:
- Load required state files before writing.
- Follow agent_sequence exactly.
- Write only allowed output roots for the phase.
- Do NOT write runtime/agent-compliance files; the KitHub runner records phase evidence itself.
- Emit mandatory per-agent evidence reports when required by the phase: chief editor, domain researcher, and research citation auditor reports under revision/_workspace/.
- For create/polish/rewrite, update all required state ledgers.
- For export, do not invent missing manuscript, front matter, cover, or publication data.
- Never claim official TDK/web/source research without source artifacts.
- Never mark the book complete while length fulfillment, chapter coverage, or export gates are under target.
- Do not force novel-only assumptions on non-fiction, academic, article, instructional, report, screenplay, or poetry families.
- Use writing_contract.generation_rule and writing_contract.required_planning_artifacts as higher-priority planning rules than generic book defaults.
$phaseContractOutput

When using direct API mode, return only strict JSON:
{
  "files": [
    { "path": "relative/path/inside/project.ext", "content": "file content" }
  ]
}
No markdown fences. No commentary outside JSON.

## Response format example (structure only; write your own real content)

{
  "files": [
    {
      "path": "$($script:PhaseExamplePath)",
      "content": "# Kitap Önerileri\n\n## Öneri 1: Sifreli Defter\n\nDefne Aral, annesinin eski evinde sifreli bir defter bulur. Defterin sayfalari, ailenin yillardir sakladigi bir sirri isaret eder...\n\n## Öneri 2: Balat'ta Bir Mektup\n\nSahaf Rauf, Defne'ye 1998'de gonderilmis, hic acilmamis bir mektup verir. Mektup, annesinin genc ligine ve kayip bir kardese isaret eder...\n\n## Öneri 3: Cem'in Arsivi\n\nGazeteci Cem, Defne'ye profesyonel olarak yardim etmeyi teklif eder; ancak kendi gecmisinin de bu sirra bagli oldugunu saklar..."
    }
  ]
}

CRITICAL: every "content" field MUST contain real, substantive Turkish text (at least 500 characters per file). NEVER return empty strings, placeholders like "...", or summaries of files.
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
  $allowEmptyKey = ([string]$env:KITHUB_API_ALLOW_EMPTY_KEY).Trim() -eq "1"
  if (-not $model.Trim()) { throw "Provider phase blocked: KITHUB_API_MODEL is not set." }
  if (-not $apiKey.Trim() -and -not $allowEmptyKey) { throw "Provider phase blocked: KITHUB_API_KEY is not set. (Yerel model için KITHUB_API_ALLOW_EMPTY_KEY=1 ayarlayın.)" }

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

  $headers = @{ "content-type" = "application/json" }
  if ($apiKey.Trim()) { $headers["Authorization"] = "Bearer $apiKey" }
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
  $clean = ([string]$JsonText).Trim()
  $clean = $clean -replace "^\s*```(?:json)?\s*", ""
  $clean = $clean -replace "\s*```\s*$", ""
  $clean = $clean.Trim([char]0xFEFF)
  $obj = $null
  try { $obj = $clean | ConvertFrom-Json } catch { throw "Provider response is not valid JSON: $($_.Exception.Message)" }
  if (-not $obj.files) { throw "Provider API response missing files array." }
  # Once tum yollari dogrula, sonra yaz (yarim yazim olmadan retry mumkun olsun).
  $validated = @()
  foreach ($file in @($obj.files)) {
    $rel = ([string]$file.path).Replace("/", "\").TrimStart("\").Trim()
    if (-not $rel.Trim()) { throw "Provider API response included empty file path." }
    $target = Join-Path $ProjectRoot $rel
    Assert-InProjectRoot -Root $ProjectRoot -Path $target
    if ($isTaskMode) {
      $writeGuard = Join-Path $PSScriptRoot "assert_agent_write_root.ps1"
      $null = & $writeGuard -ProjectRoot $ProjectRoot -Agent $taskAgent -RelativePath $rel
    }
    # Faz kapsami yumusak kontrol: izinli desen disindaki dosyalar atilir, gorevi dusturmez.
    $relNorm = $rel -replace "\\", "/"
    if (@($script:PhaseAllowedPatterns).Count -gt 0 -and -not (@($script:PhaseAllowedPatterns | Where-Object { $relNorm -like $_ }).Count)) {
      $script:TaskDroppedPaths += $rel
      Write-Host "[provider-phase] dropped out-of-scope file: $rel"
      continue
    }
    $content = ([string]$file.content).TrimStart([char]0xFEFF)
    if ($content.Trim().Length -lt 64) {
      # Onemsiz icerik yazilmaz; bos/taslak dosya tek basina kurtarilamazsa gorev zaten duser.
      $script:TaskDroppedPaths += "$rel (trivial: $($content.Trim().Length) chars)"
      Write-Host "[provider-phase] dropped trivial file: $rel ($($content.Trim().Length) chars)"
      continue
    }
    $validated += @{ rel = $rel; target = $target; content = $content }
  }
  foreach ($v in $validated) {
    Write-Utf8Bom -Path $v.target -Content $v.content
    $script:TaskWrittenPaths += $v.rel
  }
  return @($validated).Count
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
  $maxAttempts = 2
  $correction = ""
  try {
    for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
      try {
        $response = Invoke-DirectProviderApi -Prompt ($phasePrompt + $correction)
        $providerText = Get-ChatTextFromResponse -Response $response -Provider ([string]$env:KITHUB_API_PROVIDER)
        Write-Utf8Bom -Path $logPath -Content $providerText
        $fileCount = Write-ProviderFileMap -JsonText $providerText
        break
      } catch {
        if ($attempt -ge $maxAttempts) { throw }
        $correction = "`n`nPREVIOUS ATTEMPT REJECTED: $($_.Exception.Message)`nReturn strict JSON again. Write ONLY files matching the allowed output patterns; never echo read-only state files as outputs."
        Write-Host "[provider-phase] attempt $attempt rejected, retrying with correction"
      }
    }
  } catch {
    if ($isTaskMode) { $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "failed" -ErrorText $_.Exception.Message }
    throw
  }
  if ($isTaskMode) {
    if (-not @($script:TaskWrittenPaths).Count) {
      $scopeError = "No in-scope artifacts were produced (dropped: $($script:TaskDroppedPaths -join ', '))."
      $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "failed" -ErrorText $scopeError
      throw $scopeError
    }
    # Runner otoritesi: faz kanıtı ajanın write-root kısıtlarına tabi değildir.
    $compliancePath = Join-Path $ProjectRoot ("runtime/agent-compliance/{0}.json" -f $Phase)
    $evidence = @()
    foreach ($rel in @($script:TaskWrittenPaths)) {
      $absPath = Join-Path $ProjectRoot ($rel -replace "/", "\")
      $evidence += @{ path = $rel; sha256 = (Get-FileHash -LiteralPath $absPath -Algorithm SHA256).Hash.ToLowerInvariant() }
    }
    $compliance = [ordered]@{
      run_id = $RunId
      phase = $Phase
      task_id = $TaskId
      task_agent = $taskAgent
      agents_executed = @($taskAgent)
      produced_files = @($script:TaskWrittenPaths)
      dropped_out_of_scope_files = @($script:TaskDroppedPaths)
      evidence_files = $evidence
      written_at = (Get-Date).ToString("o")
    }
    Write-Utf8Bom -Path $compliancePath -Content ($compliance | ConvertTo-Json -Depth 10)
    $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "completed" -Result ([ordered]@{ summary = "Görev tamamlandı: $fileCount dosya yazıldı."; verdict = $null; issues = $null; artifacts = @($script:TaskWrittenPaths) })
    Write-Host "[provider-phase] task completed: $TaskId"
  }
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
  if ($isTaskMode) { $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "failed" -ErrorText "Provider exit code $($process.ExitCode). See $logPath" }
  throw "Provider phase failed for '$Phase' with exit code $($process.ExitCode). See $logPath"
}
if ($isTaskMode) {
  $null = Set-TaskStatus -ProjectRoot $ProjectRoot -TaskId $TaskId -Status "completed" -Result ([ordered]@{ summary = "Görev tamamlandı (provider)."; verdict = $null; issues = $null; artifacts = @() })
  Write-Host "[provider-phase] task completed: $TaskId"
}

Write-Host "[provider-phase] completed phase=$Phase log=$logPath"
