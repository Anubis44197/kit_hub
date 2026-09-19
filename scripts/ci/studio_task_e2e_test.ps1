param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [string]$Provider = "ollama",
  [string]$Model = "qwen2.5:3b",
  [string]$BaseUrl = "http://127.0.0.1:11434/v1/chat/completions",
  [string]$Phase = "propose",
  [int]$TimeoutSeconds = 420
)

# Uctan uca senaryo:
#   canli bridge -> new project marker -> save-book-request -> task-create -> task-run
#   -> provider (direct API, local model) -> dosya yazimi -> verifier -> task completed
# Windows PowerShell 5.1 uyumlu; fixture ASCII-only tutuldu.

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$bridgeScript = Join-Path $RepoRoot "scripts/studio_bridge.ps1"
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) { throw "studio_bridge.ps1 not found: $bridgeScript" }

function Invoke-StudioJson {
  param([string]$Path, [string]$Method = "GET", [object]$Body = $null, [string]$SessionToken = "", [int]$TimeoutSec = 30)
  $headers = @{ Origin = "http://127.0.0.1:$script:Port" }
  if ($SessionToken) { $headers["X-KitHub-Session"] = $SessionToken }
  $request = @{
    Uri = "http://127.0.0.1:$script:Port$Path"
    Method = $Method
    Headers = $headers
    UseBasicParsing = $true
    TimeoutSec = $TimeoutSec
  }
  if ($null -ne $Body) {
    $request.ContentType = "application/json; charset=utf-8"
    $request.Body = [System.Text.Encoding]::UTF8.GetBytes(($Body | ConvertTo-Json -Depth 10))
  }
  return Invoke-WebRequest @request
}

$portProbe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$portProbe.Start()
$script:Port = ([System.Net.IPEndPoint]$portProbe.LocalEndpoint).Port
$portProbe.Stop()

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("kithub-e2e-" + [guid]::NewGuid().ToString("N"))
$bridgeOut = Join-Path $testRoot "bridge-out.log"
$bridgeErr = Join-Path $testRoot "bridge-err.log"
$providerSettingsPath = Join-Path $testRoot "provider-settings.json"
$bridgeProcess = $null

try {
  New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

  # 1) Izole KitHub proje isareti (new_project.ps1'in urettigi markerin eşlenigi)
  $utf8Bom = [System.Text.UTF8Encoding]::new($true)
  $marker = [ordered]@{
    schema_version = "1.0.0"
    project_name = "E2E Test Kitabi"
    project_slug = (Split-Path $testRoot -Leaf)
    project_root = $testRoot
    source_engine_root = $RepoRoot
    created_at = (Get-Date).ToString("o")
    status = "draft"
    policy = "e2e-test-project"
  }
  [System.IO.File]::WriteAllText((Join-Path $testRoot ".kithub-project.json"), ($marker | ConvertTo-Json -Depth 6), $utf8Bom)

  # 1b) Cekirdek runtime dosyalari (agent registry, faz sozlesmeleri, runner config)
  $runtimeDir = Join-Path $testRoot "runtime"
  New-Item -ItemType Directory -Path $runtimeDir -Force | Out-Null
  foreach ($rel in @("runtime/agent-registry.json", "runtime/agent-status-contract.json", "runtime/runner-config.template.json", "runtime/agent-identities.schema.json")) {
    $src = Join-Path $RepoRoot $rel
    if (Test-Path -LiteralPath $src) { Copy-Item -LiteralPath $src -Destination (Join-Path $runtimeDir (Split-Path $rel -Leaf)) -Force }
  }
  if (Test-Path (Join-Path $RepoRoot "runtime/adapters")) {
    # Adapter configleri de cekirdekle birlikte tasinir (observer snapshot bunlari okur).
    New-Item -ItemType Directory -Path (Join-Path $runtimeDir "adapters") -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot "runtime/adapters/*") -Destination (Join-Path $runtimeDir "adapters") -Recurse -Force
  }
  if (Test-Path (Join-Path $RepoRoot "runtime/memory/schema.json")) {
    # Hafıza sözleşmesi de cekirdekle tasinir (save_memory_record bunu okur).
    New-Item -ItemType Directory -Path (Join-Path $runtimeDir "memory") -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $RepoRoot "runtime/memory/schema.json") -Destination (Join-Path $runtimeDir "memory/schema.json") -Force
  }
  if (Test-Path (Join-Path $RepoRoot "runtime/phase-contracts")) {
    # Hedefi once olustur: yokken Copy-Item kaynak klasoru icine kopyalar (PS gotcha).
    New-Item -ItemType Directory -Path (Join-Path $runtimeDir "phase-contracts") -Force | Out-Null
    Copy-Item -Path (Join-Path $RepoRoot "runtime/phase-contracts/*") -Destination (Join-Path $runtimeDir "phase-contracts") -Recurse -Force
  }
  if (-not (Test-Path (Join-Path $runtimeDir "runner-config.json"))) {
    Copy-Item -LiteralPath (Join-Path $runtimeDir "runner-config.template.json") -Destination (Join-Path $runtimeDir "runner-config.json") -Force
  }

  # 2) Izole bridge baslat
  $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $startInfo.FileName = "powershell.exe"
  $startInfo.Arguments = @(
    "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$bridgeScript`"",
    "-RepoRoot", "`"$RepoRoot`"", "-Port", $script:Port,
    "-ProviderSettingsPath", "`"$providerSettingsPath`""
  ) -join " "
  $startInfo.WorkingDirectory = $RepoRoot
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $bridgeProcess = [System.Diagnostics.Process]::Start($startInfo)
  # Pipe buffer deadlock'unu onle: std ciktilari asenkron bosalt.
  $null = $bridgeProcess.StandardOutput.ReadToEndAsync()
  $null = $bridgeProcess.StandardError.ReadToEndAsync()

  $ready = $false
  for ($attempt = 0; $attempt -lt 60; $attempt++) {
    Start-Sleep -Milliseconds 400
    try {
      $health = Invoke-StudioJson -Path "/api/health" -TimeoutSec 3
      if ($health.StatusCode -eq 200) { $ready = $true; break }
    } catch {}
  }
  if (-not $ready) { throw "Bridge did not become ready on port $script:Port." }
  Write-Host "[e2e] bridge ready on port $script:Port"

  # 3) Session + izole provider ayarlari (yerel model: bos API anahtari kabul)
  $session = (Invoke-StudioJson -Path "/api/session").Content | ConvertFrom-Json
  if (-not $session.ok -or -not $session.token) { throw "Session token missing." }
  $settings = [ordered]@{
    provider = $Provider
    model = $Model
    baseUrl = $BaseUrl
    apiKeyProtected = ""
    updatedAt = (Get-Date).ToString("o")
  }
  [System.IO.File]::WriteAllText($providerSettingsPath, ($settings | ConvertTo-Json -Depth 6), $utf8Bom)
  Write-Host "[e2e] provider=$Provider model=$Model baseUrl=$BaseUrl"

  # 4) Gerekli alanlari iceren kitap istegi
  $requestText = @"
# Kitap Istegi

## Zorunlu Cevaplar
- Calisma adi: Sifreli Defter
- Yazar / imza: KitHub E2E
- Tur: Psikolojik gizem romani
- Cikti hedefi: Kitap dosyasi
- Yapi / plan sablonu: 3 Perde Yapisi
- Hedef sayfa: 24
- Hedef okur: Yetiskin psikolojik gizem okurlari
- Okur seviyesi: Yetiskin
- Kitap amaci: Psikolojik gizem romani icin tutarli plan olusturmak
- Konu: Sifreli bir defterin aile sirrini aciga cikarmasi.
- Karakterler: Defne Aral, sahaf Rauf, gazeteci Cem ve Nermin.
- Donem ve mekan: Gunumuz Istanbul'u; Beyoglu ve Balat.
- Anlatici: Ucuncu tekil sinirli, gecmis zaman.
- Final: Defne gercegi ogrenir ve annesiyle yuzlesir.
- Uslup: Edebi, akici ve psikolojik gerilim odakli.
- Sinirlar: Grafik siddet ve gercek kisi iddialari yok.
- Kaynak / gerceklik kurali: Gercek kisi iddiasi uretme
- Yayin paketi: A5 DOCX, baslik sayfasi, icindekiler ve kapak briefi.
"@
  $save = (Invoke-StudioJson -Path "/api/save-book-request" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $testRoot; text = $requestText }).Content | ConvertFrom-Json
  if (-not $save.ok) { throw "save-book-request failed." }
  Write-Host "[e2e] book request saved: family=$($save.writingFamily) words=$($save.words)"

  # 5) Gorev olustur (propose fazı, proposal-generator)
  $created = (Invoke-StudioJson -Path "/api/task-create" -Method "POST" -SessionToken $session.token -Body @{
    projectRoot = $testRoot
    agent = "proposal-generator"
    title = "E2E: kitap onerileri uret"
    phase = $Phase
    source = "e2e-test"
    requiresApproval = $false
  }).Content | ConvertFrom-Json
  if (-not $created.ok) { throw "task-create failed." }
  $taskId = $created.task.id
  Write-Host "[e2e] task created: $taskId"

  # 6) Gorevi kos
  $runResp = (Invoke-StudioJson -Path "/api/task-run" -Method "POST" -SessionToken $session.token -Body @{
    projectRoot = $testRoot
    taskId = $taskId
  }).Content | ConvertFrom-Json
  if (-not $runResp.ok -or -not $runResp.launched) { throw "task-run failed to launch." }
  $runId = $runResp.run.runId
  Write-Host "[e2e] run launched: $runId"

  # 7) Tamamlanmayi bekle
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  $taskState = $null
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 5
    $summary = (Invoke-StudioJson -Path "/api/task-summary" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $testRoot }).Content | ConvertFrom-Json
    $taskState = @($summary.tasks | Where-Object { $_.id -eq $taskId })[0]
    if (-not $taskState) { throw "Task disappeared from queue: $taskId" }
    Write-Host "[e2e] task status: $($taskState.status)"
    if ($taskState.status -in @("completed", "failed", "cancelled", "blocked")) { break }
  }
  if (-not $taskState) { throw "Task state could not be read." }

  $runJsonPath = Join-Path $testRoot "revision/_state/agent-runs/$runId.json"
  if (Test-Path $runJsonPath) {
    $runJson = [System.IO.File]::ReadAllText($runJsonPath) | ConvertFrom-Json
    Write-Host "[e2e] agent run status: $($runJson.status) exit=$($runJson.exitCode)"
    if ($runJson.error) { Write-Host "[e2e] run error: $($runJson.error)" }
  }
  $errLog = Join-Path $testRoot "runtime/provider-logs"
  if (Test-Path $errLog) {
    Get-ChildItem $errLog -Filter "*.err.log" | ForEach-Object {
      $tail = Get-Content $_.FullName -Tail 5 -ErrorAction SilentlyContinue
      if ($tail) { Write-Host "[e2e] $($_.Name) tail:"; $tail | ForEach-Object { Write-Host "  $_" } }
    }
  }

  if ($taskState.status -ne "completed") { throw "Task did not complete: status=$($taskState.status) error=$($taskState.error)" }

  # Runner son adimlarini (verifier -> observer snapshot -> Update-AgentRun) bekle:
  # provider gorevi completed yaptiginda runner hala bitiyor olabilir; yaris kosulunu kapat.
  $runJsonPathEarly = Join-Path $testRoot "revision/_state/agent-runs/$runId.json"
  $waited = 0
  while ($waited -lt 60) {
    if (Test-Path $runJsonPathEarly) {
      $rj = [System.IO.File]::ReadAllText($runJsonPathEarly) | ConvertFrom-Json
      if ($rj.status -in @("completed", "failed")) { break }
    }
    Start-Sleep -Seconds 1; $waited++
  }

  # 8) Cikti dogrulamalari
  # Izinli desenlerden birine uyan, anlamlı içerikli en az bir artifact uretilmis olmali.
  $allowedPatterns = @("_workspace/01_proposals*.md", "*_proposal.md", "runtime/approvals/story-choice.json")
  $workspaceDir = Join-Path $testRoot "_workspace"
  $artifacts = @()
  if (Test-Path $workspaceDir) { $artifacts += @(Get-ChildItem $workspaceDir -Recurse -File | ForEach-Object { @{ rel = $_.FullName.Substring($testRoot.Length).TrimStart("\").Replace("\", "/"); len = $_.Length } }) }
  $matched = @()
  foreach ($a in $artifacts) {
    $rel = [string]$a.rel
    $likeHit = @($allowedPatterns | Where-Object { $rel -like $_ })
    if ($likeHit.Count -gt 0) { $matched += $a }
  }
  if (-not $matched.Count) { throw "No artifact matching allowed patterns; produced: $($artifacts | ForEach-Object { $_.rel + "(" + $_.len + "B)" })" }
  $best = $matched | Sort-Object len -Descending | Select-Object -First 1
  if ($best.len -lt 64) { throw "Artifact too small ($($best.len) bytes): $($best.rel)" }
  Write-Host "[e2e] artifact: $($best.rel) ($($best.len) bytes)"

  $verificationPath = Join-Path $testRoot "runtime/agent-runs/$runId/verification.json"
  if (-not (Test-Path $verificationPath)) { throw "verification.json missing." }
  $verification = [System.IO.File]::ReadAllText($verificationPath) | ConvertFrom-Json
  if ($verification.verdict -ne "pass") { throw "Verifier verdict is $($verification.verdict): $($verification.reasons -join '; ')" }

  # Observer snapshot kaniti (fail-open zincirin ucu: gorev kousu iz birakmali)
  $observerPath = Join-Path $testRoot "runtime/agent-runs/$runId/observer.jsonl"
  if (-not (Test-Path $observerPath)) { throw "observer.jsonl missing (observer snapshot not wired)." }
  $observerRecords = @(Get-Content $observerPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
  if (-not (@($observerRecords | Where-Object { $_.kind -eq "status" }).Count)) { throw "observer.jsonl has no status record." }
  Write-Host "[e2e] observer snapshot: $($observerRecords.Count) kayit"

  # Hafıza kaydi kaniti (1. kosu): runner basarili kosudan schema-uyumlu kayit birakmali.
  $recordsPathE2E = Join-Path $testRoot "runtime/memory/records.jsonl"
  $recordsCount1 = 0
  if (Test-Path $recordsPathE2E) { $recordsCount1 = @(Get-Content $recordsPathE2E | Where-Object { $_.Trim() }).Count }
  if ($recordsCount1 -lt 1) { throw "memory record missing after first run (records.jsonl)." }
  Write-Host "[e2e] hafiza kaydi (1. kosu): $recordsCount1"

  $compliancePath = Join-Path $testRoot "runtime/agent-compliance/$Phase.json"
  if (-not (Test-Path $compliancePath)) { throw "Runner-written compliance evidence missing for phase $Phase." }
  $compliance = [System.IO.File]::ReadAllText($compliancePath) | ConvertFrom-Json
  if (-not $compliance.evidence_files -or @($compliance.evidence_files).Count -lt 1) { throw "Compliance evidence has no file hashes." }

  Write-Host "[e2e] verifier verdict: $($verification.verdict)"
  Write-Host "[e2e] compliance evidence files: $(@($compliance.evidence_files).Count)"

  # 9) Ikinci kosu: hafiza zinciri kaniti (2. kosu baglami 1. kosu kaydini tasmali)
  $created2 = (Invoke-StudioJson -Path "/api/task-create" -Method "POST" -SessionToken $session.token -Body @{
    projectRoot = $testRoot
    agent = "proposal-generator"
    title = "E2E: kitap onerileri uret (2)"
    phase = $Phase
    source = "e2e-test"
    requiresApproval = $false
  }).Content | ConvertFrom-Json
  if (-not $created2.ok) { throw "task-create(2) failed." }
  $taskId2 = $created2.task.id
  $runResp2 = (Invoke-StudioJson -Path "/api/task-run" -Method "POST" -SessionToken $session.token -Body @{
    projectRoot = $testRoot
    taskId = $taskId2
  }).Content | ConvertFrom-Json
  if (-not $runResp2.ok -or -not $runResp2.launched) { throw "task-run(2) failed to launch." }
  $runId2 = $runResp2.run.runId
  Write-Host "[e2e] run 2 launched: $runId2"

  $deadline2 = (Get-Date).AddSeconds($TimeoutSeconds)
  $taskState2 = $null
  while ((Get-Date) -lt $deadline2) {
    Start-Sleep -Seconds 5
    $summary2 = (Invoke-StudioJson -Path "/api/task-summary" -Method "POST" -SessionToken $session.token -Body @{ projectRoot = $testRoot }).Content | ConvertFrom-Json
    $taskState2 = @($summary2.tasks | Where-Object { $_.id -eq $taskId2 })[0]
    if (-not $taskState2) { throw "Task(2) disappeared from queue: $taskId2" }
    Write-Host "[e2e] task(2) status: $($taskState2.status)"
    if ($taskState2.status -in @("completed", "failed", "cancelled", "blocked")) { break }
  }
  if (-not $taskState2 -or $taskState2.status -ne "completed") { throw "Task(2) did not complete: status=$($taskState2.status)" }

  $runJsonPath2 = Join-Path $testRoot "revision/_state/agent-runs/$runId2.json"
  $waited2 = 0
  while ($waited2 -lt 60) {
    if (Test-Path $runJsonPath2) {
      $rj2 = [System.IO.File]::ReadAllText($runJsonPath2) | ConvertFrom-Json
      if ($rj2.status -in @("completed", "failed")) { break }
    }
    Start-Sleep -Seconds 1; $waited2++
  }

  $recordsCount2 = @(Get-Content $recordsPathE2E | Where-Object { $_.Trim() }).Count
  if ($recordsCount2 -le $recordsCount1) { throw "memory record not added on second run (before=$recordsCount1 after=$recordsCount2)." }
  Write-Host "[e2e] hafiza kaydi (2. kosu): $recordsCount2"

  $cp2Path = Join-Path $testRoot "runtime/agent-runs/$runId2/context-pack.json"
  if (-not (Test-Path $cp2Path)) { throw "context-pack(2) missing." }
  $cp2 = [System.IO.File]::ReadAllText($cp2Path) | ConvertFrom-Json
  $memoryCount2 = @($cp2.memory).Count
  if ($memoryCount2 -lt 1) { throw "second run context-pack carries no memory records." }
  Write-Host "[e2e] hafiza zinciri OK: 2. kosu baglami $memoryCount2 kayit tasiyor"

  Write-Host "[e2e] PASS: book request -> task -> provider -> artifacts -> verifier -> observer+memory"
  Write-Host "[e2e] project kept for inspection: $testRoot"
  exit 0
}
catch {
  Write-Host "[e2e] FAIL: $($_.Exception.Message)"
  if ($bridgeProcess -and -not $bridgeProcess.HasExited -and $bridgeOut) {
    # bridge loglari redirect ile yazilmiyor; surec ciktilarini oldurmeden once denemiyoruz
  }
  if (Test-Path $bridgeErr) { Get-Content $bridgeErr -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  [bridge-err] $_" } }
  if (Test-Path (Join-Path $testRoot "bridge-out.log")) { Get-Content (Join-Path $testRoot "bridge-out.log") -Tail 20 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "  [bridge-out] $_" } }
  throw
}
finally {
  if ($bridgeProcess -and -not $bridgeProcess.HasExited) {
    Stop-Process -Id $bridgeProcess.Id -Force -ErrorAction SilentlyContinue
    $bridgeProcess.WaitForExit(5000) | Out-Null
  }
}
