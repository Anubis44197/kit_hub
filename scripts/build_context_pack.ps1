param(
  [Parameter(Mandatory = $true)][string]$ProjectRoot,
  [Parameter(Mandatory = $true)][string]$RunId,
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")][string]$Phase = "create",
  [string]$Episode = "",
  [switch]$IncludeCodebaseContext
)

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$runRoot = Join-Path $ProjectRoot ("runtime/agent-runs/{0}" -f $RunId)
if (-not (Test-Path -LiteralPath $runRoot -PathType Container)) { New-Item -ItemType Directory -Path $runRoot -Force | Out-Null }

$candidatePaths = @(
  "runtime/book-contract.json", "runtime/book-brief.json", "runtime/book-dna.json",
  "runtime/layout-profile.json", "revision/_state/chapter-plan.json",
  "revision/_state/character-state.json", "revision/_state/plot-ledger.json",
  "revision/_state/continuity-ledger.json", "revision/_state/world-state.json",
  "revision/_state/relationship-graph.json", "revision/_state/knowledge-graph.json",
  "revision/_state/promise-payoff-ledger.json", "revision/_state/timeline.json",
  "revision/_state/theme-ledger.json"
)
if ($Episode.Trim()) {
  $candidatePaths += "episode/$Episode"
  $candidatePaths += "design/$Episode"
}

$files = @()
foreach ($relative in $candidatePaths) {
  $path = Join-Path $ProjectRoot ($relative -replace "/", "\")
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
  $bytes = [System.IO.File]::ReadAllBytes($path)
  $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  $text = [System.Text.Encoding]::UTF8.GetString($bytes)
  $files += [ordered]@{ path = $relative; sha256 = $hash; bytes = $bytes.Length; content = $text }
}

# Hafıza kayıtları (same_project_same_book_relevant_phase seçici): onceki kosulardan
# decision/verification ozetleri + son N story_state kaydı (karakter/olay/süreklilik özeti).
# Fail-open: hafıza okunamazsa pack yine de üretilir.
$memoryRecords = @()
$storyStateRecords = @()
$memorySelectorPath = Join-Path $PSScriptRoot "select_memory_records.ps1"
$recordsPath = Join-Path $ProjectRoot "runtime/memory/records.jsonl"
if ((Test-Path -LiteralPath $memorySelectorPath) -and (Test-Path -LiteralPath $recordsPath)) {
  try {
    $projectId = Split-Path -Leaf $ProjectRoot
    # book_id'yi save_memory_record.ps1 ile AYNI sekilde turet (brief basligi slug -> default-book).
    # Farkli turetilirse secici 0 kayit dondurur: hafiza zinciri sessizce kopar.
    $bookId = "default-book"
    $briefPath = Join-Path $ProjectRoot "runtime/book-brief.json"
    if (Test-Path -LiteralPath $briefPath -PathType Leaf) {
      try {
        $brief = Get-Content -LiteralPath $briefPath -Raw | ConvertFrom-Json
        $title = [string]$brief.writing_intent.title
        if ($title.Trim()) { $bookId = ($title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-') }
      } catch { }
    }
    $memoryOut = & $memorySelectorPath -RecordsPath $recordsPath -ProjectId $projectId -BookId $bookId -Phase $Phase
    $memoryObj = (@($memoryOut) -join "`n") | ConvertFrom-Json
    foreach ($r in @($memoryObj.records)) {
      $memoryRecords += [ordered]@{
        ts = [string]$r.ts; record_type = [string]$r.record_type; run_id = [string]$r.run_id
        phase = [string]$r.phase; summary = [string]$r.summary; decision = [string]$r.decision
      }
    }
    # Hikâye durumu: bölüm sayısı arttıkça karakter konumları/olaylar/ihlaller bu bölümden taşınır.
    foreach ($s in @($memoryObj.story_state)) {
      $storyStateRecords += [ordered]@{
        ts = [string]$s.ts; run_id = [string]$s.run_id; episode = [string]$s.episode
        phase = [string]$s.phase; summary = [string]$s.summary; decision = [string]$s.decision
      }
    }
  } catch { $memoryRecords = @() }
}

# Codebase graph (codebase-memory-mcp adaptoru): yalnizca istege bagli.
# Varsayilan KAPALI, cunku kitap projelerinde kod grafigi anlamsizdir ve her
# kosuda indeksleme maliyeti yaratir. Acildiginda bile FAIL-OPEN'dir: adaptor
# kapali/binary yok/sorgu hata verirse bolum status=fallback olur ve paket
# eskisi gibi uretilir (gorev asla dusmez).
$codebase = [ordered]@{ status = "not_requested"; source = "filesystem_context_pack"; project = ""; bytes = 0; result = "" }
if ($IncludeCodebaseContext) {
  try {
    $queryScript = Join-Path $PSScriptRoot "query_codebase_graph.ps1"
    if (Test-Path -LiteralPath $queryScript -PathType Leaf) {
      $rawQuery = & powershell -NoProfile -ExecutionPolicy Bypass -File $queryScript -ProjectRoot $ProjectRoot -Mode architecture -MaxBytes 6000 2>$null
      $queryObj = (@($rawQuery) -join "`n").Trim() | ConvertFrom-Json
      if ($queryObj.ok) {
        $codebase.status = "ok"
        $codebase.source = $queryObj.source
        $codebase.project = $queryObj.project
        $codebase.truncated = [bool]$queryObj.truncated
        $codebase.bytes = [int]$queryObj.bytes
        $codebase.result = [string]$queryObj.result
      } else {
        $codebase.status = "fallback"
        $codebase.source = [string]$queryObj.source
        $codebase.reason = [string]$queryObj.reason
      }
    } else {
      $codebase.status = "fallback"
      $codebase.reason = "query_tool_missing"
    }
  } catch {
    $codebase.status = "fallback"
    $codebase.reason = $_.Exception.Message
  }
}

$pack = [ordered]@{
  schema_version = "1.0.0"
  run_id = $RunId
  phase = $Phase
  episode = $Episode
  created_at = (Get-Date).ToString("o")
  source_policy = "phase-scoped-approved-project-state-only"
  memory = [object[]]$memoryRecords
  story_state = [object[]]$storyStateRecords
  codebase = $codebase
  files = [object[]]$files
  context_fingerprint = if ($files.Count) { ("{0}" -f (($files | ForEach-Object { "{0}:{1}" -f $_.path, $_.sha256 }) -join "|")) | ForEach-Object { [BitConverter]::ToString(([Security.Cryptography.SHA256]::Create().ComputeHash([Text.Encoding]::UTF8.GetBytes($_)))).Replace("-", "").ToLowerInvariant() } } else { "empty" }
}
$output = Join-Path $runRoot "context-pack.json"
$pack | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $output -Encoding utf8
[pscustomobject]@{ ok = $true; path = $output; files = $files.Count; fingerprint = $pack.context_fingerprint } | ConvertTo-Json -Compress
