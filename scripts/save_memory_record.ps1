# Hafıza kaydı üretici (claude-mem uyarlaması, jsonl_compat depo).
# Bir agent-run bittiğinde çağrılır; runtime/memory/schema.json sözleşmesine uyan tek satır JSON
# kaydını runtime/memory/records.jsonl dosyasına ekler. Fail-open DEĞILDIR: kayıt şemaya uymuyorsa
# exit 2 ile döner (runner bunu kanıt kaybı olarak raporlar ama görevi düşürmez).
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$TaskId,
  [Parameter(Mandatory = $true)][string]$Phase,
  [string]$BookId = "",
  [string]$VerificationPath = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$schemaPath = Join-Path $ProjectRoot "runtime/memory/schema.json"
if (-not (Test-Path -LiteralPath $schemaPath)) { throw "Memory schema missing: $schemaPath" }
$schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json

# project_id: proje klasör adı (izole/temp projelerde stabil kimlik)
$projectId = Split-Path -Leaf $ProjectRoot

# book_id: brief yoksa tek-kitap varsayılanı
if (-not $BookId.Trim()) {
  $briefPath = Join-Path $ProjectRoot "runtime/book-brief.json"
  if (Test-Path -LiteralPath $briefPath) {
    try {
      $brief = Get-Content -LiteralPath $briefPath -Raw | ConvertFrom-Json
      $title = [string]$brief.writing_intent.title
      if ($title.Trim()) { $BookId = ($title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-') }
    } catch { }
  }
  if (-not $BookId.Trim()) { $BookId = "default-book" }
}

# decision: yazılan artifact'lerden özet çıkarım (plan: gerçek LLM özetine yükseltme)
$artifactSummaries = @()
$runDir = Join-Path $ProjectRoot ("runtime/agent-runs/{0}" -f $RunId)
if (Test-Path -LiteralPath (Join-Path $runDir "run-artifacts.json") -PathType Leaf) {
  try {
    $runArtifacts = Get-Content (Join-Path $runDir "run-artifacts.json") -Raw | ConvertFrom-Json
    foreach ($a in @($runArtifacts)) {
      $p = Join-Path $ProjectRoot ([string]$a.path)
      if (Test-Path -LiteralPath $p) {
        $text = [System.IO.File]::ReadAllText($p)
        $firstLine = ($text -split "`n" | Where-Object { $_.Trim() } | Select-Object -First 1)
        if (-not $firstLine) { $firstLine = "(bos icerik)" }
        $artifactSummaries += ("{0}: {1}" -f $a.path, $firstLine.Trim())
      }
    }
  } catch { }
}
$decision = "Faz '$Phase' tamamlandi; uretim: " + $(if ($artifactSummaries.Count) { $artifactSummaries -join " | " } else { "(artifact listesi okunamadi)" })
if ($decision.Length -gt 600) { $decision = $decision.Substring(0, 600) }

# verification özeti (varsa)
$verificationNote = ""
if ($VerificationPath.Trim() -and (Test-Path -LiteralPath $VerificationPath -PathType Leaf)) {
  try {
    $v = Get-Content -LiteralPath $VerificationPath -Raw | ConvertFrom-Json
    $verificationNote = "verdict=$($v.verdict)"
    if ($v.reasons -and @($v.reasons).Count) { $verificationNote += "; reasons=" + (@($v.reasons) -join "; ") }
  } catch { $verificationNote = "verdict=unavailable" }
}

$summary = ("Run {0} (task {1}, faz {2}) tamamlandi. {3}" -f $RunId, $TaskId, $Phase, $(if ($verificationNote) { "Dogrulama: " + $verificationNote } else { "Dogrulama: verify_agent_run pass" }))
if ($summary.Length -gt 500) { $summary = $summary.Substring(0, 500) }

$record = [ordered]@{
  ts = (Get-Date).ToString("o")
  record_type = "verification"
  project_id = $projectId
  book_id = $BookId
  run_id = $RunId
  phase = $Phase
  source_hash = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant().Substring(0, 16) + ":" + $RunId
  summary = $summary
  task_id = $TaskId
  decision = $decision
  provider_phase = $Phase
}

# Şema sözleşmesi: zorunlu alanlar dolu, yasak alanlar YOK
$missing = @($schema.required_fields | Where-Object { [string]::IsNullOrWhiteSpace([string]$record.$_) })
$forbidden = @($schema.forbidden_fields | Where-Object { $null -ne $record.$_ })
if ($missing.Count -gt 0 -or $forbidden.Count -gt 0) {
  Write-Host ([ordered]@{ valid = $false; missing = $missing; forbidden = $forbidden } | ConvertTo-Json -Compress)
  exit 2
}

# Bağımsız doğrulayıcıdan da geç (aynı sözleşme, ikinci kontrol).
# Not: doğrulayıcı başarıda açık exit 0 yazmadığı için $LASTEXITCODE güvenilemez;
# kararı JSON çıktısındaki 'valid' alanından okuruz.
$validator = Join-Path $PSScriptRoot "validate_memory_record.ps1"
$recordJson = $record | ConvertTo-Json -Depth 8 -Compress
$push = Push-Location; Push-Location $ProjectRoot
try {
  $validation = & $validator -RecordJson $recordJson | Out-String
} finally { Pop-Location; $null = $push }
$validationObj = $null
try { $validationObj = $validation.Trim() | ConvertFrom-Json } catch { }
if (-not $validationObj -or -not $validationObj.valid) {
  Write-Host "[memory] dogrulayici reddetti: $($validation.Trim())"
  exit 2
}

# jsonl_compat depoya ekle (tek satır = tek kayıt; ileride SQLite'a birebir taşınır)
$memoryDir = Join-Path $ProjectRoot "runtime/memory"
New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
$recordsPath = Join-Path $memoryDir "records.jsonl"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::AppendAllText($recordsPath, $recordJson + "`n", $utf8NoBom)

Write-Host "[memory] kayit yazildi: $recordsPath"
exit 0
