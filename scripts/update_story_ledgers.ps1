# Defter doldurucu (story ledger keeper): başarılı bir hikâye koşusundan sonra
# revision/_state altındaki üç defteri bölüm içeriğine göre günceller:
#   - character-state.json  : karakter konum/durum güncellemeleri (+ yeni karakter)
#   - plot-ledger.json      : bölümün ana olayı eklenir (append-only)
#   - continuity-ledger.json: çözülmemiş süreklilik ihlalleri eklenir (append-only)
#
# Zemin (artifact): runtime/agent-compliance/<Phase>.json → produced_files (bu koşuda
# yazılan dosyalar); bulunamazsa episode/ altındaki en yeni .md.
# Model: provider_phase.ps1 ile AYNI env sözleşmesi (KITHUB_API_PROVIDER/MODEL/KEY/
# BASE_URL/ALLOW_EMPTY_KEY) — scripts/lib_ledger_model.ps1 üzerinden.
# -ResponseJson verilirse model çağrısı tamamen atlanır (CI determinizmi).
#
# Fail-open: her hata loglanır ve exit 0 — görev asla düşmez, en fazla kanıt/staleness kaybı olur.
param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [Parameter(Mandatory = $true)][string]$Phase,
  [string]$TaskId = "",
  [string]$ResponseJson = "",
  [int]$MaxArtifactChars = 6000,
  [int]$TimeoutSeconds = 120
)

$script:TimeoutSeconds = $TimeoutSeconds
$storyPhases = @("create", "polish", "rewrite")

try {
  $ProjectRoot = [System.IO.Path]::GetFullPath((Resolve-Path -LiteralPath $ProjectRoot).Path)

  # 1) Faz kapısı: yalnızca hikâye metni üreten fazlarda çalış.
  if (@($storyPhases) -notcontains ($Phase.Trim().ToLowerInvariant())) {
    Write-Host "[ledger-keeper] faz atlandi (hikâye üretimi degil): $Phase"
    exit 0
  }

  $stateDir = Join-Path $ProjectRoot "revision/_state"
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)

  function Read-StateJson([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $null }
    try { return [System.IO.File]::ReadAllText($path) | ConvertFrom-Json } catch { return "__CORRUPT__" }
  }

  function Write-StateJson([string]$path, $object) {
    $json = $object | ConvertTo-Json -Depth 12
    [System.IO.File]::WriteAllText($path, $json, $utf8Bom)
  }

  function Get-Prop([object]$obj, [string[]]$names) {
    if ($null -eq $obj) { return "" }
    foreach ($n in @($names)) {
      if ($obj.PSObject.Properties[$n]) {
        $v = [string]$obj.$n
        if ($v.Trim()) { return $v.Trim() }
      }
    }
    return ""
  }

  function Set-Prop([object]$obj, [string]$existingKey, [string]$fallbackKey, [string]$value) {
    if (-not $value.Trim()) { return }
    if ($obj.PSObject.Properties[$existingKey]) { $obj.$existingKey = $value }
    elseif ($obj.PSObject.Properties[$fallbackKey]) { $obj.$fallbackKey = $value }
    else { Add-Member -InputObject $obj -NotePropertyName $existingKey -NotePropertyValue $value }
  }

  # Placeholder savunma: run_pipeline.ps1 (Validate-LongformState) planning defterlerinde
  # bu desenleri faz-dusurucu olarak tarar. Model yaniti boyle metin tasiyorsa o degeri
  # red etmek fail-open sozunu korur; deftere yazmak kapıları patlatır.
  $script:placeholderPattern = "(?i)(plan_required|to_be_confirmed|placeholder|\btodo\b|\btbd\b|fill\s*in|lorem ipsum)"
  function Test-Clean([string]$value) { return (-not ([string]$value -match $script:placeholderPattern)) }

  # 2) Defterleri oku (bozuksa hiç dokunma — veri kaybı riski).
  $charPath = Join-Path $stateDir "character-state.json"
  $plotPath = Join-Path $stateDir "plot-ledger.json"
  $contPath = Join-Path $stateDir "continuity-ledger.json"
  $characterState = Read-StateJson $charPath
  $plotLedger = Read-StateJson $plotPath
  $continuityLedger = Read-StateJson $contPath
  foreach ($l in @($characterState, $plotLedger, $continuityLedger)) {
    if ("$l" -eq "__CORRUPT__") { Write-Host "[ledger-keeper] atlandi (fail-open): bozuk defter JSON'u ($stateDir)"; exit 0 }
  }

  # 3) Artifact zeminini topla.
  # İki compliance şeması desteklenir:
  #   - task-modu (provider_phase.ps1):  produced_files
  #   - IDE/manual modu (write_agent_compliance.ps1): output_artifacts
  $artifactParts = @()
  $totalChars = 0
  $compliancePath = Join-Path $ProjectRoot ("runtime/agent-compliance/{0}.json" -f $Phase)
  $compliance = Read-StateJson $compliancePath
  $produced = @()
  if ($compliance -and "$compliance" -ne "__CORRUPT__") {
    if ($compliance.PSObject.Properties["produced_files"]) { $produced = @($compliance.produced_files) }
    elseif ($compliance.PSObject.Properties["output_artifacts"]) { $produced = @($compliance.output_artifacts) }
  }
  if ($produced.Count) {
    foreach ($rel in $produced) {
      if ($totalChars -ge $MaxArtifactChars) { break }
      $relStr = ([string]$rel).Trim()
      if (-not $relStr -or $relStr -notmatch "\.(md|txt)$") { continue }
      $abs = Join-Path $ProjectRoot ($relStr -replace "/", "\")
      if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) { continue }
      try {
        $text = [System.IO.File]::ReadAllText($abs).Trim()
        if ($text.Length -lt 64) { continue }
        $remaining = $MaxArtifactChars - $totalChars
        if ($text.Length -gt $remaining) { $text = $text.Substring(0, $remaining) }
        $artifactParts += ("--- {0} ---`n{1}" -f $relStr, $text)
        $totalChars += $text.Length
      } catch { }
    }
  }
  if (-not $artifactParts.Count) {
    $episodeDir = Join-Path $ProjectRoot "episode"
    if (Test-Path -LiteralPath $episodeDir -PathType Container) {
      $newest = Get-ChildItem -LiteralPath $episodeDir -Recurse -Filter *.md -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
      if ($newest) {
        try {
          $text = [System.IO.File]::ReadAllText($newest.FullName).Trim()
          if ($text.Length -gt $MaxArtifactChars) { $text = $text.Substring(0, $MaxArtifactChars) }
          if ($text.Length -ge 64) { $artifactParts += ("--- {0} ---`n{1}" -f $newest.Name, $text) }
        } catch { }
      }
    }
  }
  $artifactExcerpt = if ($artifactParts.Count) { $artifactParts -join "`n`n" } else { "" }

  # 4) Prompt: mevcut defter özetleri + artifact parçası; model strict JSON döner.
  $curChars = @()
  if ($characterState) {
    foreach ($c in @(@($characterState.characters) | Where-Object { $_ } | Select-Object -First 12)) {
      $n = Get-Prop $c @("name", "id")
      if (-not $n) { continue }
      $s = $n
      $l = Get-Prop $c @("location", "position")
      $cd = Get-Prop $c @("condition", "status")
      if ($l) { $s += "@" + $l }
      if ($cd) { $s += "(" + $cd + ")" }
      $curChars += $s
    }
  }
  $curEvents = @()
  if ($plotLedger) {
    $evSrc = @()
    if ($plotLedger.PSObject.Properties["events"]) { $evSrc = @($plotLedger.events) }
    elseif ($plotLedger.PSObject.Properties["chapters"]) { $evSrc = @($plotLedger.chapters) }
    foreach ($e in @($evSrc | Where-Object { $_ } | Select-Object -Last 5)) {
      $s = Get-Prop $e @("summary", "new_event", "event", "description")
      if ($s) { $curEvents += $s }
    }
  }
  $curViols = @()
  if ($continuityLedger -and $continuityLedger.PSObject.Properties["violations"]) {
    foreach ($v in @($continuityLedger.violations | Where-Object { $_ })) {
      $t = if ($v -is [string]) { ([string]$v).Trim() } else { Get-Prop $v @("description", "summary", "message") }
      if ($t) { $curViols += $t }
    }
    $curViols = @($curViols | Select-Object -Last 3)
  }

  $prompt = @"
Kitap yazim hattinin hikâye defterlerini guncelleme gorevi. Asagidaki BOLUM METNINI oku ve su sekilde SADECE strict JSON dondur (markdown fence yok, aciklama yok):

{"character_updates":[{"name":"karakter adi","location":"yeni konum","condition":"yeni durum"}],"new_event":"bu bolumdeki ana olay (1-2 cumle)","violations":["varsa cozulmemis sureklilik ihlali"]}

Kurallar:
- Sadece metinde kanitlanmis degisiklikleri yaz; konum/durum degismeyen karakterleri listeleme.
- Degisen karakter yoksa character_updates bos dizi olsun. Ihlal yoksa violations bos dizi olsun.
- new_event her kosuda mutlaka dolsun.

MEVCUT KARAKTER DURUMU: $(if ($curChars.Count) { $curChars -join "; " } else { "(yok)" })
MEVCUT SON OLAYLAR: $(if ($curEvents.Count) { $curEvents -join "; " } else { "(yok)" })
MEVCUT IHLALLER: $(if ($curViols.Count) { $curViols -join "; " } else { "(yok)" })

--- BOLUM METNI (kirpilmis) ---
$(if ($artifactExcerpt) { $artifactExcerpt } else { "(artifact bulunamadi; yalnizca mevcut defter bilgisine gore mantikli ve KUCUK bir guncelleme yap, uydurma olay EKLEME)" })
"@

  # 5) Model yanıtı: CI için -ResponseJson, yoksa env sözleşmesiyle canlı çağrı.
  if ($ResponseJson.Trim()) {
    $chatText = $ResponseJson
  } else {
    if (-not $artifactExcerpt) {
      Write-Host "[ledger-keeper] atlandi (fail-open): zemin artifact bulunamadi (compliance + episode bos)."
      exit 0
    }
    . (Join-Path $PSScriptRoot "lib_ledger_model.ps1")
    $chatText = Invoke-LedgerModelApi -Prompt $prompt
  }

  # 6) Yanıtı esnek parse et (fence/prose toleranslı).
  function ConvertTo-JsonCandidate([string]$text) {
    $clean = ([string]$text).Trim()
    $clean = $clean -replace '^\s*```(?:json)?\s*', ''
    $clean = $clean -replace '\s*```\s*$', ''
    $clean = $clean.Trim([char]0xFEFF)
    $start = $clean.IndexOf("{")
    $end = $clean.LastIndexOf("}")
    if ($start -lt 0 -or $end -le $start) { throw "yanitta JSON nesnesi yok" }
    return ($clean.Substring($start, $end - $start + 1) | ConvertFrom-Json)
  }

  $obj = ConvertTo-JsonCandidate $chatText
  $charUpdates = @()
  foreach ($k in @("character_updates", "characters")) {
    if ($obj.PSObject.Properties[$k]) { $charUpdates = @($obj.$k); break }
  }
  $newEvent = ""
  foreach ($k in @("new_event", "event", "summary")) {
    if ($obj.PSObject.Properties[$k]) { $v = [string]$obj.$k; if ($v.Trim()) { $newEvent = $v.Trim(); break } }
  }
  $rawViolations = @()
  foreach ($k in @("violations", "new_violations")) {
    if ($obj.PSObject.Properties[$k]) { $rawViolations = @($obj.$k); break }
  }
  # Placeholder savunma: kapıları patlatacak metinleri ele; kalan hiçbir alan yoksa fail-open.
  $charUpdates = @(@($charUpdates) | Where-Object {
    $u = $_
    if (-not $u -or $u -is [string]) { return $false }
    foreach ($p in @("name", "id", "location", "position", "condition", "status")) {
      if ($u.PSObject.Properties[$p] -and -not (Test-Clean ([string]$u.$p))) { return $false }
    }
    return $true
  })
  if ($newEvent -and -not (Test-Clean $newEvent)) { $newEvent = "" }
  $rawViolations = @(@($rawViolations) | Where-Object {
    $t = if ($_ -is [string]) { ([string]$_).Trim() } else { (Get-Prop $_ @("description", "summary", "message")) }
    return ($t -and (Test-Clean $t))
  })
  if (-not $charUpdates.Count -and -not $newEvent -and -not $rawViolations.Count) {
    throw "yanitta guncellenebilir alan yok (character_updates/new_event/violations)"
  }

  # 7) character-state güncelle (eşleşen karakteri yamala; yeni karakter ekle).
  $ts = (Get-Date).ToString("o")
  $charChanged = 0
  if ($null -ne $characterState) { $cs = $characterState } else { $cs = [pscustomobject]@{ schema_version = "1.1.0"; run_id = $RunId; characters = @() } }
  if (-not $cs.PSObject.Properties["characters"]) { Add-Member -InputObject $cs -NotePropertyName characters -NotePropertyValue @() }
  if ($cs.PSObject.Properties["run_id"]) { $cs.run_id = $RunId } else { Add-Member -InputObject $cs -NotePropertyName run_id -NotePropertyValue $RunId }
  $chars = @(@($cs.characters) | Where-Object { $_ })
  foreach ($u in $charUpdates) {
    if (-not $u -or $u -is [string]) { continue }
    $uname = Get-Prop $u @("name", "id")
    if (-not $uname) { continue }
    $uloc = Get-Prop $u @("location", "position")
    $ucond = Get-Prop $u @("condition", "status")
    $match = $null
    foreach ($c in $chars) {
      $cname = Get-Prop $c @("name", "id")
      if ($cname -and $cname -ieq $uname) { $match = $c; break }
    }
    if ($match) {
      Set-Prop $match "location" "position" $uloc
      Set-Prop $match "condition" "status" $ucond
      $charChanged++
    } else {
      $newChar = [ordered]@{ name = $uname }
      if ($uloc) { $newChar.location = $uloc }
      if ($ucond) { $newChar.condition = $ucond }
      $chars += [pscustomobject]$newChar
      $charChanged++
    }
  }
  if ($charChanged -gt 0) { $cs.characters = $chars }

  # 8) plot-ledger'a olay ekle (append-only, son olaylarla birebir aynıysa atla).
  $plotChanged = 0
  if ($newEvent) {
    if ($null -ne $plotLedger) { $pl = $plotLedger } else { $pl = [pscustomobject]@{ schema_version = "1.1.0"; run_id = $RunId; events = @() } }
    $arrayKey = "events"
    if (-not $pl.PSObject.Properties["events"] -and $pl.PSObject.Properties["chapters"]) { $arrayKey = "chapters" }
    if (-not $pl.PSObject.Properties[$arrayKey]) { Add-Member -InputObject $pl -NotePropertyName $arrayKey -NotePropertyValue @() }
    if ($pl.PSObject.Properties["run_id"]) { $pl.run_id = $RunId } else { Add-Member -InputObject $pl -NotePropertyName run_id -NotePropertyValue $RunId }
    $events = @(@($pl.$arrayKey) | Where-Object { $_ })
    $recentSummaries = @()
    foreach ($e in @($events | Select-Object -Last 5)) {
      $s = Get-Prop $e @("summary", "new_event", "event", "description")
      if ($s) { $recentSummaries += $s }
    }
    if (@($recentSummaries) -notcontains $newEvent) {
      $events += [pscustomobject]@{ summary = $newEvent; run_id = $RunId; ts = $ts }
      $pl.$arrayKey = $events
      $plotChanged = 1
    }
  }

  # 9) Ihlaller continuity-ledger'a YAZILMAZ: validate_state_reducers.ps1 dolu violations
  # listesini faz-dusurucu kabul eder. Bunun yerine append-only kanit dosyasina yazilir;
  # editor/continuity-editor ajanlari bunu sonraki faz girdisi olarak kullanir.
  $violAdded = 0
  if ($rawViolations.Count) {
    $proofDir = Join-Path $ProjectRoot "runtime/fixture-reports"
    New-Item -ItemType Directory -Path $proofDir -Force | Out-Null
    $proofPath = Join-Path $proofDir "story-ledger-violations.json"
    $existingProof = @()
    $proofObj = Read-StateJson $proofPath
    if ($proofObj -and "$proofObj" -ne "__CORRUPT__") { $existingProof = @($proofObj) }
    # Dikkat: @(...) sarmalayici nested dizi/dize kopyasi uretir; kopya yazmak dedupe'yi bozar.
    # Bu yuzden mevcut kayitlar yerinde (in-place) güncellenir, yeni girdiler sona eklenir.
    $existingDescriptions = @()
    foreach ($v in $existingProof) {
      $t = if ($v -is [string]) { ([string]$v).Trim() } else { (Get-Prop $v @("description", "summary", "message")) }
      if ($t) { $existingDescriptions += $t }
    }
    $toAppend = @()
    foreach ($v in $rawViolations) {
      $t = if ($v -is [string]) { ([string]$v).Trim() } else { (Get-Prop $v @("description", "summary", "message")) }
      if ($t -and @($existingDescriptions) -notcontains $t) {
        $toAppend += [ordered]@{ description = $t; run_id = $RunId; ts = $ts }
        $violAdded++
      }
    }
    if ($violAdded -gt 0) {
      Write-StateJson $proofPath (@($existingProof) + @($toAppend))
      $violAdded = 1
    }
  }

  # 10) Sadece değişen defterleri yaz (yok olan defter ilk değişimde oluşur).
  if ($charChanged -gt 0) { Write-StateJson $charPath $cs }
  if ($plotChanged -gt 0) { Write-StateJson $plotPath $pl }

  # 11) Design-hash tazeleme: design-hashes.json kilitli tasarım tabanında
  # character-state.json + plot-ledger.json hashing yapar. Keeper bu defterleri
  # güncelliyorsa hash kayıtlarını yeniler; aksi halde sonraki faz "approved design
  # baseline changed" ile düşer (fail-open sözüne aykırı).
  if ($charChanged -gt 0 -or $plotChanged -gt 0) {
    $dhPath = Join-Path $stateDir "design-hashes.json"
    $dh = Read-StateJson $dhPath
    if ($dh -and "$dh" -ne "__CORRUPT__" -and $dh.PSObject.Properties["sources"]) {
      $targets = @()
      if ($charChanged -gt 0) { $targets += "revision/_state/character-state.json" }
      if ($plotChanged -gt 0) { $targets += "revision/_state/plot-ledger.json" }
      $sha = [Security.Cryptography.SHA256]::Create()
      foreach ($src in @($dh.sources)) {
        if (-not $src) { continue }
        $rel = ([string]$src.path).Replace("\", "/")
        if (@($targets) -notcontains $rel) { continue }
        $abs = Join-Path $ProjectRoot ($rel -replace "/", "\")
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) { continue }
        try {
          $stream = [System.IO.File]::OpenRead($abs)
          try { $hash = (($sha.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join "") } finally { $stream.Dispose() }
          $src.sha256 = $hash
        } catch { }
      }
      Write-StateJson $dhPath $dh
    }
  }

  Write-Host ("[ledger-keeper] defterler guncellendi: karakter={0} olay=+{1} ihlal=+{2} (run={3} faz={4})" -f $charChanged, $plotChanged, $violAdded, $RunId, $Phase)
  exit 0
} catch {
  Write-Host ("[ledger-keeper] atlandi (fail-open): " + $_.Exception.Message)
  exit 0
}
