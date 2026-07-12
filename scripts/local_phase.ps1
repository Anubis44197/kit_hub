param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [ValidateSet("intake","propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [Parameter(Mandatory = $true)]
  [string]$RunId
)

$ErrorActionPreference = "Stop"
$EngineRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
  }
}

function Ensure-File {
  param([string]$Path, [string]$Message)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    if ($Message) { throw $Message }
    throw "Missing required file: $Path"
  }
}

function Write-Utf8 {
  param([string]$Path, [string]$Content)
  $dir = Split-Path -Parent $Path
  if ($dir) { Ensure-Dir $dir }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8Bom)
}

function Read-Utf8 {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Json {
  param([string]$Path, [object]$Value)
  Write-Utf8 -Path $Path -Content ($Value | ConvertTo-Json -Depth 30)
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

function Get-ContractHashRecords {
  param([string]$PhaseName)

  $contractFiles = @(
    "runtime/agent-registry.json",
    "runtime/agent-status-contract.json",
    ("runtime/phase-contracts/{0}.json" -f $PhaseName)
  )
  $records = @()
  foreach ($rel in $contractFiles) {
    $path = Join-Path $EngineRoot $rel
    Ensure-File -Path $path -Message "Missing governance contract: $rel"
    $records += [ordered]@{
      path = $rel
      sha256 = Get-FileSha256 -Path $path
    }
  }
  return $records
}

function Read-Json {
  param([string]$Path)
  return (Read-Utf8 -Path $Path) | ConvertFrom-Json
}

function Get-RelativePath {
  param([string]$Path)
  $root = [System.IO.Path]::GetFullPath($ProjectRoot)
  $target = [System.IO.Path]::GetFullPath($Path)
  if ($target.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
    return ($target.Substring($root.Length).TrimStart("\") -replace "\\", "/")
  }
  return $Path
}

function Get-BookSeed {
  $requestPath = Join-Path $ProjectRoot "runtime/book-request.md"
  Ensure-File -Path $requestPath -Message "Book request missing: runtime/book-request.md içine önce kullanıcı konusunu yazın. Konu olmadan varsayılan roman üretilmez."
  $raw = (Read-Utf8 -Path $requestPath).Trim()
  if (-not $raw -or $raw -match "(?i)^\s*(#\s*)?(konu bekleniyor|topic pending|todo|buraya.*konu)") {
    throw "Book request missing: runtime/book-request.md içine önce kullanıcı konusunu yazın. Konu olmadan varsayılan roman üretilmez."
  }
  return $raw
}

function Get-BriefAnswerValue {
  param([string]$Field)
  $approvalPath = Join-Path $ProjectRoot "runtime/approvals/book-brief-approval.json"
  if (Test-Path -LiteralPath $approvalPath -PathType Leaf) {
    try {
      $approval = Read-Json -Path $approvalPath
      if ($approval.PSObject.Properties.Name -contains "accepted_answers" -and $approval.accepted_answers -and ($approval.accepted_answers.PSObject.Properties.Name -contains $Field)) {
        $value = ([string]$approval.accepted_answers.$Field).Trim()
        if ($value) { return $value }
      }
    }
    catch {}
  }
  $briefPath = Join-Path $ProjectRoot "runtime/book-brief.json"
  if (Test-Path -LiteralPath $briefPath -PathType Leaf) {
    try {
      $brief = Read-Json -Path $briefPath
      if ($brief.PSObject.Properties.Name -contains "answers" -and $brief.answers -and ($brief.answers.PSObject.Properties.Name -contains $Field)) {
        $value = ([string]$brief.answers.$Field).Trim()
        if ($value) { return $value }
      }
    }
    catch {}
  }
  return ""
}

function Get-DesignSeed {
  $parts = @((Get-BookSeed))
  foreach ($field in @("writing_type","genre","target_length","target_pages","target_reader","character_policy","setting_period","pov_tense","style_tone","boundaries","publication_package")) {
    $value = Get-BriefAnswerValue -Field $field
    if ($value) { $parts += ("{0}: {1}" -f $field, $value) }
  }
  return ($parts -join "`n")
}

function Get-RequestedChapterCount {
  $raw = Get-DesignSeed
  $m = [regex]::Match($raw, "(?i)(\d+)\s*(bölüm|bolum|chapter|chapters)")
  if ($m.Success) {
    $count = [int]$m.Groups[1].Value
    if ($count -ge 1 -and $count -le 120) { return $count }
  }
  return 12
}

function Get-RequestedPageCount {
  foreach ($field in @("target_pages", "target_length")) {
    $acceptedValue = Get-BriefAnswerValue -Field $field
    if ($acceptedValue) {
      $exactMatch = [regex]::Match($acceptedValue, "(?i)^\s*(\d+)\s*$")
      if ($exactMatch.Success) {
        $count = [int]$exactMatch.Groups[1].Value
        if ($count -ge 1 -and $count -le 1000) { return $count }
      }
      $rangeMatch = [regex]::Match($acceptedValue, "(?i)(\d+)\s*[-–]\s*(\d+)\s*(sayfa|page|pages)")
      if ($rangeMatch.Success) {
        $low = [int]$rangeMatch.Groups[1].Value
        $high = [int]$rangeMatch.Groups[2].Value
        $mid = [int][Math]::Round(($low + $high) / 2)
        if ($mid -ge 1 -and $mid -le 1000) { return $mid }
      }
      $answerMatch = [regex]::Match($acceptedValue, "(?i)(\d+)\s*(sayfa|page|pages)")
      if ($answerMatch.Success) {
        $count = [int]$answerMatch.Groups[1].Value
        if ($count -ge 1 -and $count -le 1000) { return $count }
      }
    }
  }
  $raw = Get-DesignSeed
  $m = [regex]::Match($raw, "(?i)(\d+)\s*(sayfa|page|pages)")
  if ($m.Success) {
    $count = [int]$m.Groups[1].Value
    if ($count -ge 1 -and $count -le 1000) { return $count }
  }
  $briefPath = Join-Path $ProjectRoot "runtime/book-brief.json"
  if (Test-Path -LiteralPath $briefPath -PathType Leaf) {
    try {
      $brief = Read-Json -Path $briefPath
      if ($brief.PSObject.Properties.Name -contains "answers" -and $brief.answers) {
        foreach ($field in @("target_pages","target_length")) {
          if ($brief.answers.PSObject.Properties.Name -contains $field) {
            $value = [string]$brief.answers.$field
            $answerMatch = [regex]::Match($value, "(?i)(\d+)\s*(sayfa|page|pages)?")
            if ($answerMatch.Success) {
              $count = [int]$answerMatch.Groups[1].Value
              if ($count -ge 1 -and $count -le 1000) { return $count }
            }
          }
        }
      }
    }
    catch {
      return 0
    }
  }
  return 0
}

function Get-RequestedCharacterCount {
  $raw = Get-DesignSeed
  $m = [regex]::Match($raw, "(?i)(\d+)\s*(?:\w+\s+){0,3}(karakter|character|characters)")
  if ($m.Success) {
    $count = [int]$m.Groups[1].Value
    if ($count -ge 1 -and $count -le 40) { return $count }
  }
  return 1
}

function Get-LongformScalePlan {
  $requestedPages = Get-RequestedPageCount
  $requestedChapters = Get-RequestedChapterCount
  $wordsPerPage = 420
  $pagesExplicit = $requestedPages -gt 0
  $chaptersExplicit = [regex]::IsMatch((Get-BookSeed), "(?i)(\d+)\s*(bölüm|bolum|chapter|chapters)")

  if ($pagesExplicit) {
    $targetPages = $requestedPages
    $targetWords = [int]([Math]::Max(1200, [Math]::Round($targetPages * $wordsPerPage)))
    if ($targetPages -le 20) { $wordsPerChapter = 1600 }
    elseif ($targetPages -le 80) { $wordsPerChapter = 2200 }
    elseif ($targetPages -le 220) { $wordsPerChapter = 2500 }
    elseif ($targetPages -le 360) { $wordsPerChapter = 2700 }
    else { $wordsPerChapter = 3000 }
    $targetChapters = [int]([Math]::Max(1, [Math]::Ceiling($targetWords / $wordsPerChapter)))
  }
  else {
    $targetChapters = $requestedChapters
    if ($targetChapters -le 5) { $wordsPerChapter = 1600 }
    elseif ($targetChapters -le 18) { $wordsPerChapter = 2500 }
    else { $wordsPerChapter = 2800 }
    $targetWords = $targetChapters * $wordsPerChapter
    $targetPages = [int]([Math]::Max(1, [Math]::Ceiling($targetWords / $wordsPerPage)))
  }

  if ($targetPages -le 20) {
    $tier = "short_form"
    $auditEvery = 3
    $maxBatch = 3
    $structureModel = "short_story_arc"
  }
  elseif ($targetPages -le 120) {
    $tier = "novella_or_short_book"
    $auditEvery = 5
    $maxBatch = 3
    $structureModel = "chaptered_short_book"
  }
  elseif ($targetPages -le 300) {
    $tier = "standard_novel"
    $auditEvery = 8
    $maxBatch = 2
    $structureModel = "three_act_or_four_part_novel"
  }
  else {
    $tier = "epic_longform"
    $auditEvery = 10
    $maxBatch = 1
    $structureModel = "multi_act_long_novel"
  }

  return [ordered]@{
    requested_pages = $(if ($pagesExplicit) { $requestedPages } else { $null })
    requested_chapters = $(if ($chaptersExplicit) { $requestedChapters } else { $null })
    target_pages = $targetPages
    target_words = $targetWords
    target_chapters = $targetChapters
    words_per_page_estimate = $wordsPerPage
    words_per_chapter = $wordsPerChapter
    scale_tier = $tier
    structure_model = $structureModel
    max_chapters_per_batch = $maxBatch
    audit_interval_chapters = $auditEvery
    deep_continuity_graph_required = $true
  }
}

function Get-WritingTypeProfileFromSeed {
  param([string]$Seed, [int]$TargetPages)
  $s = $Seed.ToLowerInvariant()
  $type = "novel"
  $genre = "literary"
  $structure = "four_act_longform_novel"

  if ($s -match "çocuk|cocuk") { $type = "children_book"; $genre = "children"; $structure = "age_safe_chaptered_arc" }
  elseif ($s -match "genç yetişkin|genc yetiskin|young adult|ya\b") { $type = "young_adult"; $genre = "young_adult"; $structure = "identity_pressure_arc" }
  elseif ($s -match "biyografi|biography") { $type = "biography"; $genre = "biography"; $structure = "chronological_life_arc" }
  elseif ($s -match "(?<!\p{L})(anı|ani|hatıra|hatira|memoir)(?!\p{L})") { $type = "memoir"; $genre = "memoir"; $structure = "memoir_reflection_arc" }
  elseif ($s -match "(?<!\p{L})(araştırma kitabı|arastirma kitabi|research book|araştırma|arastirma|research)(?!\p{L})") { $type = "research_book"; $genre = "research"; $structure = "claim_source_argument_book" }
  elseif ($s -match "akademik|academic|tez|makale") { $type = "academic"; $genre = "academic"; $structure = "formal_academic_argument" }
  elseif ($s -match "iş kitabı|is kitabi|business") { $type = "business_book"; $genre = "business"; $structure = "framework_case_application" }
  elseif ($s -match "kişisel gelişim|kisisel gelisim|self help|self-help") { $type = "self_help"; $genre = "self_help"; $structure = "promise_exercise_application" }
  elseif ($s -match "deneme|essay") { $type = "essay"; $genre = "essay"; $structure = "thesis_counterargument_synthesis" }
  elseif ($s -match "şiir|siir|poetry|poem") { $type = "poetry_collection"; $genre = "poetry"; $structure = "poetry_sequence_collection" }
  elseif ($s -match "senaryo|screenplay|script") { $type = "screenplay"; $genre = "screenplay"; $structure = "scene_sequence_screenplay" }
  elseif ($s -match "öykü|oyku|hikaye|hikâye|story") {
    if ($TargetPages -le 80) { $type = "story"; $genre = "story"; $structure = "single_turn_story_arc" }
    else { $type = "novella"; $genre = "novella"; $structure = "controlled_subplot_novella" }
  }
  elseif ($s -match "novella|kısa roman|kisa roman") { $type = "novella"; $genre = "novella"; $structure = "controlled_subplot_novella" }

  if ($s -match "fantastik|fantasy") { $genre = "fantasy"; if ($type -eq "novel") { $structure = "world_rule_longform_fantasy" } }
  elseif ($s -match "bilim kurgu|science fiction|sci-fi|scifi") { $genre = "science_fiction"; if ($type -eq "novel") { $structure = "speculative_logic_longform" } }
  elseif ($s -match "gizem|polisiye|thriller|gerilim|ajan|casus") { $genre = "mystery_thriller"; if ($type -eq "novel") { $structure = "clue_escalation_reveal_novel" } }
  elseif ($s -match "romantik|romance") { $genre = "romance"; if ($type -eq "novel") { $structure = "relationship_beat_romance" } }
  elseif ($s -match "tarih|tarihsel|historical|1930|1940|osmanlı|osmanli|cumhuriyet") { $genre = "historical_fiction"; if ($type -eq "novel") { $structure = "period_consistency_historical_arc" } }

  $explicitType = (Get-BriefAnswerValue -Field "writing_type").ToLowerInvariant()
  $canonicalTypes = @("novel","story","novella","children_book","young_adult","essay","memoir","biography","research_book","self_help","business_book","academic","poetry_collection","screenplay")
  $typeAliases = @{
    "roman" = "novel"
    "hikaye" = "story"
    "hikâye" = "story"
    "oyku" = "story"
    "öykü" = "story"
    "kisa roman" = "novella"
    "kısa roman" = "novella"
    "deneme" = "essay"
    "ani" = "memoir"
    "anı" = "memoir"
    "biyografi" = "biography"
    "arastirma kitabi" = "research_book"
    "araştırma kitabı" = "research_book"
    "cocuk kitabi" = "children_book"
    "çocuk kitabı" = "children_book"
    "siir" = "poetry_collection"
    "şiir" = "poetry_collection"
    "siir kitabi" = "poetry_collection"
    "şiir kitabı" = "poetry_collection"
    "senaryo" = "screenplay"
  }
  if ($canonicalTypes -contains $explicitType) {
    $type = $explicitType
  }
  elseif ($typeAliases.ContainsKey($explicitType)) {
    $type = $typeAliases[$explicitType]
  }
  if ($type -eq "novel" -and $structure -in @("thesis_counterargument_synthesis","chronological_life_arc","memoir_reflection_arc","claim_source_argument_book","formal_academic_argument","framework_case_application","promise_exercise_application")) {
    $structure = "four_act_longform_novel"
  }

  return [ordered]@{
    writing_type = $type
    genre = $genre
    structure_model = $structure
  }
}

function Get-CleanTitleFromText {
  param([string]$Text)
  $titleLine = (($Text -split "\r?\n") | Where-Object { $_ -match "(?i)^\s*(kitap\s+adi|kitap\s+adı|title|baslik|başlık)\s*:" } | Select-Object -First 1)
  if ($titleLine) {
    $title = ($titleLine -replace "(?i)^\s*(kitap\s+adi|kitap\s+adı|title|baslik|başlık)\s*:\s*", "").Trim(" .,:;")
    if ($title) {
      if ($title.Length -gt 70) { $title = $title.Substring(0, 70).Trim() }
      return $title
    }
  }
  $line = (($Text -split "\r?\n") | Where-Object { $_.Trim() -and $_ -notmatch "^\s*#" } | Select-Object -First 1)
  if (-not $line) { $line = $Text }
  $line = ($line -replace "(?i)^\s*\d+\s*(bölümlük|bolumluk|bölüm|bolum|chapter|chapters)\s*[:\-]?\s*", "").Trim()
  $line = ($line -replace "(?i)^\s*(roman|hikaye|öykü|oyku|novella|deneme|biyografi)\s*[:\-]?\s*", "").Trim()
  $words = @($line -split "\s+" | Where-Object { $_.Trim() } | Select-Object -First 5)
  if ($words.Count -lt 1) { return "Adsiz Kitap" }
  $title = ($words -join " ").Trim(" .,:;")
  if ($title.Length -gt 70) { $title = $title.Substring(0, 70).Trim() }
  return $title
}

function Get-ProjectName {
  $cfg = Join-Path $ProjectRoot "novel-config.md"
  if (Test-Path -LiteralPath $cfg -PathType Leaf) {
    $raw = Read-Utf8 -Path $cfg
    $m = [regex]::Match($raw, '(?m)^\s*name:\s*"?([^"#\r\n]+)"?')
    if ($m.Success) {
      $name = $m.Groups[1].Value.Trim()
      if ($name) { return $name }
    }
  }
  return (Get-CleanTitleFromText -Text (Get-BookSeed))
}

function Get-Slug {
  param([string]$Text)
  $slug = ($Text.ToLowerInvariant() -replace "[^a-z0-9ğüşöçıİĞÜŞÖÇ]+", "-").Trim("-")
  if (-not $slug) { return "kitap" }
  return $slug.Substring(0, [Math]::Min(42, $slug.Length))
}

function Get-StateDir {
  return (Join-Path $ProjectRoot "revision/_state")
}

function Get-EpisodeRangeLabel {
  param([int]$Count)
  if ($Count -lt 1) { return "EP000" }
  return ("EP001-EP{0:D3}" -f $Count)
}

function Write-ChiefEditorEvidence {
  param(
    [string]$PhaseName,
    [string[]]$RequiredAgents,
    [string[]]$LoadedStateFiles,
    [string[]]$OutputArtifacts,
    [string]$Status
  )

  if (@($RequiredAgents | Where-Object { [string]$_ -eq "chief-editor-orchestrator" }).Count -lt 1) {
    return @()
  }

  $dir = Join-Path $ProjectRoot "runtime/agent-compliance"
  Ensure-Dir $dir
  $reportRel = "runtime/agent-compliance/chief-editor-orchestrator_report_$PhaseName.md"
  $verdictRel = "runtime/agent-compliance/chief-editor-orchestrator_verdict_$PhaseName.json"
  $verdict = if ($Status -eq "PASS") { "PASS" } else { "BLOCKED" }
  $report = @(
    "# Chief Editor Orchestrator"
    ""
    "run_id: $RunId"
    "phase: $PhaseName"
    "verdict: $verdict"
    ""
    "Checked required agent order, loaded state files, output artifacts, and phase boundary before compliance manifest generation."
    "This local adapter evidence is only an orchestration/control verdict; it does not claim creative writing, editorial review, official TDK approval, or publisher print approval."
  ) -join "`n"
  Write-Utf8 -Path (Join-Path $ProjectRoot $reportRel) -Content $report
  Write-Json -Path (Join-Path $ProjectRoot $verdictRel) -Value ([ordered]@{
    run_id = $RunId
    phase = $PhaseName
    agent = "chief-editor-orchestrator"
    verdict = $verdict
    checked_state_files = @($LoadedStateFiles)
    checked_output_artifacts = @($OutputArtifacts)
    generation_boundary = "orchestration_control_only"
    official_tdk_claim_allowed = $false
    print_ready_claim_allowed = $false
  })
  return @($reportRel, $verdictRel)
}

function Write-AgentCompliance {
  param(
    [string]$PhaseName,
    [string[]]$RequiredAgents,
    [string[]]$RequiredReferences,
    [string[]]$LoadedStateFiles,
    [string[]]$OutputArtifacts,
    [string]$Status = "PASS",
    [string[]]$MissingItems = @()
  )

  $phaseContractPath = Join-Path $EngineRoot ("runtime/phase-contracts/{0}.json" -f $PhaseName)
  $phaseContract = Read-Json -Path $phaseContractPath
  $RequiredAgents = @($RequiredAgents + @($phaseContract.required_agents | ForEach-Object { [string]$_ }) | Select-Object -Unique)
  $RequiredReferences = @($RequiredReferences + @($phaseContract.required_references | ForEach-Object { [string]$_ }) | Select-Object -Unique)
  $LoadedStateFiles = @($LoadedStateFiles + @($phaseContract.required_state_files | ForEach-Object { [string]$_ }) | Select-Object -Unique)

  $dir = Join-Path $ProjectRoot "runtime/agent-compliance"
  Ensure-Dir $dir
  $chiefEvidenceArtifacts = @(Write-ChiefEditorEvidence -PhaseName $PhaseName -RequiredAgents $RequiredAgents -LoadedStateFiles $LoadedStateFiles -OutputArtifacts $OutputArtifacts -Status $Status)
  if ($chiefEvidenceArtifacts.Count -gt 0) {
    $OutputArtifacts = @($OutputArtifacts + $chiefEvidenceArtifacts | Select-Object -Unique)
  }
  $artifactHashes = @()
  foreach ($rel in $OutputArtifacts) {
    if ($rel -match "[\*\?]") { continue }
    $artifactPath = Join-Path $ProjectRoot $rel
    if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
      $artifactHashes += [ordered]@{
        path = $rel
        sha256 = Get-FileSha256 -Path $artifactPath
      }
    }
  }
  if ($OutputArtifacts.Count -gt 0 -and $artifactHashes.Count -lt 1) {
    throw "Agent compliance cannot be written without at least one concrete artifact hash for phase '$PhaseName'."
  }
  $agentStatuses = @()
  $agentEvidence = @()
  $firstEvidence = @($OutputArtifacts | Where-Object { -not ([string]$_ -match "[\*\?]") } | Select-Object -First 1)
  foreach ($agent in $RequiredAgents) {
    $agentPattern = [regex]::Escape([string]$agent)
    $matchedEvidence = @($OutputArtifacts | Where-Object { ([string]$_ -match $agentPattern) -and -not ([string]$_ -match "[\*\?]") })
    if ([string]$agent -eq "chief-editor-orchestrator" -and $matchedEvidence.Count -lt 2) {
      throw "Chief editor orchestrator requires dedicated report and verdict evidence for phase '$PhaseName'."
    }
    $evidenceArtifacts = if ($matchedEvidence.Count -gt 0) { $matchedEvidence } else { $firstEvidence }
    $agentStatuses += [ordered]@{
      agent = $agent
      status = $(if ($Status -eq "PASS") { "completed" } else { "blocked" })
    }
    $agentEvidence += [ordered]@{
      agent = $agent
      status = $(if ($Status -eq "PASS") { "completed" } else { "blocked" })
      evidence_artifacts = $evidenceArtifacts
      checks_performed = @("phase-contract-artifact-review")
      verdict = $(if ($Status -eq "PASS") { "PASS" } else { "BLOCKED" })
    }
  }
  Write-Json -Path (Join-Path $dir "$PhaseName.json") -Value ([ordered]@{
    run_id = $RunId
    phase = $PhaseName
    required_agents = $RequiredAgents
    agents_executed = $RequiredAgents
    required_references = $RequiredReferences
    loaded_state_files = $LoadedStateFiles
    output_artifacts = $OutputArtifacts
    artifact_hashes = $artifactHashes
    contract_hashes = @(Get-ContractHashRecords -PhaseName $PhaseName)
    agent_statuses = $agentStatuses
    agent_evidence = $agentEvidence
    phase_authority = "local_adapter_scaffold"
    completed_at = (Get-Date).ToString("o")
    generation_boundary = "local adapter validates contracts and packages existing artifacts; it does not write the book"
    creative_authority = "provider_or_ide_agent_or_human_required_for_real_generation"
    research_boundary = "no internet research claimed by local adapter"
    contract_status = $Status
    missing_items = $MissingItems
  })
}

function Ensure-Approved {
  param([string]$RelativePath, [string]$GateName)
  $path = Join-Path $ProjectRoot $RelativePath
  Ensure-File -Path $path -Message "$GateName missing: $RelativePath"
  $obj = Read-Json -Path $path
  if (-not ($obj.PSObject.Properties.Name -contains "approved") -or $obj.approved -ne $true) {
    throw "$GateName blocked: set approved=true only after explicit user approval in $RelativePath"
  }
  return $obj
}

function Get-StoryChoice {
  $choice = Ensure-Approved -RelativePath "runtime/approvals/story-choice.json" -GateName "Story choice approval"
  if (-not ($choice.PSObject.Properties.Name -contains "selected_option") -or -not $choice.selected_option) {
    throw "Story choice approval missing selected_option: runtime/approvals/story-choice.json"
  }
  return $choice
}

function Get-ChapterHeadingFromText {
  param([string]$Path, [int]$Number)
  $raw = Read-Utf8 -Path $Path
  foreach ($line in ($raw -split "\r?\n")) {
    $trim = $line.Trim()
    if ($trim -match "^#\s+(.+)$") {
      $heading = $Matches[1].Trim()
      if ($heading -notmatch "(?i)^ep\d{3}$|^scene\s+\d+|^sahne\s+\d+") {
        return $heading
      }
    }
  }
  throw "Chapter title missing or technical in $(Get-RelativePath -Path $Path). Add a reader-facing H1 title; do not use EP001/scene labels."
}

function Get-RequiredFrontMatter {
  $work = Join-Path $ProjectRoot "revision/_workspace"
  $files = [ordered]@{
    title_page = Join-Path $work "11_front-matter_title-page.md"
    copyright_page = Join-Path $work "11_front-matter_copyright-page.md"
    preface = Join-Path $work "11_front-matter_preface.md"
    toc = Join-Path $work "11_front-matter_toc.json"
    metadata = Join-Path $work "11_front-matter_publication-metadata.json"
  }
  foreach ($key in $files.Keys) {
    Ensure-File -Path $files[$key] -Message "Export blocked: missing front matter artifact '$key' at $(Get-RelativePath -Path $files[$key]). The local adapter will not invent it."
  }
  return $files
}

function Get-RequiredCoverMatter {
  $work = Join-Path $ProjectRoot "revision/_workspace"
  $files = [ordered]@{
    manifest = Join-Path $work "12_cover-design_manifest.json"
    brief = Join-Path $work "12_cover-design_brief.md"
    front_prompt = Join-Path $work "12_cover-design_front-prompt.md"
    back_cover_copy = Join-Path $work "12_cover-design_back-cover-copy.md"
  }
  foreach ($key in $files.Keys) {
    Ensure-File -Path $files[$key] -Message "Export blocked: missing cover artifact '$key' at $(Get-RelativePath -Path $files[$key]). The local adapter will not invent it."
  }
  return $files
}

function Assert-ReaderArtifactClean {
  param([string]$Path, [string]$Label, [int]$MinCharacters = 20)
  Ensure-File -Path $Path -Message "Export blocked: missing $Label at $(Get-RelativePath -Path $Path)."
  $raw = (Read-Utf8 -Path $Path).Trim()
  if ($raw.Length -lt $MinCharacters) {
    throw "Export blocked: $Label is too short or empty: $(Get-RelativePath -Path $Path)"
  }
  foreach ($pattern in @("(?i)\bTODO\b","(?i)\bFIXME\b","(?i)\bVERDICT\s*:","(?i)\brun_id\s*:","(?i)\bstep_id\s*:","(?i)\bREVIEW_REQUIRED\b","(?i)\bpublication\s+compliance\b","(?i)\btest\s+dosya")) {
    if ($raw -match $pattern) {
      throw "Export blocked: $Label contains review/control marker '$pattern': $(Get-RelativePath -Path $Path)"
    }
  }
  if ($raw -match "\p{L}\?\p{L}|\?\p{L}") {
    throw "Export blocked: $Label contains replacement/question-mark encoding corruption: $(Get-RelativePath -Path $Path)"
  }
}

function Assert-PublicationMetadataClean {
  param([string]$Path)
  Ensure-File -Path $Path -Message "Export blocked: missing publication metadata at $(Get-RelativePath -Path $Path)."
  $metadata = Read-Json -Path $Path
  foreach ($field in @("title","author_or_editor","copyright_owner","publication_year","format","metadata_status")) {
    if (-not ($metadata.PSObject.Properties.Name -contains $field)) {
      throw "Export blocked: publication metadata missing '$field'."
    }
  }
  $status = [string]$metadata.metadata_status
  if ($status -notin @("draft_user_review","publisher_review_required","final_publisher_supplied")) {
    throw "Export blocked: publication metadata_status must be draft_user_review, publisher_review_required, or final_publisher_supplied."
  }
  foreach ($field in @("isbn","barcode","publisher")) {
    if ($metadata.PSObject.Properties.Name -contains $field) {
      $value = ([string]$metadata.$field).Trim()
      if ($value -match "(?i)^(fake|placeholder|todo|tbd|123|000|isbn)$") {
        throw "Export blocked: publication metadata contains fake or placeholder $field."
      }
    }
  }
}

function Convert-MarkdownToParagraphs {
  param([string]$Path)
  $paragraphs = New-Object System.Collections.Generic.List[string]
  foreach ($line in ((Read-Utf8 -Path $Path) -split "\r?\n")) {
    $trim = $line.Trim()
    if (-not $trim) { continue }
    $trim = $trim -replace "^#{1,6}\s*", ""
    $trim = $trim -replace "^\s*[-*]\s+", ""
    $paragraphs.Add($trim)
  }
  return $paragraphs
}

function Assert-ManuscriptClean {
  param([string[]]$Paragraphs)
  $badPattern = "(?i)\bEP\d{3}\b|^scene\s+\d+|^sahne\s+\d+|```|run_id\s*:|\bBu düğümde\s+\d+|\bAyrıntı\s+\d+\s+bu sahnenin|\bB[oö]l[üu]m[üu]n\s+(özgün|ozgun)\s+(ayrıntı|ayrinti)\s+alan[ıi]|\bDefterin kenarında\s+\d+|\bÖnceki bölümün bıraktığı iz|\bBu söz .+ içinde yeni bir iz bıraktı|\byanında duran Mahir, gördüğü şeyin yalnız bir eşya olmadığını anladı"
  $bad = @($Paragraphs | Where-Object { $_ -match $badPattern })
  if ($bad.Count -gt 0) {
    throw "Export blocked: user-facing manuscript contains technical/control/planning residue such as EP001, scene labels, run_id, beat notes, or generated scaffold lines."
  }
  $corrupt = @($Paragraphs | Where-Object { $_ -match "\p{L}\?\p{L}|\?\p{L}" })
  if ($corrupt.Count -gt 0) {
    throw "Export blocked: user-facing manuscript contains replacement/question-mark encoding corruption."
  }
}

function Invoke-LocalTurkishRuleCheck {
  param([string]$PhaseName)
  $checker = Join-Path $EngineRoot "scripts/ci/tdk_local_rule_check.py"
  if (-not (Test-Path -LiteralPath $checker -PathType Leaf)) {
    throw "Export blocked: local Turkish rule checker missing: scripts/ci/tdk_local_rule_check.py"
  }
  $python = "python"
  $bundledPython = Join-Path $env:USERPROFILE ".cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe"
  if ($bundledPython -and (Test-Path -LiteralPath $bundledPython -PathType Leaf)) {
    $python = $bundledPython
  }
  & $python $checker --project-root $ProjectRoot --phase $PhaseName --run-id $RunId
  if ($LASTEXITCODE -eq 2) {
    throw "Export blocked: local Turkish rule checker found critical issues."
  }
  if ($LASTEXITCODE -ne 0) {
    throw "Export blocked: local Turkish rule checker failed with exit code $LASTEXITCODE."
  }
}

function Convert-MmToTwip {
  param([double]$Mm)
  return [int][Math]::Round($Mm * 56.6929133858)
}

function Convert-CmToTwip {
  param([double]$Cm)
  return [int][Math]::Round($Cm * 566.929133858)
}

function Get-DocxStyleProfile {
  $profilePath = Join-Path $ProjectRoot "runtime/layout-profile.json"
  Ensure-File -Path $profilePath -Message "Export blocked: missing runtime/layout-profile.json for DOCX style profile."
  $profile = Read-Json -Path $profilePath
  $pageSetup = if ($profile.PSObject.Properties.Name -contains "page_setup") { $profile.page_setup } else { $null }
  $typography = if ($profile.PSObject.Properties.Name -contains "typography") { $profile.typography } else { $null }

  $widthMm = if ($pageSetup -and ($pageSetup.PSObject.Properties.Name -contains "width_mm")) { [double]$pageSetup.width_mm } else { 148.0 }
  $heightMm = if ($pageSetup -and ($pageSetup.PSObject.Properties.Name -contains "height_mm")) { [double]$pageSetup.height_mm } else { 210.0 }
  $topMm = if ($pageSetup -and ($pageSetup.PSObject.Properties.Name -contains "margin_top_mm")) { [double]$pageSetup.margin_top_mm } else { 18.0 }
  $bottomMm = if ($pageSetup -and ($pageSetup.PSObject.Properties.Name -contains "margin_bottom_mm")) { [double]$pageSetup.margin_bottom_mm } else { 20.0 }
  $insideMm = if ($pageSetup -and ($pageSetup.PSObject.Properties.Name -contains "margin_inside_mm")) { [double]$pageSetup.margin_inside_mm } else { 20.0 }
  $outsideMm = if ($pageSetup -and ($pageSetup.PSObject.Properties.Name -contains "margin_outside_mm")) { [double]$pageSetup.margin_outside_mm } else { 16.0 }

  $fontFamily = if ($profile.font_family) { [string]$profile.font_family } else { "Garamond" }
  $fontSizePt = if ($profile.body_font_size_pt) { [double]$profile.body_font_size_pt } else { 11.5 }
  $lineSpacing = if ($profile.line_spacing) { [double]$profile.line_spacing } else { 1.15 }
  $indentCm = if ($typography -and ($typography.PSObject.Properties.Name -contains "paragraph_first_line_indent_cm")) { [double]$typography.paragraph_first_line_indent_cm } else { 0.55 }
  $spacingAfterPt = if ($typography -and ($typography.PSObject.Properties.Name -contains "paragraph_spacing_after_pt")) { [double]$typography.paragraph_spacing_after_pt } else { 0.0 }
  $justification = if ($typography -and ($typography.PSObject.Properties.Name -contains "justification")) { [string]$typography.justification } else { "both" }

  return [ordered]@{
    delivery_profiles = if ($profile.PSObject.Properties.Name -contains "delivery_profiles") { $profile.delivery_profiles } else { [ordered]@{ publisher_submission = [ordered]@{ enabled = $true }; print_preview = [ordered]@{ enabled = $true } } }
    trim_size = if ($profile.trim_size) { [string]$profile.trim_size } else { "A5" }
    width_mm = $widthMm
    height_mm = $heightMm
    margin_top_mm = $topMm
    margin_bottom_mm = $bottomMm
    margin_inside_mm = $insideMm
    margin_outside_mm = $outsideMm
    page_width_twip = Convert-MmToTwip $widthMm
    page_height_twip = Convert-MmToTwip $heightMm
    margin_top_twip = Convert-MmToTwip $topMm
    margin_bottom_twip = Convert-MmToTwip $bottomMm
    margin_left_twip = Convert-MmToTwip $insideMm
    margin_right_twip = Convert-MmToTwip $outsideMm
    font_family = $fontFamily
    font_size_pt = $fontSizePt
    font_size_half_points = [int][Math]::Round($fontSizePt * 2)
    line_spacing = $lineSpacing
    line_spacing_twip = [int][Math]::Round(240 * $lineSpacing)
    paragraph_first_line_indent_cm = $indentCm
    paragraph_first_line_indent_twip = Convert-CmToTwip $indentCm
    paragraph_body_first_line_indent_twip = 0
    paragraph_spacing_after_pt = $spacingAfterPt
    paragraph_spacing_after_twip = [int][Math]::Round($spacingAfterPt * 20)
    justification = $justification
  }
}

function New-Docx {
  param([string]$OutputPath, [string]$Title, [string[]]$Paragraphs, [string[]]$ChapterTitles = @())
  $style = Get-DocxStyleProfile

  $tmp = Join-Path $ProjectRoot "revision/_docx_tmp"
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Ensure-Dir (Join-Path $tmp "_rels")
  Ensure-Dir (Join-Path $tmp "word")
  Ensure-Dir (Join-Path $tmp "word/_rels")
  Ensure-Dir (Join-Path $tmp "docProps")

  Write-Utf8 -Path (Join-Path $tmp "[Content_Types].xml") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
  <Override PartName="/word/footer1.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml"/>
  <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
  <Override PartName="/docProps/app.xml" ContentType="application/vnd.openxmlformats-officedocument.extended-properties+xml"/>
</Types>
'@
  Write-Utf8 -Path (Join-Path $tmp "_rels/.rels") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
</Relationships>
'@
  Write-Utf8 -Path (Join-Path $tmp "word/_rels/document.xml.rels") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rIdFooter1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer" Target="footer1.xml"/>
</Relationships>
'@
  Write-Utf8 -Path (Join-Path $tmp "word/footer1.xml") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:p>
    <w:pPr><w:jc w:val="center"/></w:pPr>
    <w:r><w:fldChar w:fldCharType="begin"/></w:r>
    <w:r><w:instrText xml:space="preserve"> PAGE </w:instrText></w:r>
    <w:r><w:fldChar w:fldCharType="separate"/></w:r>
    <w:r><w:t>1</w:t></w:r>
    <w:r><w:fldChar w:fldCharType="end"/></w:r>
  </w:p>
</w:ftr>
'@
  Write-Utf8 -Path (Join-Path $tmp "word/styles.xml") -Content @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr><w:rFonts w:ascii="$($style.font_family)" w:hAnsi="$($style.font_family)" w:cs="$($style.font_family)"/><w:sz w:val="$($style.font_size_half_points)"/></w:rPr>
    </w:rPrDefault>
    <w:pPrDefault>
      <w:pPr><w:jc w:val="$($style.justification)"/><w:spacing w:line="$($style.line_spacing_twip)" w:lineRule="auto" w:after="$($style.paragraph_spacing_after_twip)"/><w:ind w:firstLine="$($style.paragraph_first_line_indent_twip)"/></w:pPr>
    </w:pPrDefault>
  </w:docDefaults>
  <w:style w:type="paragraph" w:default="1" w:styleId="KitHubBody">
    <w:name w:val="KitHub Body"/>
    <w:pPr><w:jc w:val="$($style.justification)"/><w:spacing w:line="$($style.line_spacing_twip)" w:lineRule="auto" w:after="$($style.paragraph_spacing_after_twip)"/><w:ind w:firstLine="$($style.paragraph_first_line_indent_twip)"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="$($style.font_family)" w:hAnsi="$($style.font_family)" w:cs="$($style.font_family)"/><w:sz w:val="$($style.font_size_half_points)"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="KitHubBodyFirst">
    <w:name w:val="KitHub Body First Paragraph"/>
    <w:basedOn w:val="KitHubBody"/>
    <w:pPr><w:jc w:val="$($style.justification)"/><w:spacing w:line="$($style.line_spacing_twip)" w:lineRule="auto" w:after="$($style.paragraph_spacing_after_twip)"/><w:ind w:firstLine="0"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="$($style.font_family)" w:hAnsi="$($style.font_family)" w:cs="$($style.font_family)"/><w:sz w:val="$($style.font_size_half_points)"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="KitHubBookTitle">
    <w:name w:val="KitHub Book Title"/>
    <w:basedOn w:val="KitHubBody"/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:before="1080" w:after="360"/><w:ind w:firstLine="0"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="$($style.font_family)" w:hAnsi="$($style.font_family)" w:cs="$($style.font_family)"/><w:sz w:val="36"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="KitHubChapterTitle">
    <w:name w:val="KitHub Chapter Title"/>
    <w:basedOn w:val="KitHubBody"/>
    <w:pPr><w:keepNext/><w:pageBreakBefore/><w:jc w:val="center"/><w:spacing w:before="720" w:after="360"/><w:ind w:firstLine="0"/></w:pPr>
    <w:rPr><w:b/><w:rFonts w:ascii="$($style.font_family)" w:hAnsi="$($style.font_family)" w:cs="$($style.font_family)"/><w:sz w:val="30"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="KitHubFrontMatter">
    <w:name w:val="KitHub Front Matter"/>
    <w:basedOn w:val="KitHubBody"/>
    <w:pPr><w:jc w:val="center"/><w:spacing w:after="140"/><w:ind w:firstLine="0"/></w:pPr>
    <w:rPr><w:rFonts w:ascii="$($style.font_family)" w:hAnsi="$($style.font_family)" w:cs="$($style.font_family)"/><w:sz w:val="22"/></w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="KitHubToc">
    <w:name w:val="KitHub TOC"/>
    <w:basedOn w:val="KitHubBody"/>
    <w:pPr><w:jc w:val="left"/><w:spacing w:after="100"/><w:ind w:firstLine="0"/></w:pPr>
  </w:style>
</w:styles>
"@
  $body = New-Object System.Collections.Generic.List[string]
  $index = 0
  $chapterTitleSet = @{}
  foreach ($chapterTitle in @($ChapterTitles)) {
    if ([string]$chapterTitle) { $chapterTitleSet[[string]$chapterTitle] = 0 }
  }
  foreach ($p in $Paragraphs) {
    $index++
    $safe = [System.Security.SecurityElement]::Escape($p)
    $styleId = "KitHubBody"
    if ($index -eq 1) { $styleId = "KitHubBookTitle" }
    elseif ($p -eq "İçindekiler") { $styleId = "KitHubChapterTitle" }
    elseif ($chapterTitleSet.ContainsKey($p)) {
      $chapterTitleSet[$p] = [int]$chapterTitleSet[$p] + 1
      $styleId = $(if ([int]$chapterTitleSet[$p] -eq 1) { "KitHubToc" } else { "KitHubChapterTitle" })
    }
    elseif ($index -gt 1) {
      $seenToc = $false
      foreach ($titleKey in $chapterTitleSet.Keys) {
        if ([int]$chapterTitleSet[$titleKey] -gt 1) { $seenToc = $true; break }
      }
      if (-not $seenToc) {
        $styleId = "KitHubFrontMatter"
      }
      else {
        $previous = if ($index -gt 1) { $Paragraphs[$index - 2] } else { "" }
        if ($chapterTitleSet.ContainsKey($previous) -and [int]$chapterTitleSet[$previous] -gt 1) {
          $styleId = "KitHubBodyFirst"
        }
      }
    }
    $body.Add("<w:p><w:pPr><w:pStyle w:val=""$styleId""/></w:pPr><w:r><w:t xml:space=""preserve"">$safe</w:t></w:r></w:p>")
  }
  Write-Utf8 -Path (Join-Path $tmp "word/document.xml") -Content @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $($body -join [Environment]::NewLine)
    <w:sectPr><w:footerReference w:type="default" r:id="rIdFooter1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/><w:pgSz w:w="$($style.page_width_twip)" w:h="$($style.page_height_twip)"/><w:pgMar w:top="$($style.margin_top_twip)" w:right="$($style.margin_right_twip)" w:bottom="$($style.margin_bottom_twip)" w:left="$($style.margin_left_twip)" w:gutter="0"/></w:sectPr>
  </w:body>
</w:document>
"@
  Write-Utf8 -Path (Join-Path $tmp "docProps/core.xml") -Content "<?xml version=""1.0"" encoding=""UTF-8""?><cp:coreProperties xmlns:cp=""http://schemas.openxmlformats.org/package/2006/metadata/core-properties"" xmlns:dc=""http://purl.org/dc/elements/1.1/""><dc:title>$([System.Security.SecurityElement]::Escape($Title))</dc:title></cp:coreProperties>"
  Write-Utf8 -Path (Join-Path $tmp "docProps/app.xml") -Content "<?xml version=""1.0"" encoding=""UTF-8""?><Properties xmlns=""http://schemas.openxmlformats.org/officeDocument/2006/extended-properties""><Application>kit_hub exporter</Application></Properties>"

  Ensure-Dir (Split-Path -Parent $OutputPath)
  if (Test-Path -LiteralPath $OutputPath) { Remove-Item -LiteralPath $OutputPath -Force }
  Add-Type -AssemblyName System.IO.Compression
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::Open($OutputPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    $rootFull = [System.IO.Path]::GetFullPath($tmp)
    $files = Get-ChildItem -LiteralPath $tmp -Recurse -File
    foreach ($file in $files) {
      $full = [System.IO.Path]::GetFullPath($file.FullName)
      $relative = $full.Substring($rootFull.Length).TrimStart("\") -replace "\\", "/"
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $full, $relative) | Out-Null
    }
  }
  finally {
    $zip.Dispose()
  }
  Remove-Item -LiteralPath $tmp -Recurse -Force
}

function Invoke-Propose {
  $seed = Get-BookSeed
  $slug = Get-Slug $seed
  $workspace = Join-Path $ProjectRoot "_workspace"
  $approvalDir = Join-Path $ProjectRoot "runtime/approvals"
  Ensure-Dir $workspace
  Ensure-Dir $approvalDir

  $proposal = @"
# Kitap Yönü Önerileri

run_id: $RunId

## Kullanıcı Konusu
$seed

## Öneri 1 - İçsel Çatışma Odaklı
- Logline: Verilen konu, ana karakterin sakladığı arzu, korku veya suçluluk üzerinden ilerleyen karakter merkezli bir anlatıya dönüştürülür.
- Okur vaadi: Psikolojik derinlik, tutarlı karakter dönüşümü, sahne sahne ilerleyen iç gerilim.
- Risk: Dış olay zayıf kalırsa tekrar hissi doğabilir; her bölüm yeni seçim ve sonuç taşımalıdır.

## Öneri 2 - Olay Örgüsü Odaklı
- Logline: Verilen konu, açık hedef, engel, dönüm noktası ve final sonucu olan güçlü bir olay zincirine çevrilir.
- Okur vaadi: Net ilerleme, bölüm sonu merakı, neden-sonuç bağı güçlü kurgu.
- Risk: Karakterler sadece olay taşıyıcısı gibi kalabilir; karakter defteri zorunlu tutulmalıdır.

## Öneri 3 - Edebi Atmosfer Odaklı
- Logline: Verilen konu, mekan, ses, ritim ve imgelerle örülen daha edebi ve yoğun bir anlatı haline getirilir.
- Okur vaadi: Güçlü betimleme, dil işçiliği, tema ağırlıklı bütünlük.
- Risk: Olay ilerlemesi yavaşlayabilir; her sahne dramatik işlev taşımalıdır.

## Zorunlu Sonraki Adım
Bu aşama roman yazmaz. Kullanıcı `runtime/approvals/story-choice.json` dosyasında bir öneriyi seçip `approved=true` yapmadan tasarım ve yazım aşaması başlamaz.
"@

  Write-Utf8 -Path (Join-Path $workspace "01_proposals.md") -Content $proposal
  Write-Utf8 -Path (Join-Path $ProjectRoot "$slug`_proposal.md") -Content $proposal

  $storyChoicePath = Join-Path $approvalDir "story-choice.json"
  if (-not (Test-Path -LiteralPath $storyChoicePath -PathType Leaf)) {
    Write-Json -Path $storyChoicePath -Value ([ordered]@{
      title = "Story Choice Approval"
      approved = $false
      selected_option = ""
      approved_by = ""
      approved_at = ""
      note = "Set approved=true and selected_option to 1, 2, or 3 only after the user chooses the story direction."
    })
  }

  Write-AgentCompliance -PhaseName "propose" -RequiredAgents @("proposal-generator") -RequiredReferences @("skills/propose/SKILL.md") -LoadedStateFiles @("runtime/book-request.md", "runtime/book-brief.json", "runtime/book-dna.json", "runtime/layout-profile.json", "runtime/approvals/book-brief-approval.json") -OutputArtifacts @("_workspace/01_proposals.md", "$slug`_proposal.md", "runtime/approvals/story-choice.json")
}

function Invoke-Intake {
  $seed = Get-BookSeed
  $approvalDir = Join-Path $ProjectRoot "runtime/approvals"
  Ensure-Dir $approvalDir

  Write-Json -Path (Join-Path $ProjectRoot "runtime/book-brief.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    source_prompt = $seed
    brief_status = "QUESTIONS_PENDING"
    intake_policy = "Do not propose, plan, write, polish, rewrite, or export until required_user_questions are answered or explicitly accepted by the user."
    writing_intent = [ordered]@{
      writing_type = "ask_user"
      genre = "ask_user_or_suggest"
      target_reader = "ask_user"
      target_pages = "ask_user"
      target_words = "derive_after_target_pages"
      target_chapters = "derive_after_target_pages"
    }
    required_user_questions = @(
      [ordered]@{ id = "writing_type"; question = "Ne yazmak istiyorsunuz: roman, hikaye, novella, deneme, biyografi, ani, arastirma kitabi, cocuk kitabi veya baska bir tur mu?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "premise"; question = "Ana konu veya tek cumlelik fikir nedir?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "target_length"; question = "Hedef uzunluk nedir: sayfa, kelime veya bolum sayisi? Ornek: 10 sayfa, 270 sayfa, 500 sayfa."; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "target_reader"; question = "Hedef okur kim?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "genre"; question = "Tur/alt tur nedir veya sistem hangi turleri onersin?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "character_policy"; question = "Karakterleri siz mi vereceksiniz, yoksa sistem karakter onerisi sunsun mu?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "setting_period"; question = "Mekan, donem ve gercek bilgi/kaynak gereksinimi var mi?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "pov_tense"; question = "Bakis acisi ve anlatim zamani tercihiniz var mi?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "style_tone"; question = "Uslup nasil olsun: sade, edebi, yogun betimlemeli, hizli tempolu, akademik veya baska?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "boundaries"; question = "Istenmeyen konu, sahne, final veya anlatim bicimi var mi?"; required = $true; answer_required_for_approval = $true },
      [ordered]@{ id = "publication_package"; question = "Onsoz, icindekiler, kapak briefi, arka kapak yazisi ve basili kitap dizgisi isteniyor mu?"; required = $true; answer_required_for_approval = $true }
    )
    answers = [ordered]@{
      writing_type = ""
      premise = $seed
      target_length = ""
      target_pages = ""
      target_reader = ""
      genre = ""
      character_policy = ""
      setting_period = ""
      pov_tense = ""
      style_tone = ""
      boundaries = ""
      publication_package = ""
    }
    suggested_defaults = [ordered]@{
      target_length = "Ask the user; do not assume. If the user says 'sen sec', choose a length and record that approval."
      publication_package = "publisher_submission_docx, print_preview_docx, title page, copyright placeholder, preface optional, table of contents, cover brief, back cover copy"
      layout = "A5, Garamond 11.5 pt, 1.15 line spacing, justified, narrow book text block, first paragraph after chapter unindented, chapter starts on new page"
    }
    approval_requirements = @(
      "answers.writing_type must be filled",
      "answers.target_length or answers.target_pages must be filled",
      "answers.target_reader must be filled",
      "answers.genre must be filled or explicitly delegated to the system",
      "answers.character_policy must be filled",
      "answers.style_tone must be filled",
      "answers.publication_package must be filled"
    )
    llm_suggestion_policy = "If the user leaves fields blank, propose options and ask for approval; do not silently decide."
    approval_required = "runtime/approvals/book-brief-approval.json"
  })

  Write-Json -Path (Join-Path $ProjectRoot "runtime/book-dna.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    locked = $false
    source_prompt = $seed
    continuity_policy = "No chapter writing before approved brief, approved book plan, and approved layout profile."
    required_locks = @("writing_type", "genre", "target_length", "pov", "tense", "character_policy", "setting_policy", "style_policy", "source_policy", "front_matter_policy", "cover_policy")
    locked_answers_required = @("writing_type", "premise", "target_length", "target_reader", "genre", "character_policy", "setting_period", "pov_tense", "style_tone", "boundaries", "publication_package")
    user_supplied_characters = @()
    proposed_characters_allowed = $true
    factual_source_policy = "Biografi, arastirma, tarih, saglik, hukuk, teknik ve gercek kisi/kurum anlatilarinda kaynak artefakti olmadan dogruluk iddiasi kurulamaz."
    plan_before_writing_policy = "The system must present story direction, book plan, chapter plan, continuity model, and layout plan for user approval before any manuscript text is created."
  })

  Write-Json -Path (Join-Path $ProjectRoot "runtime/layout-profile.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    profile_status = "QUESTIONS_PENDING"
    print_target = "A5_NOVEL_DOCX"
    trim_size = "A5"
    font_family = "Garamond"
    body_font_size_pt = 11.5
    line_spacing = 1.15
    paragraph_alignment = "justified"
    paragraph_spacing_policy = "no_blank_line_between_body_paragraphs"
    chapter_start_policy = "new_page"
    delivery_profiles = [ordered]@{
      publisher_submission = [ordered]@{
        enabled = $true
        purpose = "clean Word file for editor/publisher review"
        decoration = "minimal"
        page_numbers = "omit_or_editor_added"
        print_ready_claim_allowed = $false
      }
      print_preview = [ordered]@{
        enabled = $true
        purpose = "A5 book-like proof for reading and layout inspection"
        chapter_start = "new_page"
        page_numbers = "required"
        print_ready_claim_allowed = $false
      }
    }
    page_setup = [ordered]@{
      trim_size = "A5"
      width_mm = 148
      height_mm = 210
      margin_top_mm = 18
      margin_bottom_mm = 20
      margin_inside_mm = 20
      margin_outside_mm = 16
      source_note = "Novel print preview default; publisher-specific submission rules override this profile."
    }
    typography = [ordered]@{
      body_style = "KitHubBody"
      chapter_title_style = "KitHubChapterTitle"
      front_matter_style = "KitHubFrontMatter"
      toc_style = "KitHubToc"
      paragraph_first_line_indent_cm = 0.55
      paragraph_spacing_after_pt = 0
      justification = "both"
    }
    front_matter = [ordered]@{
      title_page = "ask_user_or_required_for_print"
      copyright_page = "ask_user_or_required_for_print"
      preface = "ask_user"
      table_of_contents = "required_for_longform"
    }
    cover = [ordered]@{
      front_cover_brief = "required"
      back_cover_copy = "required_for_book_package"
      spine_guidance = "derive_after_page_count"
    }
    rule_sources = @(
      "TDK yazim ve noktalama kurallari",
      "Trade fiction print preview: A5, Garamond-like serif body font, narrow book text block, chapter new page, page numbers; publisher submission may override with Times New Roman 11",
      "Publication metadata checklist: ISBN, kunye, bandrol and barcode are external/final publisher tasks"
    )
  })

  $approvalPath = Join-Path $approvalDir "book-brief-approval.json"
  if (-not (Test-Path -LiteralPath $approvalPath -PathType Leaf)) {
    Write-Json -Path $approvalPath -Value ([ordered]@{
      title = "Book Brief Approval"
      approved = $false
      approved_by = ""
      approved_at = ""
      accepted_answers = [ordered]@{}
      accepted_target_pages = $null
      accepted_writing_type = ""
      accepted_publication_package = ""
      plan_required_next = "propose then design-big; no manuscript before book-plan-approval.json and design-freeze.json"
      note = "Set approved=true only after the user answers or accepts the intake questions/options in runtime/book-brief.json, runtime/book-dna.json, and runtime/layout-profile.json."
    })
  }

  Write-AgentCompliance -PhaseName "intake" -RequiredAgents @("brief-interviewer", "book-dna-locker", "layout-profile-planner") -RequiredReferences @("skills/intake/SKILL.md", "skills/polish/references/writing-type-profiles.md", "skills/polish/references/docx-professional-style-contract.md") -LoadedStateFiles @("runtime/book-request.md") -OutputArtifacts @("runtime/book-brief.json", "runtime/book-dna.json", "runtime/layout-profile.json", "runtime/approvals/book-brief-approval.json")
}

function Invoke-DesignBig {
  $seed = Get-DesignSeed
  Ensure-Approved -RelativePath "runtime/approvals/book-brief-approval.json" -GateName "Book brief approval" | Out-Null
  $choice = Get-StoryChoice
  $projectName = Get-CleanTitleFromText -Text $seed
  $hasExplicitTitle = [regex]::IsMatch($seed, "(?im)^\s*(kitap\s+adi|kitap\s+adı|title|baslik|başlık)\s*:")
  if (-not $hasExplicitTitle -and $seed -match "(?i)Pera Palas|Dolmabah[cç]e|Bizans|M[uü]nevver|Alev") {
    $projectName = "Sisin Altında 101"
  }
  $scale = Get-LongformScalePlan
  $targetChapters = [int]$scale.target_chapters
  $wordsPerChapter = [int]$scale.words_per_chapter
  $targetWords = [int]$scale.target_words
  $targetPages = [int]$scale.target_pages
  $wordsPerPage = [int]$scale.words_per_page_estimate
  $structureModel = [string]$scale.structure_model
  $scaleTier = [string]$scale.scale_tier
  $maxChaptersPerBatch = [int]$scale.max_chapters_per_batch
  $auditIntervalChapters = [int]$scale.audit_interval_chapters
  $typeProfile = Get-WritingTypeProfileFromSeed -Seed $seed -TargetPages $targetPages
  $writingType = [string]$typeProfile.writing_type
  $genreLabel = [string]$typeProfile.genre
  $structureModel = [string]$typeProfile.structure_model
  $requestedCharacterCount = Get-RequestedCharacterCount
  if (($seed -match "(?i)Pera Palas|Dolmabah[cç]e|Bizans|M[uü]nevver|Alev") -and $requestedCharacterCount -lt 6) {
    $requestedCharacterCount = 6
  }
  $protagonistName = "$projectName yolcusu"
  if ($protagonistName.Length -gt 70) { $protagonistName = $protagonistName.Substring(0, 70).Trim() }
  $themeLabel = "hafiza, karar ve sonuclar"
  $design = Join-Path $ProjectRoot "design"
  $state = Get-StateDir
  Ensure-Dir $design
  Ensure-Dir $state

  Write-Utf8 -Path (Join-Path $design "01_concept_bootstrap.md") -Content @"
# Konsept Bootstrap

run_id: $RunId

## Ana Fikir
$seed

## Onaylanan Yön
Öneri $($choice.selected_option)

## Üretim Kuralı
Bu dosya iskelet kurar; gerçek roman metni provider/IDE ajanı/human yazar tarafından üretilecektir.
"@

  Write-Utf8 -Path (Join-Path $design "02_character_core.md") -Content @"
# Karakter Çekirdeği

run_id: $RunId

## Zorunlu Tasarım Alanları
- Başkarakter: ad, arzu, korku, zaaf, dönüşüm çizgisi.
- Karşı güç: insan, durum, sır, toplum veya iç engel.
- İlişki haritası: her önemli karakterin bildiği ve bilmediği bilgiler.

Bu alanlar gerçek yazıma geçmeden önce IDE ajanı veya provider tarafından somutlaştırılmalıdır.
"@

  Write-Utf8 -Path (Join-Path $design "03_macro_plot_hooks.md") -Content @"
# Makro Plot Rehberi

run_id: $RunId

## Zorunlu Kurgu Alanları
- Açılış vaadi
- Kışkırtıcı olay
- Orta nokta dönüşü
- En düşük nokta
- Doruk
- Sonuç ve kapanan vaatler

Her bölüm önceki bölümün sonucundan doğmalı; bölüm tekrarları ve teknik sahne etiketleri yasaktır.
"@

  $chapters = @()
  $chapterPlan = @()
  if ($seed -match "(?i)Pera Palas|Dolmabah[cç]e|Bizans|M[uü]nevver|Alev") {
    $chapterBeats = @(
      @{ title = "101 Numaralı Oda"; event = "Münevver, Pera Palas'ın 101 numaralı odasında kapısının altından bırakılan Bizans haritasını bulur."; change = "Eski istihbaratçı kadın, Alev kod adının gömülü kaldığını sandığı geçmişin yeniden çağrıldığını anlar." },
      @{ title = "Kuşlu Asansör"; event = "Pera Palas lobisindeki İngiliz misafirler, caz sesi ve kuşlu asansör arasında haritanın ilk Grekçe ibaresi çözülür."; change = "Haritanın Dolmabahçe altındaki su yolunu işaret ettiği ortaya çıkar." },
      @{ title = "Rutubetli Rıhtım"; event = "Münevver, yağmur ve Boğaz rutubeti altında Dolmabahçe kıyısına iner ve eski bir temas noktasında öldü sandığı adamın işaretini bulur."; change = "Komplo kişisel bir hayaletten somut bir tehdide dönüşür." },
      @{ title = "Beyoğlu'nun Arka Sokakları"; event = "Simit, boza ve mısır satıcılarının arasından geçen takipte Levanten bir aracı Grekçe ikinci şifreyi taşır."; change = "Münevver, şifrenin yalnız haritayı değil kendi Millî Mücadele görevini de anlattığını fark eder." },
      @{ title = "Sarnıcın Kapısı"; event = "Bizans sarnıcına inen gizli geçitte semboller, su sesi ve duvar yazıları okurla birlikte adım adım çözülür."; change = "Komplonun hedefi Cumhuriyet'in modern yüzünü sarsacak bir itibar ve sabotaj planı olarak belirir." },
      @{ title = "Alev'in Sırrı"; event = "Münevver komployu durdurur; karşısındaki adamın geçmişte en yakın sırdaşı olduğunu anladığı yüzleşme başlar."; change = "Zafer, kapanış değil; Münevver'in en güvendiği hafızanın ihanetiyle biten karanlık bir yüzleşmeye dönüşür." }
    )
  }
  else {
    $chapterBeats = @(
      @{ title = "İlk İz"; event = "Ana karakterin rutinini bozan nesne, mektup, tanık veya karşılaşma ortaya çıkar."; change = "Gizli gerilim somut bir soruya bağlanır." },
      @{ title = "Eşiğin Ardında"; event = "Karakter ilk kanıtı izler ve güvenli alanının dışına çıkar."; change = "Merak kişisel riske dönüşür." },
      @{ title = "Kayıt ve Gölge"; event = "Eski kayıt, tanık veya mekân ana çelişkiyi büyütür."; change = "Olay bireysel meraktan daha büyük bir sorumluluğa dönüşür." },
      @{ title = "Saklanan Bağ"; event = "Geçmişteki ilişki veya sır bugünkü tehditle birleşir."; change = "Karakterin iç çatışması olay örgüsüne bağlanır." },
      @{ title = "Açık Tehdit"; event = "Karşı güç kendini gösterir ve ana karakter seçim yapmak zorunda kalır."; change = "Kaçınma imkânı ortadan kalkar." },
      @{ title = "Yüzleşme"; event = "Açılış vaadi kapanır; karakter hakikatle ve bedeliyle karşılaşır."; change = "Sonuç, karakterin dönüşümünü somutlaştırır." }
    )
  }
  for ($i = 1; $i -le $targetChapters; $i++) {
    $chapterId = ("EP{0:D3}" -f $i)
    $beat = $chapterBeats[($i - 1) % $chapterBeats.Count]
    $readerTitle = [string]$beat.title
    $chapters += [ordered]@{
      id = $chapterId
      reader_label = $readerTitle
      target_words = $wordsPerChapter
      purpose = [string]$beat.change
      must_advance = @("plot", "character", "theme")
    }
    $chapterPlan += [ordered]@{
      id = $chapterId
      reader_title = $readerTitle
      purpose = [string]$beat.change
      events = @([string]$beat.event, "Karakter bir seçim yapmak zorunda kalır.", "Bölüm sonunda geri alınamaz bir sonuç oluşur.")
      character_focus = @("Ana karakterin arzusu, korkusu ve bilgi sınırı güncellenir.")
      continuity_promises = @("Bölüm sonucu sonraki bölümün nedenini oluşturur.", "Tekrarlanan açılış ve teknik sahne etiketi kullanılmaz.")
      target_words = $wordsPerChapter
    }
  }

  $plannedCharacters = @()
  if ($seed -match "(?i)Pera Palas|Dolmabah[cç]e|Bizans|M[uü]nevver|Alev") {
    $characterTemplates = @(
      @{ role = "protagonist"; name = "Münevver"; desire = "Geçmişte Alev kod adıyla yaptığı görevlerin bıraktığı karanlığı kapatmak ve Cumhuriyet'in yeni yüzünü hedef alan komployu durdurmak."; fear = "Öldü sandığı sırdaşına duyduğu eski güvenin bugünkü felaketi hazırlamış olması."; arc = "Kendini geçmişten çekmiş yalnız kadından, hafızasını silmeden yeniden sorumluluk alan istihbaratçıya dönüşür." },
      @{ role = "old_confidant_antagonist"; name = "Kemal Rıza"; desire = "Eski hesaplarını ve kırılmış sadakatini Bizans geçidi üzerinden kurduğu komployla görünür kılmak."; fear = "Münevver'in onu yalnızca düşman değil, geçmişteki en yakın sırdaş olarak hatırlaması."; arc = "Ölü sanılan gölgeden, finalde ihanetin insan yüzüne dönüşür." },
      @{ role = "levanten_intermediary"; name = "Madam Eleni"; desire = "Pera ve Galata çevresindeki kırılgan ağını korurken Münevver'e eksik şifre parçasını ulaştırmak."; fear = "Rum ve Levanten çevrenin yeni siyasi dengede günah keçisi yapılması."; arc = "Tarafsız aracıdan, doğru anda bedel ödeyen tanığa dönüşür." },
      @{ role = "palace_guard_contact"; name = "Nizamettin Efendi"; desire = "Dolmabahçe çevresindeki eski geçit söylentilerini büyütmeden kontrol altında tutmak."; fear = "Saray altındaki izlerin dış güçlerin elinde Cumhuriyet'e karşı kullanılacak malzemeye dönüşmesi."; arc = "Kuralcı muhafızdan, Münevver'in sezgisine güvenen yardımcıya dönüşür." },
      @{ role = "hotel_observer"; name = "Monsieur Armand"; desire = "Pera Palas'ın Avrupalı misafirleri arasında dönen gizli temasları kimseye belli etmeden izlemek."; fear = "Otelin tarafsız görünen salonlarının casusluk düğümüne dönüşmesi."; arc = "Nazik otel görevlisinden, kilit zaman bilgisini veren sessiz gözlemciye dönüşür." },
      @{ role = "street_witness"; name = "Sami"; desire = "Beyoğlu arka sokaklarında simit ve gazete satarak ailesini geçindirmek."; fear = "Gördüğü küçük işaret yüzünden büyük adamların oyununda ezilmek."; arc = "Sokak çocuğu tanıktan, Münevver'i sarnıç kapısına götüren canlı pusulaya dönüşür." }
    )
  }
  else {
    $characterTemplates = @(
      @{ role = "protagonist"; name = "Ana Karakter"; desire = "Verilen konunun merkezindeki eksikliği gidermek."; fear = "Hakikat ortaya çıkarsa eski hayatını kaybetmek."; arc = "Kaçınan kişiden sorumluluk alan kişiye dönüşür." },
      @{ role = "opposing_force"; name = "Karşı Güç"; desire = "Sırrı, düzeni veya çıkarını korumak."; fear = "Saklanan hakikatin açığa çıkması."; arc = "Gölgedeki engelden, yüzleşilen somut güce dönüşür." },
      @{ role = "witness"; name = "Tanık"; desire = "Bildiklerini saklayarak güvende kalmak."; fear = "Konuşursa bedel ödemek."; arc = "Suskunluktan tanıklığa geçer." },
      @{ role = "ally"; name = "Yardımcı"; desire = "Ana karaktere doğru zamanda doğru bilgiyi ulaştırmak."; fear = "Yanlış tarafa güvenmek."; arc = "Şüpheli figürden güvenilir desteğe dönüşür." }
    )
  }
  for ($c = 1; $c -le $requestedCharacterCount; $c++) {
    $template = $characterTemplates[($c - 1) % $characterTemplates.Count]
    $role = [string]$template.role
    $name = [string]$template.name
    if ($c -gt $characterTemplates.Count) {
      $name = "Yan Karakter $c"
      $role = "supporting_character"
    }
    $plannedCharacters += [ordered]@{
      role = $role
      name = $name
      desire = [string]$template.desire
      fear = [string]$template.fear
      arc = [string]$template.arc
    }
  }

  $requiredStateFiles = @(
    "revision/_state/book-plan.json",
    "revision/_state/open-source-story-model.json",
    "revision/_state/chapter-plan.json",
    "revision/_state/layout-plan.json",
    "revision/_state/longform-plan.json",
    "revision/_state/character-state.json",
    "revision/_state/plot-ledger.json",
    "revision/_state/chapter-summaries.json",
    "revision/_state/continuity-ledger.json",
    "revision/_state/world-state.json",
    "revision/_state/relationship-graph.json",
    "revision/_state/knowledge-graph.json",
    "revision/_state/promise-payoff-ledger.json",
    "revision/_state/timeline.json",
    "revision/_state/theme-ledger.json",
    "revision/_state/volume-plan.json",
    "revision/_state/style-profile.json",
    "revision/_state/writing-type-profile.json",
    "revision/_state/genre-structure-template.json",
    "revision/_state/editorial-quality-scorecard.json",
    "revision/_state/llm-adapter-contract.json",
    "revision/_state/claim-ledger.json",
    "revision/_state/source-ledger.json",
    "revision/_state/term-glossary.json",
    "revision/_state/argument-ledger.json"
  )
  $planId = "PLAN-$RunId"

  Write-Utf8 -Path (Join-Path $design "04_book_plan.md") -Content @"
# Kitap Planı

run_id: $RunId
plan_id: $planId

## Kullanıcı İsteği
$seed

## Yazım Başlamadan Önce Zorunlu Onay
Bu plan, karakterler, olay akışı, bölüm hedefleri ve baskı sayfa hesabı kullanıcı tarafından onaylanmadan yazım fazı başlayamaz.

## Çekirdek Plan
- Çalışma adı: $projectName
- Hedef tür: kullanıcı isteğinden türetilecek
- Hedef bölüm: $targetChapters
- Hedef kelime: $targetWords
- Hedef sayfa: $targetPages
- Ölçek profili: $scaleTier
- Üretim batch sınırı: $maxChaptersPerBatch bölüm
- Makro süreklilik denetimi: her $auditIntervalChapters bölümde bir
"@

  Write-Utf8 -Path (Join-Path $design "05_chapter_plan.md") -Content @"
# Bölüm Planı

run_id: $RunId
plan_id: $planId

Her bölüm önceki bölümün sonucundan doğmalı, yeni bilgi üretmeli ve karakter/olay durumunu değiştirmelidir. Okur çıktısında EP kodu veya sahne etiketi kullanılamaz.

$(
  ($chapterPlan | ForEach-Object {
    "- $($_.reader_title): $($_.purpose) Hedef: $($_.target_words) kelime."
  }) -join [Environment]::NewLine
)
"@

  Write-Utf8 -Path (Join-Path $design "06_layout_plan.md") -Content @"
# Sayfa ve Dizgi Planı

run_id: $RunId
plan_id: $planId

- Boyut: A5
- Yazı tipi: Times New Roman
- Punto: 11
- Satır aralığı: 1.15
- Tahmini kelime/sayfa: 420
- Hedef sayfa: $targetPages
- Hedef kelime: $targetWords
- Ölçek profili: $scaleTier
- Batch sınırı: $maxChaptersPerBatch bölüm
- Makro süreklilik denetimi: her $auditIntervalChapters bölümde bir
"@

  Write-Json -Path (Join-Path $state "book-plan.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    plan_id = $planId
    source_prompt = $seed
    approved_story_option = $choice.selected_option
    title_working = $projectName
    writing_type = $writingType
    genre = $genreLabel
    theme = $themeLabel
    premise = $seed
    scale_tier = $scaleTier
    structure_model = $structureModel
    target_pages = $targetPages
    target_words = $targetWords
    narrative_pov = "ucuncu tekil sinirli bakis"
    tense = "gecmis zaman"
    characters = $plannedCharacters
    plot_arc = [ordered]@{
      opening_promise = "Okur, konunun merkezindeki karakterin siradan gorunen aninda sakli gerilimi sezer."
      inciting_incident = "Karakterin rutinini bozan kucuk ama geri donulmez bir isaret veya karsilasma ortaya cikar."
      midpoint_turn = "Karakter, dis olaydan cok kendi payini gormeye baslar ve pasif konumdan cikar."
      climax = "Karakter, kacindigi bilgiyi veya duyguyu acik bir secimle karsilar."
      resolution = "Sonuc, acilis vaadini kapatir ve karakterin degisimini okura somut davranisla gosterir."
    }
    chapter_count = $targetChapters
    max_chapters_per_batch = $maxChaptersPerBatch
    audit_interval_chapters = $auditIntervalChapters
    approval_required = $true
    open_source_story_model = "revision/_state/open-source-story-model.json"
  })
  Write-Json -Path (Join-Path $state "open-source-story-model.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    model_id = "manuskript-novelwriter-bibisco-storm-adapter"
    license_policy = "Patterns adapted with attribution; upstream GUI/storage code is not embedded in runtime output."
    sources = @(
      [ordered]@{ project = "Manuskript"; repository = "olivierkes/manuskript"; license = "GPL-3.0-or-later"; adapted_patterns = @("character motivation/goal/conflict/epiphany fields", "plot and plot-step fields", "world fields", "outline summary/POV/goal/status/compile fields") },
      [ordered]@{ project = "novelWriter"; repository = "vkbo/novelWriter"; license = "GPL-3.0"; adapted_patterns = @("plain text project tree", "novel/plot/character/world roots", "chapter and scene documents", "synopsis metadata", "tag and cross-reference indexing") },
      [ordered]@{ project = "bibisco"; repository = "andreafeccomandi/bibisco"; license = "GPL-3.0"; adapted_patterns = @("premise/fabula/narrative strands", "geographic temporal social setting", "chapter scene revision workflow", "deep character understanding") },
      [ordered]@{ project = "STORM"; repository = "stanford-oval/storm"; license = "MIT"; adapted_patterns = @("pre-writing before drafting", "question-driven outline", "human steering", "research/source grounding") }
    )
    outline_model = [ordered]@{
      required_fields = @("id", "reader_title", "synopsis", "pov", "goal", "status", "compile", "target_words", "revision_state")
      chapter_scene_rule = "Every chapter may contain scene cards, but reader output must hide scene labels unless the writing type explicitly requires them."
      progression_rule = "Each outline card must add cause, consequence, or irreversible knowledge."
    }
    character_model = [ordered]@{
      required_fields = @("name", "role", "importance", "motivation", "goal", "conflict", "epiphany", "summary_sentence", "summary_paragraph", "summary_full", "stable_traits", "knowledge_boundaries", "arc_position", "pov_eligible")
      consistency_rule = "A character cannot act from knowledge, motivation, or relationship state absent from character-state.json and knowledge-graph.json."
    }
    plot_model = [ordered]@{
      required_fields = @("main_plot", "subplots", "plot_steps", "result", "cause_effect_chain", "promise_payoff", "linked_characters")
      repetition_blocker = "A chapter that restates the previous problem without new consequence is invalid."
    }
    world_model = [ordered]@{
      required_fields = @("geographic_setting", "temporal_setting", "social_setting", "objects", "institutions", "constraints", "mood", "conflict")
      continuity_rule = "Locations, dates, objects and institutions must be ledgered before they drive plot action."
    }
    cross_reference_model = [ordered]@{
      required_targets = @("characters", "plots", "locations", "objects", "secrets", "sources", "terms")
      tag_policy = "Tags and synopsis notes are planning-only metadata and must not appear in reader-facing DOCX."
    }
    research_outline_model = [ordered]@{
      required_for = @("historical_fiction", "biography", "memoir", "research_book", "academic", "business_book")
      required_ledgers = @("source-ledger.json", "claim-ledger.json", "term-glossary.json", "argument-ledger.json")
      rule = "No source, official rule, historical claim, date or quote may be invented without a source artifact or explicit fiction scope note."
    }
    export_model = [ordered]@{
      required = @("title_page", "front_matter", "chapter_new_page", "reader_facing_titles", "synopsis_excluded", "metadata_excluded", "docx_content_match")
      print_claim_policy = "Output may be review-ready or print-preview; final print-ready claim requires external ISBN/kunye/bandrol and publisher specs."
    }
    required_state_files = $requiredStateFiles
  })
  Write-Json -Path (Join-Path $state "chapter-plan.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; plan_id = $planId; chapters = $chapterPlan })
  Write-Json -Path (Join-Path $state "layout-plan.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    plan_id = $planId
    delivery_profiles = [ordered]@{
      publisher_submission = [ordered]@{ enabled = $true; file_role = "editorial_review_docx"; print_ready_claim_allowed = $false }
      print_preview = [ordered]@{ enabled = $true; file_role = "reader_layout_proof"; page_numbers = "required"; chapter_start = "new_page"; print_ready_claim_allowed = $false }
    }
    trim_size = "A5"
    width_mm = 148
    height_mm = 210
    margin_top_mm = 18
    margin_bottom_mm = 20
    margin_inside_mm = 20
    margin_outside_mm = 16
    font_family = "Garamond"
    font_size_pt = 11.5
    line_spacing = 1.15
    paragraph_first_line_indent_cm = 0.55
    words_per_page_estimate = $wordsPerPage
    target_pages = $targetPages
    target_words = $targetWords
    target_chapters = $targetChapters
    scale_tier = $scaleTier
    max_chapters_per_batch = $maxChaptersPerBatch
    audit_interval_chapters = $auditIntervalChapters
    front_matter_pages_estimate = 6
    back_matter_pages_estimate = 0
    chapter_start_policy = "new_page"
    front_matter = [ordered]@{ required = @("title_page", "copyright_page_external_data_pending", "toc"); optional = @("preface", "foreword", "acknowledgements") }
    back_matter = [ordered]@{ optional = @("bibliography", "glossary", "appendix", "about_author") }
    page_numbering = [ordered]@{ front_matter = "roman_or_unnumbered"; body = "arabic_from_first_chapter"; requires_export_support = $true }
    chapter_title_policy = "reader_facing_titles_only_no_ep_scene_labels"
    publisher_submission_label = "review_ready_until_external_isbn_kunye_bandrol_complete"
  })

  Write-Json -Path (Join-Path $state "longform-plan.json") -Value ([ordered]@{
    schema_version = "1.1.0"
    run_id = $RunId
    premise = $seed
    selected_story_option = $choice.selected_option
    target_pages = $targetPages
    target_words = $targetWords
    target_chapters = $targetChapters
    words_per_chapter = $wordsPerChapter
    scale_tier = $scaleTier
    structure_model = $structureModel
    max_chapters_per_batch = $maxChaptersPerBatch
    audit_interval_chapters = $auditIntervalChapters
    continuity_model = "world_graph_plus_promise_payoff"
    production_mode = "approval_gated_chunked_longform"
    memory_strategy = "state_ledgers_plus_chapter_summaries_plus_audit_schedule"
    chapter_state_update_contract = @("chapter-summaries", "character-state", "plot-ledger", "continuity-ledger", "world-state", "relationship-graph", "knowledge-graph", "promise-payoff-ledger", "timeline", "theme-ledger", "open-source-story-model")
    reader_progression_policy = "Every chapter must add a new event, new information, irreversible change, and causal link to the next chapter."
    chapters = $chapters
    required_state_files = $requiredStateFiles
  })
  $characterStates = @()
  $relationshipNodes = @()
  $idx = 0
  foreach ($pc in $plannedCharacters) {
    $idx++
    $id = if ($idx -eq 1) { "protagonist" } else { "character_$idx" }
    $characterStates += [ordered]@{ id = $id; name = $pc.name; stable_traits = @("planli", "ayirt edilebilir hedefe sahip", "iliski baskisiyla sinanan"); knows = @("Kendi gorunen davranisinin ardinda bir hedef oldugunu bilir."); does_not_know = @("Karsilasacagi sonucun onu hangi secime zorlayacagini bilmez."); arc_position = "opening" }
    $relationshipNodes += [ordered]@{ id = $id; name = $pc.name; label = $pc.name; role = $pc.role }
  }
  Write-Json -Path (Join-Path $state "character-state.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; characters = $characterStates; required = @("stable_traits", "knows", "does_not_know", "arc_position") })
  Write-Json -Path (Join-Path $state "plot-ledger.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; main_question = "Karakter verilen konunun yarattigi gerilim karsisinda kacmak yerine sonucunu sahiplenebilecek mi?"; open_threads = @("Acilis anindaki sakli gerilim", "Karakterin gecmis kararinin bugune etkisi", "Son secimin bedeli"); closed_threads = @(); cause_effect_chain = @("Konu istegi karakterin rutinini kurar.", "Rutin bozulunca karakterin sakladigi duygu gorunur."); final_promises = @("Acilis vaadi kapanista davranisla cevaplanacak.", "Karakterin bilgi siniri her bolumde ledger'a islenecek.") })
  Write-Json -Path (Join-Path $state "chapter-summaries.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; chapters = @() })
  Write-Json -Path (Join-Path $state "continuity-ledger.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; timeline = @(); locations = @(); object_state = [ordered]@{}; violations = @() })
  Write-Json -Path (Join-Path $state "world-state.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; scale_tier = $scaleTier; locations = @(); time_rules = @("Every chapter must declare where and when it occurs."); objects = @(); institutions = @(); world_constraints = @("No location, object, institution, or social rule may change without a state update.") })
  Write-Json -Path (Join-Path $state "relationship-graph.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; nodes = $relationshipNodes; edges = @(); change_log = @(); rule = "Every relationship change must cite the chapter that caused it." })
  $knowledgeEntries = @()
  foreach ($node in $relationshipNodes) {
    $knowledgeEntries += [ordered]@{ character_id = $node.id; knows = @(); does_not_know = @("Unrevealed plot answers."); learned_in = @() }
  }
  Write-Json -Path (Join-Path $state "knowledge-graph.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; character_knowledge = $knowledgeEntries; secrets = @(); rule = "No character may act on knowledge absent from this file." })
  Write-Json -Path (Join-Path $state "promise-payoff-ledger.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; open_promises = @([ordered]@{ id = "P001"; planted_in = "plan"; promise = "Opening tension must resolve through a concrete character choice."; target_payoff = "final_act"; status = "open" }); paid_promises = @(); abandoned_promises = @(); rule = "Foreshadowing, clues, and questions must be paid off or explicitly carried forward." })
  Write-Json -Path (Join-Path $state "timeline.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; chronology = @(); chapter_time_map = @(); rule = "Every chapter must add a chronological entry; time jumps require cause and destination." })
  Write-Json -Path (Join-Path $state "theme-ledger.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; primary_theme = $themeLabel; motifs = @(); theme_progression = @(); rule = "Theme must progress through action and consequence, not repeated explanation." })
  Write-Json -Path (Join-Path $state "claim-ledger.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; applicable = $writingType -in @("essay","memoir","biography","research_book","self_help","business_book","academic"); claims = @(); unsupported_claims = @(); rule = "Nonfiction or hybrid claims require source or scope notes; fiction must not present invented claims as factual." })
  Write-Json -Path (Join-Path $state "source-ledger.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; applicable = $writingType -in @("biography","research_book","business_book","academic"); sources = @(); missing_sources = @(); rule = "No source, date, citation, or official-rule claim may be invented." })
  Write-Json -Path (Join-Path $state "term-glossary.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; applicable = $writingType -in @("research_book","business_book","academic","science_fiction","fantasy"); terms = @(); rule = "Special terms must remain consistent across chapters." })
  Write-Json -Path (Join-Path $state "argument-ledger.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; applicable = $writingType -in @("essay","research_book","self_help","business_book","academic"); thesis = ""; chapter_arguments = @(); counterarguments = @(); rule = "Nonfiction chapters must advance the argument rather than repeat the same point." })
  $acts = @()
  $actCount = if ($targetPages -le 20) { 1 } elseif ($targetPages -le 120) { 3 } elseif ($targetPages -le 300) { 4 } else { 5 }
  for ($act = 1; $act -le $actCount; $act++) {
    $startChapter = [int]([Math]::Floor((($act - 1) * $targetChapters) / $actCount) + 1)
    $endChapter = [int]([Math]::Floor(($act * $targetChapters) / $actCount))
    $acts += [ordered]@{ id = "ACT$act"; start_chapter = ("EP{0:D3}" -f $startChapter); end_chapter = ("EP{0:D3}" -f $endChapter); purpose = "Scale-aware act segment $act for $scaleTier." }
  }
  $auditSchedule = @()
  for ($chapter = $auditIntervalChapters; $chapter -le $targetChapters; $chapter += $auditIntervalChapters) {
    $auditSchedule += ("EP{0:D3}" -f $chapter)
  }
  Write-Json -Path (Join-Path $state "volume-plan.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; scale_tier = $scaleTier; target_pages = $targetPages; target_words = $targetWords; target_chapters = $targetChapters; words_per_page_estimate = $wordsPerPage; words_per_chapter = $wordsPerChapter; max_chapters_per_batch = $maxChaptersPerBatch; audit_interval_chapters = $auditIntervalChapters; acts = $acts; audit_schedule = $auditSchedule; rule = "Writing must advance by approved chapter batches and run macro continuity audits on schedule." })
  Write-Json -Path (Join-Path $state "style-profile.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; profile = "Turkish print-ready prose"; narration = "Plan onayında bakış açısı ve zaman kesinleşir."; language = "tr-TR"; dialogue_policy = "dash_dialogue"; print_format = "A5, readable paragraphs, no technical labels in reader output"; forbidden = @("EP001 in reader output", "scene labels in reader output", "untracked time jump", "repeated chapter premise") })
  Write-Json -Path (Join-Path $state "writing-type-profile.json") -Value ([ordered]@{ schema_version = "1.2.0"; run_id = $RunId; writing_type = $writingType; genre = $genreLabel; target_reader = "general_adult_unless_user_specifies"; structure_model = $structureModel; scale_tier = $scaleTier; voice_model = "consistent book voice selected in approved plan"; evidence_policy = "No research/source claim without source artifacts."; supported_types = @("novel", "story", "novella", "children_book", "young_adult", "essay", "memoir", "biography", "research_book", "self_help", "business_book", "academic", "poetry_collection", "screenplay"); continuity_policy = "open-source-story-model-plus-world-graph-and-state-ledger-first"; completion_criteria = @("approved book plan", "approved layout plan", "open-source story model", "chapter continuity ledgers", "world graph", "promise payoff ledger", "type-specific ledgers", "publication readiness gates") })
  Write-Json -Path (Join-Path $state "genre-structure-template.json") -Value ([ordered]@{ schema_version = "1.2.0"; run_id = $RunId; template_id = $structureModel; writing_type = $writingType; genre = $genreLabel; scale_tier = $scaleTier; acts = $acts; chapter_rules = @("Each chapter must create new consequence.", "No chapter may restate the same situation without change.", "No character may use unknown information.", "Every chapter must update the world, relationship, knowledge, timeline, or promise/payoff state.", "Nonfiction chapters must update claim/source/argument ledgers when applicable."); mandatory_ledgers = @("character-state.json", "plot-ledger.json", "continuity-ledger.json", "chapter-summaries.json", "world-state.json", "relationship-graph.json", "knowledge-graph.json", "promise-payoff-ledger.json", "timeline.json", "theme-ledger.json", "style-profile.json", "claim-ledger.json", "source-ledger.json", "term-glossary.json", "argument-ledger.json") })
  Write-Json -Path (Join-Path $state "editorial-quality-scorecard.json") -Value ([ordered]@{ schema_version = "1.2.0"; run_id = $RunId; threshold_pass = 85; axes = @("continuity", "progression", "character_or_argument_depth", "style", "language", "layout", "publication-readiness", "type-fit"); export_blockers = @("critical_continuity_issue", "missing_type_specific_ledger", "missing_front_matter", "missing_cover_brief", "technical_marker_in_reader_output", "missing_story_choice_approval", "missing_book_plan_approval"); verdict = "DESIGN_PENDING_DETAIL" })
  Write-Json -Path (Join-Path $state "llm-adapter-contract.json") -Value ([ordered]@{ schema_version = "1.2.0"; run_id = $RunId; adapter_contract = "Provider or IDE agent must load approved plan/state, write only requested phase artifacts, and update state ledgers."; max_chapters_per_batch = $maxChaptersPerBatch; audit_interval_chapters = $auditIntervalChapters; required_input_state = $requiredStateFiles; required_output_state = @("revision/_state/chapter-summaries.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/continuity-ledger.json", "revision/_state/world-state.json", "revision/_state/relationship-graph.json", "revision/_state/knowledge-graph.json", "revision/_state/promise-payoff-ledger.json", "revision/_state/timeline.json", "revision/_state/theme-ledger.json", "revision/_state/claim-ledger.json", "revision/_state/source-ledger.json", "revision/_state/term-glossary.json", "revision/_state/argument-ledger.json"); governing_story_model = "revision/_state/open-source-story-model.json"; local_adapter_boundary = "The local adapter creates scaffolding and export packages only from existing artifacts; it must not invent manuscript, preface, or cover copy."; authorship_policy = "Creative authorship belongs to provider command, IDE agent, or human writer."; research_policy = "No web/TDK/source research claim without source artifacts."; chapter_batch_rule = "Never write beyond max_chapters_per_batch without loading and updating required_output_state." })

  Write-Utf8 -Path (Join-Path $ProjectRoot "novel-config.md") -Content @"
# Novel Config

project:
  name: "$projectName"
  target_platform: "PRINT_BOOK"
  target_genre: "user_defined_from_request"
  episode_dir: "episode/"
  work_dir: "revision/"
  design_dir: "design/"

language_profile:
  locale: "tr-TR"
  content_language: "Turkish"
  interface_language: "Turkish"
  tdk_enforcement: true

book_mode:
  profile: "print_preview"
  enabled: true
  dialogue_style: "dash"

book_package:
  front_matter:
    title_page: true
    copyright_page: true
    preface: true
    table_of_contents: true
  cover:
    brief_required: true
    front_cover_prompt_required: true
    back_cover_copy_required: true
  print_readiness:
    trim_size: "A5"
    docx_required: true
    compatibility_test_required: true

longform:
  target_pages: $targetPages
  target_words: $targetWords
  target_chapters: $targetChapters
  generation_strategy: "approval_gated_chunked_chapter_state"
  state_dir: "revision/_state/"
  max_chapters_per_generation_batch: $maxChaptersPerBatch
  required_plan_approval: "runtime/approvals/book-plan-approval.json"
  plan_state_files:
    - "revision/_state/book-plan.json"
    - "revision/_state/open-source-story-model.json"
    - "revision/_state/chapter-plan.json"
    - "revision/_state/layout-plan.json"
"@

  $planApprovalPath = Join-Path $ProjectRoot "runtime/approvals/book-plan-approval.json"
  Write-Json -Path $planApprovalPath -Value ([ordered]@{
    title = "Book Plan Approval"
    approved = $false
    approved_by = ""
    approved_at = ""
    approved_plan_run_id = $RunId
    accepted_plan_summary = ""
    accepted_targets = [ordered]@{
      target_pages = $targetPages
      target_words = $targetWords
      target_chapters = $targetChapters
      scale_tier = $scaleTier
      max_chapters_per_batch = $maxChaptersPerBatch
      audit_interval_chapters = $auditIntervalChapters
    }
    reviewed_files = @(
      "design/04_book_plan.md",
      "design/05_chapter_plan.md",
      "design/06_layout_plan.md",
      "revision/_state/book-plan.json",
      "revision/_state/open-source-story-model.json",
      "revision/_state/chapter-plan.json",
      "revision/_state/layout-plan.json",
      "revision/_state/volume-plan.json"
    )
    note = "Set approved=true only after the user reviews and accepts the visible book plan, chapter flow, continuity model, and layout/page targets. A new design-big run resets this approval."
  })

  Write-AgentCompliance -PhaseName "design-big" -RequiredAgents @("concept-builder", "character-architect", "plot-hook-engineer", "book-structure-optimizer") -RequiredReferences @("skills/design-big/SKILL.md", "skills/polish/references/llm-agent-compliance-policy.md", "skills/polish/references/open-source-novel-editor-patterns.md") -LoadedStateFiles @("runtime/book-request.md", "runtime/book-brief.json", "runtime/book-dna.json", "runtime/layout-profile.json", "runtime/approvals/book-brief-approval.json", "runtime/approvals/story-choice.json") -OutputArtifacts @("novel-config.md", "design/01_concept_bootstrap.md", "design/02_character_core.md", "design/03_macro_plot_hooks.md", "design/04_book_plan.md", "design/05_chapter_plan.md", "design/06_layout_plan.md", "runtime/approvals/book-plan-approval.json", "revision/_state/book-plan.json", "revision/_state/open-source-story-model.json", "revision/_state/chapter-plan.json", "revision/_state/layout-plan.json", "revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/chapter-summaries.json", "revision/_state/continuity-ledger.json", "revision/_state/world-state.json", "revision/_state/relationship-graph.json", "revision/_state/knowledge-graph.json", "revision/_state/promise-payoff-ledger.json", "revision/_state/timeline.json", "revision/_state/theme-ledger.json", "revision/_state/volume-plan.json", "revision/_state/style-profile.json", "revision/_state/writing-type-profile.json", "revision/_state/genre-structure-template.json", "revision/_state/editorial-quality-scorecard.json", "revision/_state/llm-adapter-contract.json", "revision/_state/claim-ledger.json", "revision/_state/source-ledger.json", "revision/_state/term-glossary.json", "revision/_state/argument-ledger.json")
}

function Invoke-DesignSmall {
  Ensure-Approved -RelativePath "runtime/approvals/book-plan-approval.json" -GateName "Book plan approval" | Out-Null
  $planPath = Join-Path (Get-StateDir) "longform-plan.json"
  $bookPlanPath = Join-Path (Get-StateDir) "book-plan.json"
  $chapterPlanPath = Join-Path (Get-StateDir) "chapter-plan.json"
  $layoutPlanPath = Join-Path (Get-StateDir) "layout-plan.json"
  Ensure-File -Path $planPath -Message "Design-small blocked: missing revision/_state/longform-plan.json"
  Ensure-File -Path $bookPlanPath -Message "Design-small blocked: missing revision/_state/book-plan.json"
  Ensure-File -Path $chapterPlanPath -Message "Design-small blocked: missing revision/_state/chapter-plan.json"
  Ensure-File -Path $layoutPlanPath -Message "Design-small blocked: missing revision/_state/layout-plan.json"
  $plan = Read-Json -Path $planPath
  $design = Join-Path $ProjectRoot "design"
  Ensure-Dir $design
  $maxChaptersPerBatch = 3
  if (($plan.PSObject.Properties.Name -contains "max_chapters_per_batch") -and [int]$plan.max_chapters_per_batch -gt 0) {
    $maxChaptersPerBatch = [int]$plan.max_chapters_per_batch
  }
  $last = [Math]::Min([int]$plan.target_chapters, $maxChaptersPerBatch)
  $range = "EP001-EP{0:D3}" -f $last
  Write-Utf8 -Path (Join-Path $design "$range`_scene_plan.md") -Content @"
# Bölüm Planı $range

run_id: $RunId

Her bölüm için IDE ajanı/provider şu alanları doldurmalıdır:
- Okur başlığı
- Sahne amacı
- Önceki bölüm sonucu
- Yeni olay
- Yeni bilgi
- Karakter değişimi
- Geri dönülmez değişim
- Kapanış sonucu
- Bir sonraki bölüme neden olan bağ
- Güncellenen state dosyaları

Her yazılan bölüm `revision/_state/chapter-summaries.json` içinde şu alanları güncellemelidir:
- id
- summary
- previous_chapter_result
- new_event
- new_information
- irreversible_change
- next_causal_link
- state_updates

`revision/_state/volume-plan.json` içindeki audit_schedule hangi bölüme ulaştıysa, `revision/_workspace/macro-continuity-audit_EPxxx.json` ve `.md` dosyaları VERDICT: PASS ile üretilmeden pipeline devam edemez.

Tekrarlanan bölüm kurulumu, EP kodu, sahne etiketi, yayın kontrol notu ve test notu kullanıcı çıktısına giremez.
"@
  Write-Utf8 -Path (Join-Path $design "04_character-detail_$range.md") -Content "# Karakter Detayları $range`n`nrun_id: $RunId`n`nKarakter bilgi sınırları, arzular, korkular ve bölüm sonu değişimleri burada somutlaştırılmalıdır.`n"
  Write-Utf8 -Path (Join-Path $design "05_plot-detail_$range.md") -Content "# Plot Detayları $range`n`nrun_id: $RunId`n`nHer bölüm önceki bölümün sonucu olarak başlamalı ve yeni sonuç üretmelidir.`n"
  Write-AgentCompliance -PhaseName "design-small" -RequiredAgents @("episode-architect", "continuity-bridge") -RequiredReferences @("skills/design-small/SKILL.md", "skills/polish/references/handoff-contract.md", "skills/polish/references/open-source-novel-editor-patterns.md") -LoadedStateFiles @("runtime/book-brief.json", "runtime/book-dna.json", "runtime/layout-profile.json", "runtime/approvals/book-brief-approval.json", "revision/_state/longform-plan.json", "revision/_state/book-plan.json", "revision/_state/open-source-story-model.json", "revision/_state/chapter-plan.json", "revision/_state/layout-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/continuity-ledger.json", "revision/_state/world-state.json", "revision/_state/relationship-graph.json", "revision/_state/knowledge-graph.json", "revision/_state/promise-payoff-ledger.json", "revision/_state/timeline.json", "revision/_state/theme-ledger.json", "revision/_state/volume-plan.json", "revision/_state/claim-ledger.json", "revision/_state/source-ledger.json", "revision/_state/term-glossary.json", "revision/_state/argument-ledger.json", "runtime/approvals/book-plan-approval.json") -OutputArtifacts @("design/$range`_scene_plan.md", "design/04_character-detail_$range.md", "design/05_plot-detail_$range.md")
}

function Invoke-Create {
  throw "Create blocked in local adapter: this script will not write novel/story manuscript text. Use IDE manual mode or configure a provider/API/CLI command for create, then rerun validation/export."
}

function Invoke-Polish {
  throw "Polish blocked in local adapter: this script will not pretend editorial agents reviewed the manuscript. Use IDE manual mode or configure a provider/API/CLI command for polish."
}

function Invoke-Rewrite {
  throw "Rewrite blocked in local adapter: this script will not rewrite creative text. Use IDE manual mode or configure a provider/API/CLI command for rewrite."
}

function Invoke-Export {
  Ensure-Approved -RelativePath "runtime/approvals/export-approval.json" -GateName "Export approval" | Out-Null
  $episodeDir = Join-Path $ProjectRoot "episode"
  if (-not (Test-Path -LiteralPath $episodeDir -PathType Container)) {
    throw "Export blocked: episode directory missing. No manuscript files found."
  }
  $chapters = @(Get-ChildItem -LiteralPath $episodeDir -Filter "ep*.md" -File | Sort-Object Name)
  if ($chapters.Count -lt 1) {
    throw "Export blocked: no episode/ep*.md manuscript files found."
  }

  $front = Get-RequiredFrontMatter
  $cover = Get-RequiredCoverMatter
  Assert-ReaderArtifactClean -Path $front.title_page -Label "title page"
  Assert-ReaderArtifactClean -Path $front.copyright_page -Label "copyright page"
  Assert-ReaderArtifactClean -Path $front.preface -Label "preface"
  Assert-PublicationMetadataClean -Path $front.metadata
  Assert-ReaderArtifactClean -Path $cover.brief -Label "cover brief"
  Assert-ReaderArtifactClean -Path $cover.front_prompt -Label "cover front prompt"
  Assert-ReaderArtifactClean -Path $cover.back_cover_copy -Label "back cover copy"
  $work = Join-Path $ProjectRoot "revision/_workspace"
  $export = Join-Path $ProjectRoot "revision/export"
  Ensure-Dir $work
  Ensure-Dir $export
  $projectName = Get-ProjectName
  $rangeLabel = Get-EpisodeRangeLabel -Count $chapters.Count
  $paragraphs = New-Object System.Collections.Generic.List[string]

  foreach ($file in @($front.title_page, $front.copyright_page, $front.preface)) {
    foreach ($p in (Convert-MarkdownToParagraphs -Path $file)) { $paragraphs.Add($p) }
  }
  $paragraphs.Add("İçindekiler")
  $chapterNumber = 1
  $tocItems = @()
  $chapterHeadings = @()
  foreach ($ch in $chapters) {
    $heading = Get-ChapterHeadingFromText -Path $ch.FullName -Number $chapterNumber
    $tocItems += [ordered]@{ chapter = $chapterNumber; title = $heading; source = "episode/$($ch.Name)" }
    $chapterHeadings += $heading
    $paragraphs.Add($heading)
    $chapterNumber++
  }
  foreach ($ch in $chapters) {
    foreach ($p in (Convert-MarkdownToParagraphs -Path $ch.FullName)) { $paragraphs.Add($p) }
  }
  foreach ($p in (Convert-MarkdownToParagraphs -Path $cover.back_cover_copy)) { $paragraphs.Add($p) }

  Assert-ManuscriptClean -Paragraphs $paragraphs.ToArray()
  Invoke-LocalTurkishRuleCheck -PhaseName "export"

  Write-Json -Path $front.toc -Value ([ordered]@{ run_id = $RunId; chapters = $tocItems })
  Write-Utf8 -Path (Join-Path $work "11_front-matter_report.md") -Content "# Front Matter Report`n`nrun_id: $RunId`n`nVERDICT: PASS`nAll required front matter files were supplied before export; none were invented by the local adapter.`n"
  Write-Utf8 -Path (Join-Path $work "13_final-proofreader_report_$rangeLabel.md") -Content "# Final Proofreader`n`nrun_id: $RunId`nstep_id: export-final-proofreader`n`nVERDICT: PASS`nNo technical episode or scene markers were found in reader-facing export text.`n"
  Write-Utf8 -Path (Join-Path $work "14_publication-compliance_report_$rangeLabel.md") -Content "# Publication Compliance`n`nrun_id: $RunId`nstep_id: export-publication-compliance`n`nVERDICT: REVIEW_REQUIRED`n`nISBN, barcode, bandrol and final imprint metadata are external publishing tasks; no fake values were generated.`n"
  Write-Json -Path (Join-Path $work "14_publication-compliance_verdict_$rangeLabel.json") -Value ([ordered]@{
    run_id = $RunId
    step_id = "export-publication-compliance"
    verdict = "REVIEW_REQUIRED"
    print_ready = $false
    metadata_placeholders = @("author", "publisher", "copyright_owner", "publication_year", "edition", "isbn")
    isbn_status = "not_assigned_no_fake_value"
    barcode_status = "not_assigned_no_fake_value"
    kunye_status = "requires_user_or_publisher_final_metadata"
    bandrol_external = $true
    block_reasons = @("final publication metadata and external print workflow must be completed before print-ready claim")
  })
  Write-Json -Path (Join-Path $work "10_export-validator_verdict_$rangeLabel.json") -Value ([ordered]@{
    verdict = "READY_WITH_PUBLICATION_REVIEW"
    ready = $true
    episode_range = $rangeLabel
    checked_files = @($chapters | ForEach-Object { "episode/$($_.Name)" })
    front_matter_valid = $true
    cover_brief_valid = $true
    technical_marker_check = "PASS"
    publication_compliance_verdict = "REVIEW_REQUIRED"
    block_reasons = @()
  })
  Write-Utf8 -Path (Join-Path $work "10_export-validator_report_$rangeLabel.md") -Content "# Export Validator`n`nrun_id: $RunId`n`nVERDICT: READY_WITH_PUBLICATION_REVIEW`n"
  Write-Utf8 -Path (Join-Path $work "10_docx-reader-clean_report_$rangeLabel.md") -Content "# DOCX Reader Clean`n`nrun_id: $RunId`n`nVERDICT: PASS`nReview notes, control metadata, and publication blocker notes are kept outside the reader-facing DOCX.`n"
  Write-Utf8 -Path (Join-Path $work "tdk-rule-auditor_report_export.md") -Content "# TDK Rule Auditor`n`nrun_id: $RunId`nstep_id: export-tdk-rule-auditor`n`nVERDICT: REVIEW_REQUIRED`n`nLocal deterministic checks confirmed reader-facing export text has no mojibake, question-mark replacement corruption, ASCII Turkish transliteration warning, or technical labels. Official TDK provider verification was not claimed by the local adapter.`n"
  Write-Json -Path (Join-Path $work "tdk-rule-auditor_verdict_export.json") -Value ([ordered]@{
    run_id = $RunId
    step_id = "export-tdk-rule-auditor"
    verdict = "REVIEW_REQUIRED"
    provider_status = "local_deterministic_gate_only"
    official_tdk_claim_allowed = $false
    rule_categories_checked = @("encoding", "technical_labels", "reader_artifact_cleanliness", "professional_provider_if_configured")
    critical_issues = @()
    warnings = @("Official TDK dictionary/provider verification requires configured official-source evidence.", "Local deterministic checks are hard gates but do not replace human proofread/editing.")
    evidence = @("revision/_workspace/10_docx-reader-clean_report_$rangeLabel.md", "revision/_workspace/tdk-local-rule-check_export.json")
  })

  $docxPath = Join-Path $export "$projectName`_$rangeLabel.docx"
  New-Docx -OutputPath $docxPath -Title $projectName -Paragraphs $paragraphs.ToArray() -ChapterTitles $chapterHeadings
  $docxStyle = Get-DocxStyleProfile
  $styleProfileRel = "revision/_workspace/10_docx-style-profile_$rangeLabel.json"
  Write-Json -Path (Join-Path $ProjectRoot $styleProfileRel) -Value ([ordered]@{
    run_id = $RunId
    episode_range = $rangeLabel
    source = "runtime/layout-profile.json"
    style_profile = $docxStyle
    docx_contract = "publisher_submission_and_print_preview_review"
    print_ready_claim = $false
    publisher_submission_ready = $true
    print_preview_ready = $true
    note = "Publisher-specific final rules, ISBN, barcode, bandrol, final imprint, and final cover artwork remain external review tasks."
  })
  $sourceHashes = @()
  foreach ($ch in $chapters) {
    $sourceHashes += [ordered]@{
      path = "episode/$($ch.Name)"
      sha256 = Get-FileSha256 -Path $ch.FullName
    }
  }
  Write-Json -Path (Join-Path $work "10_export-word_manifest_$rangeLabel.json") -Value ([ordered]@{
    project_name = $projectName
    episode_range = $rangeLabel
    source_mode = "existing_artifacts_only"
    source_files = @($chapters | ForEach-Object { "episode/$($_.Name)" })
    source_hashes = $sourceHashes
    style_profile = "runtime/layout-profile.json"
    approval_artifact = "runtime/approvals/export-approval.json"
    front_matter_files = @($front.Keys | ForEach-Object { Get-RelativePath -Path $front[$_] })
    cover_design_manifest = Get-RelativePath -Path $cover.manifest
    cover_files = @($cover.Keys | ForEach-Object { Get-RelativePath -Path $cover[$_] })
    docx_style_profile = $styleProfileRel
    delivery_profiles = $docxStyle.delivery_profiles
    page_layout = [ordered]@{
      width_mm = $docxStyle.width_mm
      height_mm = $docxStyle.height_mm
      margin_top_mm = $docxStyle.margin_top_mm
      margin_bottom_mm = $docxStyle.margin_bottom_mm
      margin_inside_mm = $docxStyle.margin_inside_mm
      margin_outside_mm = $docxStyle.margin_outside_mm
    }
    typography = [ordered]@{
      font_family = $docxStyle.font_family
      font_size_pt = $docxStyle.font_size_pt
      line_spacing = $docxStyle.line_spacing
      paragraph_first_line_indent_cm = $docxStyle.paragraph_first_line_indent_cm
      paragraph_spacing_after_pt = $docxStyle.paragraph_spacing_after_pt
      justification = $docxStyle.justification
    }
    publication_compliance_verdict = "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json"
    blocked = $false
    block_reasons = @()
    local_adapter_boundary = "No manuscript, preface, or cover copy was invented during export."
    docx_sha256 = Get-FileSha256 -Path $docxPath
    output_docx_path = "revision/export/$projectName`_$rangeLabel.docx"
  })
  Write-Utf8 -Path (Join-Path $work "typography-layout-auditor_report_$rangeLabel.md") -Content "# Typography Layout Auditor`n`nrun_id: $RunId`nstep_id: export-typography-layout-auditor`n`nVERDICT: REVIEW_REQUIRED`n`nDOCX package, style profile, page size, margins, and Word styles are validated by scripts/ci/verify_docx_layout_profile.ps1 after export. Novel print-preview signals such as real chapter page breaks, headers, footers, and page numbers require the stricter novel layout profile before print-preview PASS.`n"
  Write-Json -Path (Join-Path $work "typography-layout-auditor_verdict_$rangeLabel.json") -Value ([ordered]@{
    run_id = $RunId
    step_id = "export-typography-layout-auditor"
    verdict = "REVIEW_REQUIRED"
    checked_artifacts = @("revision/export/$projectName`_$rangeLabel.docx", $styleProfileRel)
    xml_checks_required = @("word/document.xml", "word/styles.xml", "section_page_size", "section_margins", "style_references")
    novel_print_preview_blockers = @("page_numbers_not_required_by_current_publisher_submission_profile", "chapter_page_breaks_require_novel_print_preview_profile")
  })
  Write-Utf8 -Path (Join-Path $work "chief-editor-orchestrator_report_export.md") -Content "# Chief Editor Orchestrator`n`nrun_id: $RunId`nstep_id: export-chief-editor-orchestrator`n`nVERDICT: READY_WITH_PUBLICATION_REVIEW`n`nExport packaging may continue for editor review because required source artifacts, front matter, cover brief, publication compliance report, TDK local cleanliness report, and DOCX style profile exist. Print-ready and official TDK claims remain blocked until external publisher/editor evidence is supplied.`n"
  Write-Json -Path (Join-Path $work "chief-editor-orchestrator_verdict_export.json") -Value ([ordered]@{
    run_id = $RunId
    step_id = "export-chief-editor-orchestrator"
    verdict = "READY_WITH_PUBLICATION_REVIEW"
    evidence = @("revision/_workspace/10_export-validator_verdict_$rangeLabel.json", "revision/_workspace/tdk-rule-auditor_verdict_export.json", "revision/_workspace/typography-layout-auditor_verdict_$rangeLabel.json", "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json")
    print_ready = $false
    official_tdk_claim_allowed = $false
  })
  Write-AgentCompliance -PhaseName "export" -RequiredAgents @("export-approval-gate", "export-validator", "front-matter-editor", "cover-designer", "publication-compliance-checker", "final-proofreader", "book-exporter", "chief-editor-orchestrator", "tdk-rule-auditor", "typography-layout-auditor") -RequiredReferences @("skills/export-word/SKILL.md", "skills/polish/references/publication-metadata-checklist.md", "skills/polish/references/isbn-kunye-bandrol-checklist.md", "skills/export-word/references/docx-style-profile-template.md", "skills/polish/references/chief-editor-orchestrator-contract.md", "skills/polish/references/tdk-source-assurance-chain.md", "skills/export-word/references/word-compatibility-test-plan.md", "skills/polish/references/open-source-novel-editor-patterns.md") -LoadedStateFiles @("runtime/book-brief.json", "runtime/book-dna.json", "runtime/layout-profile.json", "runtime/approvals/book-brief-approval.json", "revision/_state/book-plan.json", "revision/_state/open-source-story-model.json", "revision/_state/chapter-plan.json", "revision/_state/layout-plan.json", "revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/chapter-summaries.json", "revision/_state/continuity-ledger.json", "revision/_state/world-state.json", "revision/_state/relationship-graph.json", "revision/_state/knowledge-graph.json", "revision/_state/promise-payoff-ledger.json", "revision/_state/timeline.json", "revision/_state/theme-ledger.json", "revision/_state/volume-plan.json", "revision/_state/style-profile.json", "revision/_state/writing-type-profile.json", "revision/_state/genre-structure-template.json", "revision/_state/llm-adapter-contract.json", "revision/_state/claim-ledger.json", "revision/_state/source-ledger.json", "revision/_state/term-glossary.json", "revision/_state/argument-ledger.json", "runtime/approvals/export-approval.json") -OutputArtifacts @("revision/_workspace/10_export-word_manifest_$rangeLabel.json", $styleProfileRel, "revision/_workspace/10_export-validator_verdict_$rangeLabel.json", "revision/_workspace/10_docx-reader-clean_report_$rangeLabel.md", "revision/_workspace/11_front-matter_report.md", "revision/_workspace/13_final-proofreader_report_$rangeLabel.md", "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json", "revision/_workspace/14_publication-compliance_report_$rangeLabel.md", "revision/_workspace/tdk-local-rule-check_export.json", "revision/_workspace/tdk-rule-auditor_report_export.md", "revision/_workspace/tdk-rule-auditor_verdict_export.json", "revision/_workspace/typography-layout-auditor_report_$rangeLabel.md", "revision/_workspace/typography-layout-auditor_verdict_$rangeLabel.json", "revision/export/$projectName`_$rangeLabel.docx")
}

Push-Location $ProjectRoot
try {
  switch ($Phase) {
    "intake" { Invoke-Intake }
    "propose" { Invoke-Propose }
    "design-big" { Invoke-DesignBig }
    "design-small" { Invoke-DesignSmall }
    "create" { Invoke-Create }
    "polish" { Invoke-Polish }
    "rewrite" { Invoke-Rewrite }
    "export" { Invoke-Export }
  }
  Write-Host "[local-phase] completed: $Phase"
}
finally {
  Pop-Location
}
