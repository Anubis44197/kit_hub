param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [string]$RunId = ("REV-" + (Get-Date -Format "yyyyMMdd-HHmmss")),
  [switch]$ForceNewSnapshot
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-File {
  param([string]$Path, [string]$Message)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw $Message
  }
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  [System.IO.File]::WriteAllText($Path, $Content, [System.Text.UTF8Encoding]::new($true))
}

function Write-Json {
  param([string]$Path, [object]$Value)
  Write-Utf8 -Path $Path -Content ($Value | ConvertTo-Json -Depth 30)
}

function Get-WordCount {
  param([string]$Text)
  if (-not $Text.Trim()) { return 0 }
  return ([regex]::Matches($Text, "[\p{L}\p{Nd}]+")).Count
}

function Get-FileSha256 {
  param([string]$Path)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
      $hash = $sha.ComputeHash($stream)
      return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
      if ($stream) { $stream.Dispose() }
    }
  }
  finally {
    if ($sha) { $sha.Dispose() }
  }
}

function Get-ReaderTitle {
  param([string]$Text, [string]$Fallback)
  foreach ($line in ($Text -split "`r?`n")) {
    $trimmed = $line.Trim()
    if ($trimmed -match "^#\s+(.+)$") {
      $title = ($Matches[1] -replace "(?i)\bEP\d+\b\s*-?\s*", "").Trim()
      if ($title) { return $title }
    }
  }
  return $Fallback
}

function Get-RelativePath {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root)
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  return ($pathFull.Substring($rootFull.Length).TrimStart("\") -replace "\\", "/")
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
$episodeDir = Join-Path $ProjectRoot "episode"
$workspaceDir = Join-Path $ProjectRoot "revision/_workspace"
$snapshotRoot = Join-Path $ProjectRoot "revision/_snapshots"
$approvalPath = Join-Path $ProjectRoot "runtime/approvals/revision-proposals-approval.json"

if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
  throw "Revision proposal blocked: episode directory missing."
}

$episodes = @(Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File | Sort-Object Name)
if ($episodes.Count -lt 1) {
  throw "Revision proposal blocked: no episode/ep*.md files found."
}

Ensure-Dir $workspaceDir
Ensure-Dir $snapshotRoot

$snapshotManifestPath = Join-Path $workspaceDir "draft-v1-lock.json"
$snapshotId = ""
if ((Test-Path -LiteralPath $snapshotManifestPath -PathType Leaf) -and -not $ForceNewSnapshot) {
  $existing = Read-Utf8 -Path $snapshotManifestPath | ConvertFrom-Json
  $snapshotId = [string]$existing.snapshot_id
}
else {
  $snapshotId = "draft-v1-$RunId"
  $snapshotDir = Join-Path $snapshotRoot $snapshotId
  Ensure-Dir $snapshotDir
  $records = @()
  foreach ($episode in $episodes) {
    $target = Join-Path $snapshotDir $episode.Name
    Copy-Item -LiteralPath $episode.FullName -Destination $target -Force
    $records += [ordered]@{
      source = Get-RelativePath -Root $ProjectRoot -Path $episode.FullName
      snapshot = Get-RelativePath -Root $ProjectRoot -Path $target
      sha256 = Get-FileSha256 -Path $episode.FullName
    }
  }
  Write-Json -Path $snapshotManifestPath -Value ([ordered]@{
    schema_version = "1.0.0"
    snapshot_id = $snapshotId
    locked_at = (Get-Date).ToString("o")
    source = "episode"
    files = $records
    rule = "Draft text is locked before revision analysis; revision proposals may not overwrite episode files without explicit proposal approval."
  })
}

$proposals = @()
$index = 1
foreach ($episode in $episodes) {
  $text = Read-Utf8 -Path $episode.FullName
  $words = Get-WordCount -Text $text
  $title = Get-ReaderTitle -Text $text -Fallback $episode.BaseName
  $paragraphs = @($text -split "(`r?`n){2,}" | Where-Object { $_.Trim().Length -gt 0 })
  $issues = @()
  $severity = "low"
  $action = "editorial_review"
  if ($words -lt 900) {
    $issues += "Bolum kitap olcegi icin kisa gorunuyor; sahne genisletme ve tempo duzenleme onerilir."
    $severity = "major"
    $action = "expand_scene"
  }
  if ($paragraphs.Count -gt 4) {
    $prefixes = @{}
    foreach ($paragraph in $paragraphs) {
      $prefix = ($paragraph.Trim() -replace "\s+", " ")
      if ($prefix.Length -gt 42) { $prefix = $prefix.Substring(0, 42) }
      if (-not $prefixes.ContainsKey($prefix)) { $prefixes[$prefix] = 0 }
      $prefixes[$prefix]++
    }
    foreach ($key in $prefixes.Keys) {
      if ($prefixes[$key] -ge 3) {
        $issues += "Paragraf baslangiclarinda tekrar riski var; tekrar eden ritim kirilmali."
        $severity = "major"
        $action = "reduce_repetition"
        break
      }
    }
  }
  if ($text -match "(?im)^\s*#\s*(EP|Sahne|Scene)\b" -or $text -match "(?i)\bEP\d{2,}\b") {
    $issues += "Okuyucu ciktisinda teknik bolum/sahne etiketi riski var."
    $severity = "critical"
    $action = "remove_technical_markers"
  }
  $mojibakePattern = ("[{0}{1}{2}{3}{4}]|\?{{2,}}" -f [char]0x00C3, [char]0x00C4, [char]0x00C5, [char]0x00F0, [char]0xFFFD)
  if ($text -match $mojibakePattern) {
    $issues += "Turkce karakter/encoding bozulmasi supheli; TDK ve UTF-8 duzeltmesi gerekir."
    $severity = "critical"
    $action = "fix_turkish_encoding"
  }

  if ($issues.Count -gt 0) {
    $proposalId = "REV-{0:000}" -f $index
    $replacementRel = "revision/_workspace/proposed/$proposalId-$($episode.BaseName).md"
    $proposals += [ordered]@{
      id = $proposalId
      status = "pending_user_approval"
      severity = $severity
      target_file = "episode/$($episode.Name)"
      reader_title = $title
      action = $action
      issues = $issues
      proposed_change = "IDE/API writer must create a narrow replacement at $replacementRel, preserving approved plan, character state, timeline, and chapter continuity."
      replacement_file = $replacementRel
      apply_rule = "Cannot be applied until runtime/approvals/revision-proposals-approval.json approves this proposal id."
    }
    $index++
  }
}

if ($proposals.Count -eq 0) {
  $proposals += [ordered]@{
    id = "REV-000"
    status = "no_change_required"
    severity = "info"
    target_file = ""
    reader_title = "Genel kontrol"
    action = "none"
    issues = @("Deterministic revision proposal scan found no obvious length, repetition, technical-marker, or encoding issue.")
    proposed_change = "No rewrite proposal was opened."
    replacement_file = ""
    apply_rule = "No action."
  }
}

$proposalSet = [ordered]@{
  schema_version = "1.0.0"
  run_id = $RunId
  created_at = (Get-Date).ToString("o")
  draft_lock = "revision/_workspace/draft-v1-lock.json"
  approval_file = "runtime/approvals/revision-proposals-approval.json"
  policy = "Proposal-first revision: do not overwrite episode files until the user approves exact proposal ids."
  proposals = $proposals
}

Write-Json -Path (Join-Path $workspaceDir "revision-proposals.json") -Value $proposalSet

$md = "# Revizyon Onerileri`n`n"
$md += "run_id: $RunId`n`n"
$md += "Taslak kilidi: `revision/_workspace/draft-v1-lock.json`  `n"
$md += "Onay dosyasi: `runtime/approvals/revision-proposals-approval.json`  `n`n"
$md += "Bu rapor metni degistirmez; sadece onay bekleyen dar revizyon kartlari uretir.`n`n"
foreach ($proposal in $proposals) {
  $md += "## $($proposal.id) - $($proposal.reader_title)`n`n"
  $md += "- Durum: $($proposal.status)`n"
  $md += "- Onem: $($proposal.severity)`n"
  $md += "- Hedef: $($proposal.target_file)`n"
  $md += "- Eylem: $($proposal.action)`n"
  foreach ($issue in @($proposal.issues)) {
    $md += "- Sorun: $issue`n"
  }
  if ($proposal.replacement_file) {
    $md += "- Onerilen yeni metin dosyasi: `$($proposal.replacement_file)`n"
  }
  $md += "`n"
}
Write-Utf8 -Path (Join-Path $workspaceDir "revision-proposals.md") -Content $md

Write-Host "[revision-proposals] wrote revision/_workspace/revision-proposals.json"
Write-Host "[revision-proposals] draft lock: revision/_workspace/draft-v1-lock.json"
if (-not (Test-Path -LiteralPath $approvalPath -PathType Leaf)) {
  Write-Host "[revision-proposals] waiting for approval: runtime/approvals/revision-proposals-approval.json"
}
