# CI: defter doldurucu (story ledger keeper) testi.
# Kanıtlar: (1) -ResponseJson ile üç defter gerçekten güncellenir, (2) aynı olay tekrar
# eklenmez (dedupe), (3) bozuk model yanıtı fail-open olur, (4) model yoksa fail-open
# olur, (5) güncelleme sonrası story_state kaydı "bos" özeti yerine gerçek özü taşır.
param(
  [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$testRoot = Join-Path $ProjectRoot "_workspace/ledger-filler-test"

# Ortamı koru (case 4 modeli temizlemeli; sonda geri koy)
$envBackup = @{}
foreach ($name in @("KITHUB_API_PROVIDER", "KITHUB_API_MODEL", "KITHUB_API_KEY", "KITHUB_API_BASE_URL", "KITHUB_API_ALLOW_EMPTY_KEY")) {
  $envBackup[$name] = [System.Environment]::GetEnvironmentVariable($name)
}
try {
  # Temiz başlangıç
  if (Test-Path $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
  New-Item -ItemType Directory -Path (Join-Path $testRoot "revision/_state") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $testRoot "runtime/agent-compliance") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $testRoot "runtime/memory") -Force | Out-Null
  New-Item -ItemType Directory -Path (Join-Path $testRoot "episode") -Force | Out-Null

  $utf8NoBom = New-Object System.Text.UTF8Encoding($false)

  function Reset-Ledgers {
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
  }

  function Get-Ledgers {
    [ordered]@{
      chars = ([System.IO.File]::ReadAllText((Join-Path $testRoot "revision/_state/character-state.json")) | ConvertFrom-Json)
      plot = ([System.IO.File]::ReadAllText((Join-Path $testRoot "revision/_state/plot-ledger.json")) | ConvertFrom-Json)
      cont = ([System.IO.File]::ReadAllText((Join-Path $testRoot "revision/_state/continuity-ledger.json")) | ConvertFrom-Json)
    }
  }

  # Zemin artifact: bu koşuda üretilen bölüm metni + compliance kanıtı
  $episodeText = @"
Deniz, kule kalintilarindan kurtulup gece boyunca sahile indirdigi tekneyle limana ulasti. Yarasi hâlâ aciyordu ama Mira'nin gemisi limandan ayrilmadan yetismeyi basardi. Sabah vakti iskelede Mira ile karsilasirken rantiyeci Kemal'in adamlarinin da onlari aradigini ogrendi. Bolum, Deniz'in gemiye binip denize acilmasiyla kapanir.
"@
  [System.IO.File]::WriteAllText((Join-Path $testRoot "episode/EP001.md"), $episodeText, $utf8NoBom)
  $compliance = [ordered]@{ run_id = "run-ep001"; phase = "create"; produced_files = @("episode/EP001.md") }
  [System.IO.File]::WriteAllText((Join-Path $testRoot "runtime/agent-compliance/create.json"), ($compliance | ConvertTo-Json -Depth 6), $utf8NoBom)

  $keeper = Join-Path $ProjectRoot "scripts/update_story_ledgers.ps1"

  # 1) Geçerli model yanıtı → üç defter de güncellenir
  Reset-Ledgers
  $resp1 = '{"character_updates":[{"name":"Deniz","location":"liman","condition":"iyilesiyor"},{"name":"Efe","location":"gemi","condition":"saglikli"}],"new_event":"Deniz limana ulasti ve Miranin gemisiyle denize acildi","violations":["EP001: Deniz yaraliyken tek basina tekne indirmesi fiziksel olarak zordu"]}'
  & $keeper -ProjectRoot $testRoot -RunId "run-ep001" -TaskId "t1" -Phase "create" -ResponseJson $resp1 | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "1. kosu exit 0 degil: $LASTEXITCODE" }
  $l = Get-Ledgers
  $deniz = @($l.chars.characters | Where-Object { $_.name -eq "Deniz" })[0]
  if ($deniz.location -ne "liman") { throw "Deniz konumu guncellenmedi: $($deniz.location)" }
  if ($deniz.condition -ne "iyilesiyor") { throw "Deniz durumu guncellenmedi: $($deniz.condition)" }
  if (@($l.chars.characters | Where-Object { $_.name -eq "Efe" }).Count -ne 1) { throw "yeni karakter Efe eklenmedi" }
  if (@($l.plot.events).Count -ne 3) { throw "olay eklenmedi (count=$(@($l.plot.events).Count))" }
  if (@($l.plot.events)[-1].summary -notmatch "Deniz limana ulasti") { throw "olay ozeti hatali" }
  if ($l.plot.run_id -ne "run-ep001") { throw "plot-ledger run_id guncellenmedi" }
  $proof = [System.IO.File]::ReadAllText((Join-Path $testRoot "runtime/fixture-reports/story-ledger-violations.json")) | ConvertFrom-Json
  if (@($proof).Count -ne 1) { throw "ihlal kanıtı eklenmedi (count=$(@($proof).Count))" }
  if (@($proof)[-1].description -notmatch "EP001: Deniz yaraliyken") { throw "ihlal aciklamasi hatali" }
  if (@($l.cont.violations).Count -ne 1) { throw "continuity-ledger bozulmamalı (count=$(@($l.cont.violations).Count))" }
  Write-Host "[ledger-filler-test] 1. kanit OK (karakter yamasi + yeni karakter + olay + ihlal kanıtı)"

  # 2) Dedupe: aynı olay ve ihlal tekrar eklenmez
  & $keeper -ProjectRoot $testRoot -RunId "run-ep001b" -TaskId "t1" -Phase "create" -ResponseJson $resp1 | Out-Null
  $l = Get-Ledgers
  if (@($l.plot.events).Count -ne 3) { throw "dedupe basarisiz: ayni olay tekrar eklendi (count=$(@($l.plot.events).Count))" }
  $proof = [System.IO.File]::ReadAllText((Join-Path $testRoot "runtime/fixture-reports/story-ledger-violations.json")) | ConvertFrom-Json
  if (@($proof).Count -ne 1) { throw "dedupe basarisiz: ayni ihlal tekrar eklendi (count=$(@($proof).Count))" }
  Write-Host "[ledger-filler-test] 2. kanit OK (dedupe: olay + ihlal kanıtı)"

  # 3) Bozuk model yanıtı → fail-open, defterlere dokunulmaz
  Reset-Ledgers
  & $keeper -ProjectRoot $testRoot -RunId "run-ep002" -TaskId "t2" -Phase "create" -ResponseJson '{"character_updates": [ bozuk' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "bozuk yanit gorevi dusturmamali (exit=$LASTEXITCODE)" }
  $l = Get-Ledgers
  if (@($l.plot.events).Count -ne 2) { throw "bozuk yanit defterleri degistirdi" }
  $deniz = @($l.chars.characters | Where-Object { $_.name -eq "Deniz" })[0]
  if ($deniz.location -ne "kule-kat-7") { throw "bozuk yanit karakterleri degistirdi" }
  Write-Host "[ledger-filler-test] 3. kanit OK (bozuk yanit fail-open)"

  # 4) Model yok (KITHUB_API_MODEL bos) → fail-open, defterlere dokunulmaz
  Remove-Item Env:KITHUB_API_MODEL -ErrorAction SilentlyContinue
  & $keeper -ProjectRoot $testRoot -RunId "run-ep003" -TaskId "t3" -Phase "create" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "model yokken gorev dustu (exit=$LASTEXITCODE)" }
  $l = Get-Ledgers
  if (@($l.plot.events).Count -ne 2) { throw "model yokken defterler degistirdi" }
  Write-Host "[ledger-filler-test] 4. kanit OK (model yok fail-open)"

  # 5) Entegrasyon: güncelleme sonrası story_state kaydı gerçek özü taşır
  Copy-Item -LiteralPath (Join-Path $ProjectRoot "runtime/memory/schema.json") -Destination (Join-Path $testRoot "runtime/memory/schema.json") -Force
  [System.IO.File]::WriteAllText((Join-Path $testRoot "runtime/book-brief.json"), '{"writing_intent":{"title":"Ledger Filler Test Kitabi"}}', $utf8NoBom)
  Reset-Ledgers
  & $keeper -ProjectRoot $testRoot -RunId "run-ep004" -TaskId "t4" -Phase "create" -ResponseJson $resp1 | Out-Null
  & (Join-Path $ProjectRoot "scripts/save_story_state_record.ps1") -ProjectRoot $testRoot -RunId "run-ep004" -TaskId "t4" -Phase "create" -EpisodeNumber "ep001" | Out-Null
  $recordsPath = Join-Path $testRoot "runtime/memory/records.jsonl"
  if (-not (Test-Path $recordsPath)) { throw "records.jsonl yok: story_state kaydi yazilmadi." }
  $all = @(Get-Content $recordsPath | Where-Object { $_.Trim() } | ForEach-Object { $_ | ConvertFrom-Json })
  $last = $all[-1]
  if ($last.record_type -ne "story_state") { throw "record_type hatali: $($last.record_type)" }
  if ($last.book_id -ne "ledger-filler-test-kitabi") { throw "book_id turetme hatali: $($last.book_id)" }
  if ($last.summary -match "Durum defterleri bos") { throw "ozet hâlâ bos-defter sablonunu tasiyor: $($last.summary)" }
  if ($last.summary -notmatch "Deniz@liman") { throw "ozet guncel karakter konumunu tasmıyor: $($last.summary)" }
  if ($last.summary -notmatch "IHLAL: EP003") { throw "ozet mevcut ihlali tasmıyor: $($last.summary)" }
  Write-Host "[ledger-filler-test] 5. kanit OK (story_state gercek ozu tasiyor)"

  # Temizlik
  Remove-Item -LiteralPath $testRoot -Recurse -Force
  Write-Host "[ledger-filler-test] PASS"
  exit 0
} finally {
  foreach ($name in @("KITHUB_API_PROVIDER", "KITHUB_API_MODEL", "KITHUB_API_KEY", "KITHUB_API_BASE_URL", "KITHUB_API_ALLOW_EMPTY_KEY")) {
    $old = $envBackup[$name]
    if ($null -eq $old) { Remove-Item "Env:$name" -ErrorAction SilentlyContinue }
    else { [System.Environment]::SetEnvironmentVariable($name, $old) }
  }
}
