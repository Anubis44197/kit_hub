# Hikâye durum kaydı üretici (story_state): bölüm/koşu sonunda revision/_state defterlerinden
# (character-state, plot-ledger, continuity-ledger) fark özeti çıkarıp
# runtime/memory/records.jsonl'a şema-uyumlu story_state kaydı yazar.
# Bölüm sayısı arttıkça yazıcı ajanın bağlam paketi son N story_state kaydını taşır →
# karakterlerin konumları, olaylar, süreklilik ihlalleri kitap ilerledikçe kaybolmaz.
# Fail-open: hiçbir hata görevi düşürmez; en fazla kanıt kaybı olur (hep exit 0).
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$Phase,
  [string]$TaskId = "",
  [string]$EpisodeNumber = "",
  [string]$BookId = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$stateDir = Join-Path $ProjectRoot "revision/_state"
$schemaPath = Join-Path $ProjectRoot "runtime/memory/schema.json"

try {
  if (-not (Test-Path -LiteralPath $schemaPath -PathType Leaf)) { Write-Host "[story-state] sema yok, atlandi"; exit 0 }
  $schema = Get-Content -LiteralPath $schemaPath -Raw | ConvertFrom-Json
  if (@($schema.record_types) -notcontains "story_state") { Write-Host "[story-state] sema story_state tanimiyor, atlandi"; exit 0 }

  # book_id: save_memory_record.ps1 ile AYNI türetme (brief başlığı slug → default-book)
  if (-not $BookId.Trim()) {
    $BookId = "default-book"
    $briefPath = Join-Path $ProjectRoot "runtime/book-brief.json"
    if (Test-Path -LiteralPath $briefPath -PathType Leaf) {
      try {
        $brief = Get-Content -LiteralPath $briefPath -Raw | ConvertFrom-Json
        $title = [string]$brief.writing_intent.title
        if ($title.Trim()) { $BookId = ($title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-') }
      } catch { }
    }
  }
  $projectId = Split-Path -Leaf $ProjectRoot

  function Read-StateJson([string]$rel) {
    $p = Join-Path $stateDir $rel
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return $null }
    try { return Get-Content -LiteralPath $p -Raw | ConvertFrom-Json } catch { return $null }
  }
  $characterState = Read-StateJson "character-state.json"
  $plotLedger = Read-StateJson "plot-ledger.json"
  $continuityLedger = Read-StateJson "continuity-ledger.json"

  $parts = @()

  # Karakter konum/durumları: olası alan adlarına esnek bak (name/id, location/position, condition/status)
  $charSummaries = @()
  foreach ($c in @($characterState.characters)) {
    if (-not $c) { continue }
    if ($c -is [string]) { $charSummaries += $c; continue }
    $name = [string]$c.name; if (-not $name.Trim()) { $name = [string]$c.id }
    if (-not $name.Trim()) { continue }
    $where = [string]$c.location; if (-not $where.Trim()) { $where = [string]$c.position }
    $cond = [string]$c.condition; if (-not $cond.Trim()) { $cond = [string]$c.status }
    $s = $name
    if ($where.Trim()) { $s += "@" + $where }
    if ($cond.Trim()) { $s += "(" + $cond + ")" }
    $charSummaries += $s
  }
  if ($charSummaries.Count) { $parts += ("KARAKTER: " + ($charSummaries -join "; ")) }

  # Olaylar: plot-ledger events/chapters girişlerinin özet alanları (son 5)
  $events = @()
  $eventSource = @()
  if ($plotLedger -and @($plotLedger.events).Count) { $eventSource = @($plotLedger.events) }
  elseif ($plotLedger -and @($plotLedger.chapters).Count) { $eventSource = @($plotLedger.chapters) }
  foreach ($e in $eventSource) {
    if (-not $e) { continue }
    $t = [string]$e.summary
    if (-not $t.Trim()) { $t = [string]$e.new_event }
    if (-not $t.Trim()) { $t = [string]$e.event }
    if (-not $t.Trim()) { $t = [string]$e.description }
    if ($t.Trim()) { $events += $t }
  }
  if ($events.Count) {
    $tail = @($events | Select-Object -Last 5)
    $parts += ("OLAY: " + ($tail -join "; "))
  }

  # Çözülmemiş süreklilik ihlalleri (son 3)
  $violations = @()
  if ($continuityLedger) {
    foreach ($v in @($continuityLedger.violations)) {
      if (-not $v) { continue }
      if ($v -is [string]) { $violations += $v; continue }
      $t = [string]$v.description; if (-not $t.Trim()) { $t = [string]$v.summary }
      if (-not $t.Trim()) { $t = [string]$v.message }
      if ($t.Trim()) { $violations += $t }
    }
  }
  if ($violations.Count) {
    $tail = @($violations | Select-Object -Last 3)
    $parts += ("IHLAL: " + ($tail -join "; "))
  }

  if (-not $parts.Count) { $parts += "Durum defterleri bos/okunamadi; kosu kaniti olarak birakildi." }
  $summary = ($parts -join " | ")
  if ($summary.Length -gt 600) { $summary = $summary.Substring(0, 600) }

  # source_hash: koşu+defter kimliğinden türeyen tekil hash
  $hashInput = $projectId + "|" + $BookId + "|" + $RunId + "|" + $Phase + "|" + $EpisodeNumber + "|" + (Get-Date).Ticks
  $sha = [Security.Cryptography.SHA256]::Create()
  $sourceHash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($hashInput))).Replace("-", "").ToLowerInvariant().Substring(0, 16) + ":story"

  $record = [ordered]@{
    ts = (Get-Date).ToString("o")
    record_type = "story_state"
    project_id = $projectId
    book_id = $BookId
    run_id = $RunId
    phase = $Phase
    episode = $EpisodeNumber
    source_hash = $sourceHash
    summary = $summary
    task_id = $TaskId
    decision = ("Faz '{0}' sonunda hikâye durum özeti kaydedildi." -f $Phase)
    provider_phase = $Phase
  }

  # Şema kontrolü (save_memory_record ile aynı sözleşme)
  $missing = @($schema.required_fields | Where-Object { [string]::IsNullOrWhiteSpace([string]$record.$_) })
  $forbidden = @($schema.forbidden_fields | Where-Object { $null -ne $record.$_ })
  if ($missing.Count -gt 0 -or $forbidden.Count -gt 0) {
    Write-Host ("[story-state] sema ihlali: missing=" + ($missing -join ",") + " forbidden=" + ($forbidden -join ","))
    exit 0
  }

  # Bağımsız doğrulayıcı (aynı sözleşme, ikinci kontrol)
  # Not: doğrulayıcı schema.json'u ÇALIŞMA DİZİNİNDEN okur → proje köküne girip çık.
  $recordJson = $record | ConvertTo-Json -Depth 8 -Compress
  $validator = Join-Path $PSScriptRoot "validate_memory_record.ps1"
  $push = Push-Location; Push-Location $ProjectRoot
  try { $validation = & $validator -RecordJson $recordJson | Out-String } finally { Pop-Location; $null = $push }
  $validationObj = $null
  try { $validationObj = $validation.Trim() | ConvertFrom-Json } catch { }
  if (-not $validationObj -or -not $validationObj.valid) { Write-Host "[story-state] dogrulayici reddetti"; exit 0 }

  # jsonl_compat depoya ekle
  $memoryDir = Join-Path $ProjectRoot "runtime/memory"
  New-Item -ItemType Directory -Path $memoryDir -Force | Out-Null
  $recordsPath = Join-Path $memoryDir "records.jsonl"
  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::AppendAllText($recordsPath, $recordJson + "`n", $utf8NoBom)
  Write-Host "[story-state] kayit yazildi: $recordsPath"
  exit 0
} catch {
  # Fail-open: hata görevi düşürmez.
  Write-Host "[story-state] atlandi (fail-open): $($_.Exception.Message)"
  exit 0
}
