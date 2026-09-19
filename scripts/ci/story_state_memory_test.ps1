# CI: story_state hafıza zinciri testi.
# Kanıtlar: (1) defterlerden story_state kaydı üretilir, (2) şema + bağımsız doğrulayıcı geçer,
# (3) seçici son N story_state kaydını fazdan bağımsız taşır, (4) context-pack story_state bölümü taşır.
param(
  [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$testRoot = Join-Path $ProjectRoot "_workspace/story-state-test"

# Temiz başlangıç
if (Test-Path $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $testRoot "runtime/memory") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $testRoot "revision/_state") -Force | Out-Null

# Sözleşmeyi kopyala (story_state tipini tanımalı)
Copy-Item -LiteralPath (Join-Path $ProjectRoot "runtime/memory/schema.json") -Destination (Join-Path $testRoot "runtime/memory/schema.json") -Force

# Başlıklı brief → book_id türetme kanıtı için
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $testRoot "runtime/book-brief.json"), '{"writing_intent":{"title":"Story State Test Kitabi"}}', $utf8NoBom)

# Hikâye defterleri: karakter konumu, olay, ihlal
$characterState = [ordered]@{
  characters = @(
    [ordered]@{ name = "Deniz"; location = "kule-kat-7"; condition = "yarali" },
    [ordered]@{ name = "Mira"; location = "liman"; condition = "saglikli" }
  )
}
[System.IO.File]::WriteAllText((Join-Path $testRoot "revision/_state/character-state.json"), ($characterState | ConvertTo-Json -Depth 8), $utf8NoBom)

$plotLedger = [ordered]@{
  events = @(
    [ordered]@{ summary = "Deniz kuleye cikti ve pusuya dustu" },
    [ordered]@{ summary = "Mira gemiyi limanda hazirladi" }
  )
}
[System.IO.File]::WriteAllText((Join-Path $testRoot "revision/_state/plot-ledger.json"), ($plotLedger | ConvertTo-Json -Depth 8), $utf8NoBom)

$continuityLedger = [ordered]@{
  violations = @(
    [ordered]@{ description = "EP003: Deniz sabah kuledeydi ama bolum basi limanda anlatildi" }
  )
}
[System.IO.File]::WriteAllText((Join-Path $testRoot "revision/_state/continuity-ledger.json"), ($continuityLedger | ConvertTo-Json -Depth 8), $utf8NoBom)

# 1) 1. koşu kaydı (create fazı)
& (Join-Path $PSScriptRoot "../save_story_state_record.ps1") -ProjectRoot $testRoot -RunId "run-ep001" -TaskId "t1" -Phase "create" -EpisodeNumber "ep001" | Out-Null
$recordsPath = Join-Path $testRoot "runtime/memory/records.jsonl"
if (-not (Test-Path $recordsPath)) { throw "records.jsonl yok: 1. kosu kaydi yazilmadi." }
$all = @(Get-Content $recordsPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
if ($all.Count -lt 1) { throw "1. kosu kaydi bos." }
if ($all[0].record_type -ne "story_state") { throw "record_type story_state degil: $($all[0].record_type)" }
if ($all[0].book_id -ne "story-state-test-kitabi") { throw "book_id turetme hatali: $($all[0].book_id)" }
if ($all[0].summary -notmatch "Deniz@kule-kat-7") { throw "ozet karakter konumunu tasiyor: $($all[0].summary)" }
if ($all[0].summary -notmatch "IHLAL: EP003") { throw "ozet surekliklik ihlalini tasiyor: $($all[0].summary)" }
Write-Host "[story-state-test] 1. kosu kaydi OK (book_id=$($all[0].book_id), summary uzunluk=$($all[0].summary.Length))"

# 2) 2. koşu kaydı (polish fazı) — fazdan bağımsız seçim kanıtı için
& (Join-Path $PSScriptRoot "../save_story_state_record.ps1") -ProjectRoot $testRoot -RunId "run-ep002" -TaskId "t2" -Phase "polish" -EpisodeNumber "ep002" | Out-Null
$all = @(Get-Content $recordsPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
if ($all.Count -lt 2) { throw "2. kosu kaydi yazilmadi." }

# 3) Seçici: create fazı sorgusu polish fazındaki story_state'i de taşımali (son N)
$selector = Join-Path $PSScriptRoot "../select_memory_records.ps1"
$sel = (& $selector -RecordsPath $recordsPath -ProjectId "story-state-test" -BookId "story-state-test-kitabi" -Phase "create") -join "`n" | ConvertFrom-Json
if ($sel.story_state_count -lt 2) { throw "story_state_count < 2: $($sel.story_state_count)" }
if (@($sel.story_state).Count -ne [int]$sel.story_state_count) { throw "story_state dizi uyumsuz." }
Write-Host "[story-state-test] secici OK (story_state_count=$($sel.story_state_count), fazlar: $(@($sel.story_state) | ForEach-Object { $_.phase })-)"

# 4) Context-pack story_state bölümü
New-Item -ItemType Directory -Path (Join-Path $testRoot "runtime/agent-runs/run-ep003") -Force | Out-Null
$packOut = (& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $ProjectRoot "scripts/build_context_pack.ps1") -ProjectRoot $testRoot -RunId "run-ep003" -Phase "create") -join "`n" | ConvertFrom-Json
if (-not $packOut.ok) { throw "context-pack uretilmedi." }
$pack = Get-Content (Join-Path $testRoot "runtime/agent-runs/run-ep003/context-pack.json") -Raw | ConvertFrom-Json
if (@($pack.story_state).Count -lt 2) { throw "pack story_state < 2: $(@($pack.story_state).Count)" }
if ($pack.story_state[0].summary -notmatch "Deniz@kule-kat-7|IHLAL") { throw "pack story_state ozeti anlamsiz." }
Write-Host "[story-state-test] context-pack OK (story_state=$(@($pack.story_state).Count))"

# 5) İzolasyon: başka kitap story_state'i taşınmamalı
$other = [ordered]@{ ts = "2026-09-19T00:00:00.0000000Z"; record_type = "story_state"; project_id = "story-state-test"; book_id = "diger-kitap"; run_id = "run-x"; phase = "create"; episode = "ep001"; source_hash = "aaaa:story"; summary = "diger kitap ozeti"; task_id = ""; decision = ""; provider_phase = "create" }
[System.IO.File]::AppendAllText($recordsPath, ($other | ConvertTo-Json -Compress) + "`n", $utf8NoBom)
$sel2 = (& $selector -RecordsPath $recordsPath -ProjectId "story-state-test" -BookId "story-state-test-kitabi" -Phase "create") -join "`n" | ConvertFrom-Json
if ($sel2.story_state_count -ne 2) { throw "izolasyon hatasi: diger kitap story_state sizdi (count=$($sel2.story_state_count))" }
Write-Host "[story-state-test] kitap izolasyonu OK"

# Temizlik
Remove-Item -LiteralPath $testRoot -Recurse -Force
Write-Host "[story-state-test] PASS"
exit 0
