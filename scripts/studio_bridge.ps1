param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
  [int]$Port = 8765
)

$ErrorActionPreference = "Stop"

function Resolve-ExistingDirectory {
  param([string]$Path)
  if (-not $Path.Trim()) {
    throw "ProjectRoot is required."
  }
  $resolved = Resolve-Path -LiteralPath $Path -ErrorAction Stop
  if (-not (Test-Path -LiteralPath $resolved.Path -PathType Container)) {
    throw "ProjectRoot is not a directory: $Path"
  }
  return $resolved.Path
}

function Read-Utf8JsonIfExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return $null
  }
  try {
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
  }
  catch {
    return $null
  }
}

function Read-Utf8TextIfExists {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    return ""
  }
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8Json {
  param([string]$Path, [object]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, ($Value | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($true))
}

function Get-ProviderSettingsPath {
  $appData = [Environment]::GetFolderPath("ApplicationData")
  if (-not $appData.Trim()) {
    $appData = Join-Path ([Environment]::GetFolderPath("UserProfile")) "AppData\Roaming"
  }
  return Join-Path (Join-Path $appData "KitHub") "provider-settings.json"
}

function Protect-ProviderSecret {
  param([string]$Secret)
  if (-not $Secret.Trim()) { return "" }
  $secure = ConvertTo-SecureString -String $Secret -AsPlainText -Force
  return ConvertFrom-SecureString -SecureString $secure
}

function Unprotect-ProviderSecret {
  param([string]$ProtectedSecret)
  if (-not $ProtectedSecret.Trim()) { return "" }
  $secure = ConvertTo-SecureString -String $ProtectedSecret
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  }
  finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Get-ProviderSettings {
  $path = Get-ProviderSettingsPath
  $settings = Read-Utf8JsonIfExists -Path $path
  if (-not $settings) {
    return [ordered]@{
      ok = $true
      provider = ""
      model = ""
      baseUrl = ""
      hasApiKey = $false
      settingsPath = $path
    }
  }
  return [ordered]@{
    ok = $true
    provider = [string]$settings.provider
    model = [string]$settings.model
    baseUrl = [string]$settings.baseUrl
    hasApiKey = -not [string]::IsNullOrWhiteSpace([string]$settings.apiKeyProtected)
    settingsPath = $path
  }
}

function Set-ProviderEnvironment {
  param([object]$Settings, [string]$ApiKey)
  $env:KITHUB_API_PROVIDER = [string]$Settings.provider
  $env:KITHUB_API_MODEL = [string]$Settings.model
  $env:KITHUB_API_BASE_URL = [string]$Settings.baseUrl
  if ($ApiKey.Trim()) {
    $env:KITHUB_API_KEY = $ApiKey
  }
  if (-not $env:KITHUB_PROVIDER_ARGS.Trim()) {
    $env:KITHUB_PROVIDER_ARGS = "--project-root `"{project_root}`" --phase {phase} --run-id `"{run_id}`" --prompt-file `"{prompt_file}`""
  }
}

function Test-ProviderConnection {
  param([object]$Settings, [string]$ApiKey)
  $provider = [string]$Settings.provider
  $model = [string]$Settings.model
  $baseUrl = [string]$Settings.baseUrl
  if (-not $model.Trim()) { throw "API model is required." }
  if (-not $ApiKey.Trim()) { throw "API key is required." }
  if (-not $baseUrl.Trim()) {
    if ($provider -eq "anthropic") { $baseUrl = "https://api.anthropic.com/v1/messages" }
    elseif ($provider -eq "gemini") { $baseUrl = "https://generativelanguage.googleapis.com/v1beta" }
    elseif ($provider -eq "openrouter") { $baseUrl = "https://openrouter.ai/api/v1/chat/completions" }
    else { $baseUrl = "https://api.openai.com/v1/chat/completions" }
  }

  if ($provider -eq "anthropic") {
    $headers = @{ "x-api-key" = $ApiKey; "anthropic-version" = "2023-06-01"; "content-type" = "application/json" }
    $body = @{ model = $model; max_tokens = 16; messages = @(@{ role = "user"; content = "Reply with OK." }) } | ConvertTo-Json -Depth 10
    [void](Invoke-RestMethod -Method Post -Uri $baseUrl -Headers $headers -Body $body -TimeoutSec 30)
    return $true
  }
  if ($provider -eq "gemini") {
    $uri = "$($baseUrl.TrimEnd('/'))/models/$model`:generateContent?key=$ApiKey"
    $body = @{ contents = @(@{ parts = @(@{ text = "Reply with OK." }) }) } | ConvertTo-Json -Depth 10
    [void](Invoke-RestMethod -Method Post -Uri $uri -ContentType "application/json" -Body $body -TimeoutSec 30)
    return $true
  }

  $headers = @{ Authorization = "Bearer $ApiKey"; "content-type" = "application/json" }
  if ($provider -eq "openrouter") {
    $headers["HTTP-Referer"] = "http://127.0.0.1:8765"
    $headers["X-Title"] = "KitHub Studio"
  }
  $body = @{
    model = $model
    max_tokens = 8
    messages = @(@{ role = "user"; content = "Reply with OK." })
  } | ConvertTo-Json -Depth 10
  [void](Invoke-RestMethod -Method Post -Uri $baseUrl -Headers $headers -Body $body -TimeoutSec 30)
  return $true
}

function Save-ProviderSettings {
  param([object]$Payload)
  $provider = if ($Payload.provider) { [string]$Payload.provider } else { "openai" }
  $model = [string]$Payload.model
  $baseUrl = [string]$Payload.baseUrl
  $apiKey = [string]$Payload.apiKey
  if (-not $model.Trim()) { throw "API model is required." }

  $path = Get-ProviderSettingsPath
  $existing = Read-Utf8JsonIfExists -Path $path
  $protected = if ($apiKey.Trim()) { Protect-ProviderSecret -Secret $apiKey } elseif ($existing) { [string]$existing.apiKeyProtected } else { "" }
  if (-not $protected.Trim()) { throw "API key is required for API mode." }

  $settings = [ordered]@{
    provider = $provider
    model = $model
    baseUrl = $baseUrl
    apiKeyProtected = $protected
    updatedAt = (Get-Date).ToString("o")
  }
  Write-Utf8Json -Path $path -Value $settings
  $plainKey = if ($apiKey.Trim()) { $apiKey } else { Unprotect-ProviderSecret -ProtectedSecret $protected }
  Set-ProviderEnvironment -Settings $settings -ApiKey $plainKey
  $tested = $false
  if ($Payload.test -eq $true) {
    $tested = Test-ProviderConnection -Settings $settings -ApiKey $plainKey
  }

  return [ordered]@{
    ok = $true
    provider = $provider
    model = $model
    baseUrl = $baseUrl
    hasApiKey = $true
    tested = $tested
    settingsPath = $path
  }
}

function Get-WordCount {
  param([string]$Text)
  if (-not $Text.Trim()) { return 0 }
  return ([regex]::Matches($Text, "[\p{L}\p{Nd}]+")).Count
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

function Test-Approved {
  param([object]$Value)
  return ($null -ne $Value -and $Value.approved -eq $true)
}

function Get-BookRequestChecklist {
  param([string]$Text)
  $checks = @(
    [ordered]@{ key = "writing_type"; label = "Tür"; ok = ($Text -match "(?im)^\s*-\s*T.{0,2}r\s*:") },
    [ordered]@{ key = "target_pages"; label = "Hedef sayfa"; ok = ($Text -match "(?im)^\s*-\s*Hedef sayfa\s*:") },
    [ordered]@{ key = "premise"; label = "Konu"; ok = ($Text -match "(?im)^\s*-\s*Konu\s*:") },
    [ordered]@{ key = "characters"; label = "Karakterler"; ok = ($Text -match "(?im)^\s*-\s*Karakter") },
    [ordered]@{ key = "setting"; label = "Dönem ve mekân"; ok = ($Text -match "(?im)^\s*-\s*D.{0,2}nem") },
    [ordered]@{ key = "narration"; label = "Anlatıcı"; ok = ($Text -match "(?im)^\s*-\s*Anlat") },
    [ordered]@{ key = "ending"; label = "Final"; ok = ($Text -match "(?im)^\s*-\s*Final") },
    [ordered]@{ key = "boundaries"; label = "Sınırlar"; ok = ($Text -match "(?im)^\s*-\s*S.{0,2}n.{0,2}r") }
  )
  $missing = @($checks | Where-Object { $_.ok -ne $true } | ForEach-Object { $_.label })
  return [ordered]@{
    complete = ($missing.Count -eq 0)
    missing = $missing
    checks = $checks
  }
}

function Get-QualityAudit {
  param(
    [array]$Chapters,
    [array]$Exports,
    [hashtable]$Approvals,
    [array]$Reports,
    [object]$LongformPlan
  )

  $chapterCount = @($Chapters).Count
  $totalWords = 0
  $emptyChapters = 0
  foreach ($chapter in @($Chapters)) {
    $words = [int]$chapter.words
    $totalWords += $words
    if ($words -le 0) { $emptyChapters++ }
  }

  $targetPages = 0
  if ($null -ne $LongformPlan -and $LongformPlan.PSObject.Properties.Name -contains "target_pages") {
    $targetPages = [int]$LongformPlan.target_pages
  }
  $estimatedPages = if ($totalWords -gt 0) { [math]::Ceiling($totalWords / 280) } else { 0 }
  $lengthRatio = if ($targetPages -gt 0) { [math]::Min(1, $estimatedPages / $targetPages) } else { 0 }

  $approvedCount = 0
  foreach ($key in @($Approvals.Keys)) {
    if (Test-Approved -Value $Approvals[$key]) { $approvedCount++ }
  }

  $hasDocx = @($Exports | Where-Object { $_.kind -eq "DOCX" }).Count -gt 0
  $reportText = (@($Reports) | ForEach-Object { ([string]$_.name + "`n" + [string]$_.text).ToLowerInvariant() }) -join "`n"
  $hasTdk = $reportText -match "tdk|turkish|diacritics|yaz"
  $hasContinuity = $reportText -match "continuity|tutarl|character|plot|ledger"
  $hasTypography = $reportText -match "typography|layout|docx|dizgi|mizanpaj"

  $items = @(
    [ordered]@{ key = "plan"; label = "Plan/onay zinciri"; ok = ($approvedCount -ge 4); detail = "$approvedCount onay dosyası aktif" },
    [ordered]@{ key = "chapters"; label = "Bölüm doluluğu"; ok = ($chapterCount -gt 0 -and $emptyChapters -eq 0); detail = "$chapterCount bölüm, $emptyChapters boş" },
    [ordered]@{ key = "length"; label = "Uzunluk hedefi"; ok = ($targetPages -eq 0 -or $lengthRatio -ge 0.85); detail = "$estimatedPages / $targetPages tahmini sayfa" },
    [ordered]@{ key = "continuity"; label = "Tutarlılık raporu"; ok = $hasContinuity; detail = "karakter/olay kanıtı" },
    [ordered]@{ key = "language"; label = "Türkçe/TDK raporu"; ok = $hasTdk; detail = "dil denetimi kanıtı" },
    [ordered]@{ key = "layout"; label = "Dizgi/DOCX raporu"; ok = ($hasTypography -or $hasDocx); detail = "mizanpaj/export kanıtı" },
    [ordered]@{ key = "export"; label = "Final DOCX"; ok = $hasDocx; detail = if ($hasDocx) { "DOCX bulundu" } else { "DOCX bekleniyor" } }
  )

  $passed = @($items | Where-Object { $_.ok -eq $true }).Count
  $score = [math]::Round(($passed / [math]::Max(1, @($items).Count)) * 100)
  return [ordered]@{
    score = $score
    status = if ($score -ge 86) { "ready" } elseif ($score -ge 60) { "review" } else { "blocked" }
    estimated_pages = $estimatedPages
    target_pages = $targetPages
    total_words = $totalWords
    passed = $passed
    total = @($items).Count
    checks = $items
  }
}

function Get-ChapterHeatmap {
  param(
    [array]$Chapters,
    [object]$ChapterPlan,
    [object]$ChapterSummaries,
    [object]$ContinuityLedger
  )

  $planById = @{}
  if ($null -ne $ChapterPlan -and $ChapterPlan.PSObject.Properties.Name -contains "chapters") {
    foreach ($planned in @($ChapterPlan.chapters)) {
      $id = [string]$planned.id
      if ($id) { $planById[$id.ToLowerInvariant()] = $planned }
    }
  }

  $summaryKeys = @{}
  if ($null -ne $ChapterSummaries -and $ChapterSummaries.PSObject.Properties.Name -contains "chapters") {
    foreach ($summary in @($ChapterSummaries.chapters)) {
      foreach ($candidate in @($summary.id, $summary.chapter_id, $summary.chapter, $summary.filename)) {
        $key = [string]$candidate
        if ($key) { $summaryKeys[$key.ToLowerInvariant()] = $true }
      }
    }
  }

  $continuityText = ""
  if ($null -ne $ContinuityLedger) {
    $continuityText = ($ContinuityLedger | ConvertTo-Json -Depth 12).ToLowerInvariant()
  }

  $items = @()
  foreach ($chapter in @($Chapters)) {
    $filename = [string]$chapter.filename
    $chapterId = [string]$chapter.id
    $number = [regex]::Match($filename + " " + $chapterId, "\d+").Value
    $planKeyCandidates = @($chapterId, "ch$number", "chapter-$number", "ep$number") | ForEach-Object { ([string]$_).ToLowerInvariant() }
    $planned = $null
    foreach ($key in $planKeyCandidates) {
      if ($planById.ContainsKey($key)) { $planned = $planById[$key]; break }
    }

    $targetWords = 0
    if ($null -ne $planned -and $planned.PSObject.Properties.Name -contains "target_words") {
      $targetWords = [int]$planned.target_words
    }

    $words = [int]$chapter.words
    $text = [string]$chapter.text
    $risk = 0
    $reasons = @()
    $action = "inspect"
    $phase = "polish"

    if ($words -le 0) {
      $risk += 45
      $reasons += "Bölüm metni boş."
      $action = "create"
      $phase = "create"
    }
    elseif ($targetWords -gt 0) {
      $ratio = $words / [math]::Max(1, $targetWords)
      if ($ratio -lt 0.72) {
        $risk += 25
        $reasons += "Hedef kelimenin altında."
        $action = "expand"
        $phase = "rewrite"
      }
      elseif ($ratio -gt 1.35) {
        $risk += 15
        $reasons += "Hedef kelimenin üstünde."
        $action = "tighten"
        $phase = "polish"
      }
    }
    elseif ($words -gt 0 -and $words -lt 600) {
      $risk += 20
      $reasons += "Bölüm kitap ölçeği için çok kısa görünüyor."
      $action = "expand"
      $phase = "rewrite"
    }

    $paragraphs = @($text -split "(`r?`n){2,}" | Where-Object { $_.Trim().Length -gt 0 })
    if ($paragraphs.Count -gt 4) {
      $prefixes = @{}
      foreach ($paragraph in $paragraphs) {
        $prefix = ($paragraph.Trim() -replace "\s+", " ")
        if ($prefix.Length -gt 34) { $prefix = $prefix.Substring(0, 34) }
        if (-not $prefixes.ContainsKey($prefix)) { $prefixes[$prefix] = 0 }
        $prefixes[$prefix]++
      }
      $maxRepeat = 0
      foreach ($value in $prefixes.Values) { if ($value -gt $maxRepeat) { $maxRepeat = $value } }
      if ($maxRepeat -ge 3) {
        $risk += 20
        $reasons += "Paragraf başlangıçlarında tekrar riski."
        $action = "rewrite"
        $phase = "rewrite"
      }
    }

    $hasSummary = $false
    foreach ($key in @($filename, $chapterId, "ep$number", "chapter-$number")) {
      if ($summaryKeys.ContainsKey(([string]$key).ToLowerInvariant())) { $hasSummary = $true; break }
    }
    if ($words -gt 0 -and -not $hasSummary) {
      $risk += 15
      $reasons += "Bölüm özeti/ledger güncellemesi yok."
      if ($action -eq "inspect") { $action = "ledger"; $phase = "polish" }
    }

    if ($number -and $continuityText -match [regex]::Escape($number) -and $continuityText -match "violation|risk|issue|tutarl") {
      $risk += 20
      $reasons += "Continuity ledger içinde risk/ihlal izi var."
      $action = "continuity"
      $phase = "rewrite"
    }

    if (-not $reasons.Count) {
      $reasons += "Belirgin risk yok."
      $action = "ok"
      $phase = "none"
    }

    $risk = [math]::Min(100, $risk)
    $level = if ($risk -ge 60) { "high" } elseif ($risk -ge 30) { "medium" } elseif ($risk -gt 0) { "low" } else { "ok" }
    $items += [ordered]@{
      filename = $filename
      id = $chapterId
      risk = $risk
      level = $level
      action = $action
      recommended_phase = $phase
      target_words = $targetWords
      actual_words = $words
      reasons = $reasons
    }
  }
  return $items
}

function Get-ProjectSummary {
  param([object]$Payload)

  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $stateDir = Join-Path $projectRoot "revision/_state"
  $approvalDir = Join-Path $projectRoot "runtime/approvals"
  $episodeDir = Join-Path $projectRoot "episode"
  $exportDir = Join-Path $projectRoot "revision/export"
  $complianceDir = Join-Path $projectRoot "runtime/agent-compliance"
  $workspaceDir = Join-Path $projectRoot "revision/_workspace"

  $chapters = @()
  if (Test-Path -LiteralPath $episodeDir -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File | Sort-Object Name)) {
      $text = Read-Utf8TextIfExists -Path $file.FullName
      $number = [regex]::Match($file.BaseName, "\d+").Value
      $chapterNo = if ($number) { [int]$number } else { $chapters.Count + 1 }
      $chapters += [ordered]@{
        id = "Bölüm $chapterNo"
        title = Get-ReaderTitle -Text $text -Fallback $file.BaseName
        filename = $file.Name
        relativePath = "episode/$($file.Name)"
        words = Get-WordCount -Text $text
        text = $text
      }
    }
  }

  $exports = @()
  if (Test-Path -LiteralPath $exportDir -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $exportDir -File | Sort-Object LastWriteTime -Descending)) {
      if ($file.Extension -match "^\.(docx|pdf|zip|md|json)$") {
        $exports += [ordered]@{
          name = $file.Name
          kind = $file.Extension.TrimStart(".").ToUpperInvariant()
          relativePath = "revision/export/$($file.Name)"
          bytes = $file.Length
          modified = $file.LastWriteTime.ToString("s")
        }
      }
    }
  }

  $approvals = [ordered]@{}
  foreach ($name in @("book-brief-approval.json","story-choice.json","length-depth-approval.json","book-plan-approval.json","design-freeze.json","rewrite-approval.json","export-approval.json")) {
    $approvals[$name] = Read-Utf8JsonIfExists -Path (Join-Path $approvalDir $name)
  }

  $evidence = @()
  foreach ($dir in @($complianceDir, $workspaceDir)) {
    if (Test-Path -LiteralPath $dir -PathType Container) {
      foreach ($file in @(Get-ChildItem -LiteralPath $dir -File | Sort-Object Name)) {
        if ($file.Extension -match "^\.(json|md)$") {
          $evidence += [ordered]@{
            name = $file.Name
            relativePath = ($file.FullName.Substring($projectRoot.Length).TrimStart("\") -replace "\\", "/")
            bytes = $file.Length
          }
        }
      }
    }
  }

  $designDocs = @()
  $designDir = Join-Path $projectRoot "design"
  if (Test-Path -LiteralPath $designDir -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $designDir -Filter "*.md" -File | Sort-Object Name)) {
      $designDocs += [ordered]@{
        name = $file.Name
        relativePath = "design/$($file.Name)"
        text = Read-Utf8TextIfExists -Path $file.FullName
      }
    }
  }

  $reports = @()
  if (Test-Path -LiteralPath $workspaceDir -PathType Container) {
    foreach ($file in @(Get-ChildItem -LiteralPath $workspaceDir -File | Where-Object { $_.Extension -match "^\.(md|json)$" } | Sort-Object LastWriteTime -Descending | Select-Object -First 20)) {
      $text = Read-Utf8TextIfExists -Path $file.FullName
      if ($text.Length -gt 12000) {
        $text = $text.Substring(0, 12000) + "`n`n[truncated by Studio Bridge]"
      }
      $reports += [ordered]@{
        name = $file.Name
        relativePath = ($file.FullName.Substring($projectRoot.Length).TrimStart("\") -replace "\\", "/")
        text = $text
      }
    }
  }

  return [ordered]@{
    ok = $true
    projectRoot = $projectRoot
    name = Split-Path -Leaf $projectRoot
    bookRequest = Read-Utf8TextIfExists -Path (Join-Path $projectRoot "runtime/book-request.md")
    bookRequestChecklist = Get-BookRequestChecklist -Text (Read-Utf8TextIfExists -Path (Join-Path $projectRoot "runtime/book-request.md"))
    bookPlan = Read-Utf8JsonIfExists -Path (Join-Path $stateDir "book-plan.json")
    longformPlan = Read-Utf8JsonIfExists -Path (Join-Path $stateDir "longform-plan.json")
    layoutPlan = Read-Utf8JsonIfExists -Path (Join-Path $stateDir "layout-plan.json")
    chapters = [object[]]@($chapters)
    exports = [object[]]@($exports)
    approvals = $approvals
    evidence = [object[]]@($evidence)
    designDocs = [object[]]@($designDocs)
    reports = [object[]]@($reports)
    quality = Get-QualityAudit -Chapters $chapters -Exports $exports -Approvals $approvals -Reports $reports -LongformPlan (Read-Utf8JsonIfExists -Path (Join-Path $stateDir "longform-plan.json"))
    chapterHeatmap = [object[]]@(Get-ChapterHeatmap -Chapters $chapters -ChapterPlan (Read-Utf8JsonIfExists -Path (Join-Path $stateDir "chapter-plan.json")) -ChapterSummaries (Read-Utf8JsonIfExists -Path (Join-Path $stateDir "chapter-summaries.json")) -ContinuityLedger (Read-Utf8JsonIfExists -Path (Join-Path $stateDir "continuity-ledger.json")))
    lifecycle = [ordered]@{
      status = Read-Utf8JsonIfExists -Path (Join-Path $projectRoot "runtime/project-status.json")
      finalExport = Read-Utf8JsonIfExists -Path (Join-Path $projectRoot "runtime/final-export-manifest.json")
      cleanupApproval = Read-Utf8JsonIfExists -Path (Join-Path $approvalDir "cleanup-approval.json")
    }
  }
}

function Save-BookRequest {
  param([object]$Payload)
  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $runtimeDir = Join-Path $projectRoot "runtime"
  if (-not (Test-Path -LiteralPath $runtimeDir -PathType Container)) {
    New-Item -ItemType Directory -Path $runtimeDir | Out-Null
  }
  $text = [string]$Payload.text
  if (-not $text.Trim()) {
    throw "Book request text is empty."
  }
  $checklist = Get-BookRequestChecklist -Text $text
  [System.IO.File]::WriteAllText((Join-Path $runtimeDir "book-request.md"), $text, [System.Text.UTF8Encoding]::new($true))
  return [ordered]@{ ok = $true; relativePath = "runtime/book-request.md"; characters = $text.Length; words = Get-WordCount -Text $text; checklist = $checklist }
}

function Save-Episode {
  param([object]$Payload)
  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $filename = [string]$Payload.filename
  if ($filename -notmatch "^ep\d+\.md$") {
    throw "Invalid episode filename: $filename"
  }
  $episodeDir = Join-Path $projectRoot "episode"
  if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
    New-Item -ItemType Directory -Path $episodeDir | Out-Null
  }
  $path = Join-Path $episodeDir $filename
  [System.IO.File]::WriteAllText($path, [string]$Payload.text, [System.Text.UTF8Encoding]::new($true))
  return [ordered]@{ ok = $true; relativePath = "episode/$filename"; words = Get-WordCount -Text ([string]$Payload.text) }
}

function Save-LayoutPlan {
  param([object]$Payload)
  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $stateDir = Join-Path $projectRoot "revision/_state"
  if (-not (Test-Path -LiteralPath $stateDir -PathType Container)) {
    New-Item -ItemType Directory -Path $stateDir | Out-Null
  }

  $path = Join-Path $stateDir "layout-plan.json"
  $existing = Read-Utf8JsonIfExists -Path $path
  $layout = [ordered]@{}
  if ($null -ne $existing) {
    foreach ($property in $existing.PSObject.Properties) {
      $layout[$property.Name] = $property.Value
    }
  }

  $font = [string]$Payload.font_family
  if ($font -notin @("Garamond", "Times New Roman", "Georgia", "Palatino Linotype")) {
    throw "Unsupported font_family: $font"
  }
  $fontSize = [double]$Payload.font_size_pt
  $lineSpacing = [double]$Payload.line_spacing
  $top = [double]$Payload.margin_top_mm
  $inside = [double]$Payload.margin_inside_mm
  $outside = [double]$Payload.margin_outside_mm
  $indent = [double]$Payload.paragraph_first_line_indent_cm
  $after = [double]$Payload.paragraph_spacing_after_pt

  if ($fontSize -lt 10 -or $fontSize -gt 13) { throw "font_size_pt must be between 10 and 13." }
  if ($lineSpacing -lt 1 -or $lineSpacing -gt 1.8) { throw "line_spacing must be between 1 and 1.8." }
  foreach ($margin in @($top, $inside, $outside)) {
    if ($margin -lt 10 -or $margin -gt 40) { throw "Margins must be between 10 and 40 mm." }
  }
  if ($indent -lt 0 -or $indent -gt 1.5) { throw "paragraph_first_line_indent_cm must be between 0 and 1.5." }
  if ($after -lt 0 -or $after -gt 12) { throw "paragraph_spacing_after_pt must be between 0 and 12." }

  if (-not $layout.Contains("schema_version")) { $layout["schema_version"] = "1.0.0" }
  if (-not $layout.Contains("run_id")) { $layout["run_id"] = "studio-layout" }
  if (-not $layout.Contains("width_mm")) { $layout["width_mm"] = 148 }
  if (-not $layout.Contains("height_mm")) { $layout["height_mm"] = 210 }
  if (-not $layout.Contains("margin_bottom_mm")) { $layout["margin_bottom_mm"] = $top }
  if (-not $layout.Contains("justification")) { $layout["justification"] = "both" }

  $layout["font_family"] = $font
  $layout["font_size_pt"] = $fontSize
  $layout["line_spacing"] = $lineSpacing
  $layout["margin_top_mm"] = $top
  $layout["margin_inside_mm"] = $inside
  $layout["margin_outside_mm"] = $outside
  $layout["paragraph_first_line_indent_cm"] = $indent
  $layout["paragraph_spacing_after_pt"] = $after
  $layout["studio_updated_at"] = (Get-Date).ToString("o")

  [System.IO.File]::WriteAllText($path, ($layout | ConvertTo-Json -Depth 20), [System.Text.UTF8Encoding]::new($true))
  return [ordered]@{ ok = $true; relativePath = "revision/_state/layout-plan.json"; layoutPlan = $layout }
}

function Write-Approval {
  param([object]$Payload)
  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $file = [string]$Payload.file
  if ($file -notin @("book-brief-approval.json","story-choice.json","length-depth-approval.json","book-plan-approval.json","design-freeze.json","rewrite-approval.json","export-approval.json")) {
    throw "Invalid approval file: $file"
  }
  $approvalDir = Join-Path $projectRoot "runtime/approvals"
  if (-not (Test-Path -LiteralPath $approvalDir -PathType Container)) {
    New-Item -ItemType Directory -Path $approvalDir | Out-Null
  }
  $path = Join-Path $approvalDir $file
  $json = $Payload.approval | ConvertTo-Json -Depth 30
  [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($true))
  return [ordered]@{ ok = $true; relativePath = "runtime/approvals/$file" }
}

function New-StudioProject {
  param([object]$Payload)

  $name = if ($Payload.name) { [string]$Payload.name } else { "" }
  $projectsRoot = if ($Payload.projectsRoot) { [string]$Payload.projectsRoot } else { "" }
  $projectRoot = if ($Payload.projectRoot) { [string]$Payload.projectRoot } else { "" }

  if ($projectRoot.Trim()) {
    $fullProjectRoot = [System.IO.Path]::GetFullPath($projectRoot)
    $name = if ($name.Trim()) { $name } else { Split-Path -Leaf $fullProjectRoot }
    $projectsRoot = Split-Path -Parent $fullProjectRoot
  }

  if (-not $name.Trim()) {
    throw "Project name is required."
  }
  if (-not $projectsRoot.Trim()) {
    $projectsRoot = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "KitHubProjects"
  }

  $newProjectScript = Join-Path $RepoRoot "scripts/new_project.ps1"
  if (-not (Test-Path -LiteralPath $newProjectScript -PathType Leaf)) {
    throw "new_project.ps1 not found under RepoRoot: $RepoRoot"
  }

  $args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $newProjectScript,
    "-Name", $name,
    "-ProjectsRoot", $projectsRoot
  )
  if ($Payload.force -eq $true) {
    $args += "-Force"
  }

  $output = & powershell @args 2>&1
  $exit = $LASTEXITCODE
  $createdRoot = ""
  foreach ($line in @($output)) {
    $text = [string]$line
    if ($text -match "\[new-project\]\s+created:\s+(.+)$") {
      $createdRoot = $Matches[1].Trim()
    }
  }
  if (-not $createdRoot) {
    $slug = $name.ToLowerInvariant() -replace "[^\p{L}\p{Nd}]+", "-"
    $slug = $slug.Trim("-")
    if (-not $slug) { $slug = "kitap-projesi" }
    $createdRoot = Join-Path ([System.IO.Path]::GetFullPath($projectsRoot)) $slug
  }

  return [ordered]@{
    ok = ($exit -eq 0)
    exitCode = $exit
    projectRoot = $createdRoot
    output = (($output | Out-String).Trim())
  }
}

function Invoke-Pipeline {
  param([object]$Payload)

  $validPhases = @("intake","propose","design-big","design-small","create","polish","rewrite","export")
  $validModes = @("manual","command")
  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $fromPhase = if ($Payload.fromPhase) { [string]$Payload.fromPhase } else { "intake" }
  $toPhase = if ($Payload.toPhase) { [string]$Payload.toPhase } else { "export" }
  $mode = if ($Payload.mode) { [string]$Payload.mode } else { "manual" }

  if ($validPhases -notcontains $fromPhase) { throw "Invalid fromPhase: $fromPhase" }
  if ($validPhases -notcontains $toPhase) { throw "Invalid toPhase: $toPhase" }
  if ($validModes -notcontains $mode) { throw "Invalid mode: $mode" }

  if ($toPhase -in @("design-big", "design-small", "create", "polish", "rewrite", "export")) {
    $bookRequestPath = Join-Path $projectRoot "runtime/book-request.md"
    $bookRequest = Read-Utf8TextIfExists -Path $bookRequestPath
    $checklist = Get-BookRequestChecklist -Text $bookRequest
    if ($checklist.complete -ne $true) {
      throw "Studio pipeline blocked: book request is incomplete. Missing: $($checklist.missing -join ', '). Use the Baslangic Sihirbazi before running design/create/export."
    }
  }

  $pipeline = Join-Path $RepoRoot "scripts/run_pipeline.ps1"
  if (-not (Test-Path -LiteralPath $pipeline -PathType Leaf)) {
    throw "run_pipeline.ps1 not found under RepoRoot: $RepoRoot"
  }

  $args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $pipeline,
    "-ProjectRoot", $projectRoot,
    "-FromPhase", $fromPhase,
    "-ToPhase", $toPhase,
    "-Mode", $mode
  )

  if ($mode -eq "command" -and -not $Payload.configPath) {
    $Payload | Add-Member -NotePropertyName configPath -NotePropertyValue (Join-Path $RepoRoot "runtime/runner-config.provider.template.json") -Force
  }

  if ($Payload.configPath) {
    $configPath = [string]$Payload.configPath
    if (-not [System.IO.Path]::IsPathRooted($configPath)) {
      $projectRelativeConfig = Join-Path $projectRoot $configPath
      $repoRelativeConfig = Join-Path $RepoRoot $configPath
      if (Test-Path -LiteralPath $projectRelativeConfig -PathType Leaf) {
        $configPath = $projectRelativeConfig
      }
      else {
        $configPath = $repoRelativeConfig
      }
    }
    if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
      throw "ConfigPath not found: $configPath"
    }
    $args += @("-ConfigPath", (Resolve-Path -LiteralPath $configPath).Path)
  }

  if ($Payload.noWait -eq $true) {
    $args += "-NoWait"
  }

  $output = & powershell @args 2>&1
  $exit = $LASTEXITCODE
  return [ordered]@{
    ok = ($exit -eq 0)
    exitCode = $exit
    projectRoot = $projectRoot
    fromPhase = $fromPhase
    toPhase = $toPhase
    mode = $mode
    output = (($output | Out-String).Trim())
  }
}

function Invoke-FinalExport {
  param([object]$Payload)

  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $destinationDirectory = if ($Payload.destinationDirectory) { [string]$Payload.destinationDirectory } else { [Environment]::GetFolderPath("Desktop") }
  $exportScript = Join-Path $RepoRoot "scripts/export_final.ps1"
  if (-not (Test-Path -LiteralPath $exportScript -PathType Leaf)) {
    throw "export_final.ps1 not found under RepoRoot: $RepoRoot"
  }

  $args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $exportScript,
    "-ProjectRoot", $projectRoot,
    "-DestinationDirectory", $destinationDirectory,
    "-RequireExportApproval"
  )

  $output = & powershell @args 2>&1
  $exit = $LASTEXITCODE
  return [ordered]@{
    ok = ($exit -eq 0)
    exitCode = $exit
    projectRoot = $projectRoot
    destinationDirectory = $destinationDirectory
    manifest = Read-Utf8JsonIfExists -Path (Join-Path $projectRoot "runtime/final-export-manifest.json")
    cleanupApproval = Read-Utf8JsonIfExists -Path (Join-Path $projectRoot "runtime/approvals/cleanup-approval.json")
    output = (($output | Out-String).Trim())
  }
}

function Approve-Cleanup {
  param([object]$Payload)

  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $confirmation = [string]$Payload.confirmation
  if ($confirmation.Trim().ToLowerInvariant() -notin @("roman bitti", "kitap bitti", "bitti", "temizle")) {
    throw "Cleanup approval requires explicit confirmation text: roman bitti"
  }

  $approvalDir = Join-Path $projectRoot "runtime/approvals"
  if (-not (Test-Path -LiteralPath $approvalDir -PathType Container)) {
    New-Item -ItemType Directory -Path $approvalDir | Out-Null
  }
  $approvalPath = Join-Path $approvalDir "cleanup-approval.json"
  $existing = Read-Utf8JsonIfExists -Path $approvalPath
  $finalOutputPath = ""
  if ($null -ne $existing -and $existing.PSObject.Properties.Name -contains "final_output_path") {
    $finalOutputPath = [string]$existing.final_output_path
  }
  $approval = [ordered]@{
    approved = $true
    title = "Cleanup Approval"
    approved_by = "KitHub Studio"
    approved_at = (Get-Date).ToString("o")
    final_output_preserved = $true
    final_output_path = $finalOutputPath
    user_confirmed_book_finished = $true
    user_must_confirm_book_finished = $true
    confirmation = $confirmation
    note = "User explicitly confirmed the book is finished and working files may be removed."
  }
  [System.IO.File]::WriteAllText($approvalPath, ($approval | ConvertTo-Json -Depth 10), [System.Text.UTF8Encoding]::new($true))
  return [ordered]@{ ok = $true; relativePath = "runtime/approvals/cleanup-approval.json"; approval = $approval }
}

function Invoke-CleanupProject {
  param([object]$Payload)

  $projectRoot = Resolve-ExistingDirectory -Path ([string]$Payload.projectRoot)
  $cleanupScript = Join-Path $RepoRoot "scripts/cleanup_project.ps1"
  if (-not (Test-Path -LiteralPath $cleanupScript -PathType Leaf)) {
    throw "cleanup_project.ps1 not found under RepoRoot: $RepoRoot"
  }
  $args = @(
    "-ExecutionPolicy", "Bypass",
    "-File", $cleanupScript,
    "-ProjectRoot", $projectRoot
  )
  $output = & powershell @args 2>&1
  $exit = $LASTEXITCODE
  return [ordered]@{
    ok = ($exit -eq 0)
    exitCode = $exit
    projectRoot = $projectRoot
    status = Read-Utf8JsonIfExists -Path (Join-Path $projectRoot "runtime/project-status.json")
    output = (($output | Out-String).Trim())
  }
}

function Read-HttpRequest {
  param([System.Net.Sockets.NetworkStream]$Stream)

  $buffer = New-Object byte[] 8192
  $memory = New-Object System.IO.MemoryStream
  $headerEnd = -1
  $contentLength = 0
  do {
    $read = $Stream.Read($buffer, 0, $buffer.Length)
    if ($read -le 0) { break }
    $memory.Write($buffer, 0, $read)
    $bytes = $memory.ToArray()
    $raw = [System.Text.Encoding]::ASCII.GetString($bytes)
    $headerEnd = $raw.IndexOf("`r`n`r`n", [System.StringComparison]::Ordinal)
    if ($headerEnd -ge 0) {
      $headersText = $raw.Substring(0, $headerEnd)
      foreach ($line in ($headersText -split "`r`n")) {
        if ($line -match "^\s*Content-Length\s*:\s*(\d+)\s*$") {
          $contentLength = [int]$Matches[1]
        }
      }
      if ($bytes.Length -ge ($headerEnd + 4 + $contentLength)) { break }
    }
  } while ($true)

  $allBytes = $memory.ToArray()
  if ($headerEnd -lt 0) { throw "Invalid HTTP request." }
  $headerText = [System.Text.Encoding]::ASCII.GetString($allBytes, 0, $headerEnd)
  $requestLine = ($headerText -split "`r`n")[0]
  if ($requestLine -notmatch "^(GET|POST|OPTIONS)\s+([^\s]+)\s+HTTP/") {
    throw "Unsupported HTTP request line: $requestLine"
  }
  $body = ""
  if ($contentLength -gt 0) {
    $bodyStart = $headerEnd + 4
    $body = [System.Text.Encoding]::UTF8.GetString($allBytes, $bodyStart, $contentLength)
  }
  $uri = [System.Uri]::new("http://127.0.0.1$($Matches[2])")
  return [ordered]@{
    Method = $Matches[1]
    Path = $uri.AbsolutePath
    Body = $body
  }
}

function Read-RequestBodyJson {
  param([string]$Body)
  if (-not $Body.Trim()) { return [pscustomobject]@{} }
  return $Body | ConvertFrom-Json
}

function Write-HttpResponse {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [byte[]]$BodyBytes,
    [string]$ContentType,
    [int]$StatusCode = 200
  )
  $reason = if ($StatusCode -eq 200) { "OK" } elseif ($StatusCode -eq 404) { "Not Found" } else { "Error" }
  $headers = @(
    "HTTP/1.1 $StatusCode $reason",
    "Content-Type: $ContentType",
    "Content-Length: $($BodyBytes.Length)",
    "Access-Control-Allow-Origin: *",
    "Access-Control-Allow-Methods: GET,POST,OPTIONS",
    "Access-Control-Allow-Headers: content-type",
    "Connection: close",
    "",
    ""
  ) -join "`r`n"
  $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headers)
  $Stream.Write($headerBytes, 0, $headerBytes.Length)
  if ($BodyBytes.Length -gt 0) {
    $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
  }
}

function Write-JsonHttpResponse {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [object]$Value,
    [int]$StatusCode = 200
  )
  $json = $Value | ConvertTo-Json -Depth 20
  Write-HttpResponse -Stream $Stream -BodyBytes ([System.Text.Encoding]::UTF8.GetBytes($json)) -ContentType "application/json; charset=utf-8" -StatusCode $StatusCode
}

function Write-FileHttpResponse {
  param(
    [System.Net.Sockets.NetworkStream]$Stream,
    [string]$Path,
    [string]$ContentType
  )
  Write-HttpResponse -Stream $Stream -BodyBytes ([System.IO.File]::ReadAllBytes($Path)) -ContentType $ContentType
}

$prefix = "http://127.0.0.1:$Port/"
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Parse("127.0.0.1"), $Port)
$listener.Start()

Write-Host "[studio-bridge] listening at $prefix"
Write-Host "[studio-bridge] open $prefix in Chrome/Edge"
Write-Host "[studio-bridge] press Ctrl+C to stop"

try {
  while ($true) {
    $client = $listener.AcceptTcpClient()
    try {
      $stream = $client.GetStream()
      $request = Read-HttpRequest -Stream $stream
      $method = [string]$request.Method
      $path = ([string]$request.Path).TrimEnd("/")
      if ($path -eq "") { $path = "/" }

      try {
        if ($method -eq "OPTIONS") {
          Write-JsonHttpResponse -Stream $stream -Value ([ordered]@{ ok = $true })
          continue
        }

        if ($method -eq "GET" -and $path -eq "/") {
          Write-FileHttpResponse -Stream $stream -Path (Join-Path $RepoRoot "index.html") -ContentType "text/html; charset=utf-8"
          continue
        }

        if ($method -eq "GET" -and $path -eq "/api/health") {
          Write-JsonHttpResponse -Stream $stream -Value ([ordered]@{
            ok = $true
            service = "KitHub Studio Bridge"
            repoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
            port = $Port
          })
          continue
        }

        if ($method -eq "GET" -and $path -eq "/api/provider-settings") {
          Write-JsonHttpResponse -Stream $stream -Value (Get-ProviderSettings)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/provider-settings") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Save-ProviderSettings -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/run-pipeline") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          $result = Invoke-Pipeline -Payload $payload
          $status = if ($result.ok) { 200 } else { 500 }
          Write-JsonHttpResponse -Stream $stream -Value $result -StatusCode $status
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/project-summary") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Get-ProjectSummary -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/new-project") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          $result = New-StudioProject -Payload $payload
          $status = if ($result.ok) { 200 } else { 500 }
          Write-JsonHttpResponse -Stream $stream -Value $result -StatusCode $status
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/save-book-request") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Save-BookRequest -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/save-episode") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Save-Episode -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/save-layout-plan") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Save-LayoutPlan -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/write-approval") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Write-Approval -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/export-final") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          $result = Invoke-FinalExport -Payload $payload
          $status = if ($result.ok) { 200 } else { 500 }
          Write-JsonHttpResponse -Stream $stream -Value $result -StatusCode $status
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/approve-cleanup") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          Write-JsonHttpResponse -Stream $stream -Value (Approve-Cleanup -Payload $payload)
          continue
        }

        if ($method -eq "POST" -and $path -eq "/api/cleanup-project") {
          $payload = Read-RequestBodyJson -Body ([string]$request.Body)
          $result = Invoke-CleanupProject -Payload $payload
          $status = if ($result.ok) { 200 } else { 500 }
          Write-JsonHttpResponse -Stream $stream -Value $result -StatusCode $status
          continue
        }

        Write-JsonHttpResponse -Stream $stream -Value ([ordered]@{ ok = $false; error = "Not found" }) -StatusCode 404
      }
      catch {
        Write-JsonHttpResponse -Stream $stream -Value ([ordered]@{ ok = $false; error = $_.Exception.Message }) -StatusCode 500
      }
    }
    finally {
      $client.Close()
    }
  }
}
finally {
  $listener.Stop()
}
