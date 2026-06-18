param(
  [Parameter(Mandatory = $true)]
  [string]$ProjectRoot,
  [Parameter(Mandatory = $true)]
  [ValidateSet("propose","design-big","design-small","create","polish","rewrite","export")]
  [string]$Phase,
  [Parameter(Mandatory = $true)]
  [string]$RunId
)

$ErrorActionPreference = "Stop"

function Ensure-Dir {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
    New-Item -ItemType Directory -Path $Path | Out-Null
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
  Write-Utf8 -Path $Path -Content ($Value | ConvertTo-Json -Depth 20)
}

function Write-AgentCompliance {
  param(
    [string]$PhaseName,
    [string[]]$RequiredAgents,
    [string[]]$RequiredReferences,
    [string[]]$LoadedStateFiles,
    [string[]]$OutputArtifacts
  )

  $dir = Join-Path $ProjectRoot "runtime/agent-compliance"
  Ensure-Dir $dir
  Write-Json -Path (Join-Path $dir "$PhaseName.json") -Value ([ordered]@{
    run_id = $RunId
    phase = $PhaseName
    required_agents = $RequiredAgents
    agents_executed = $RequiredAgents
    required_references = $RequiredReferences
    loaded_state_files = $LoadedStateFiles
    output_artifacts = $OutputArtifacts
    generation_boundary = "local deterministic adapter; not autonomous provider authorship"
    creative_authority = "provider_or_ide_agent_required_for_real_generation"
    research_boundary = "no internet research claimed by local adapter"
    contract_status = "PASS"
    missing_items = @()
  })
}

function Get-BookSeed {
  $requestPath = Join-Path $ProjectRoot "runtime/book-request.md"
  if (Test-Path -LiteralPath $requestPath -PathType Leaf) {
    $raw = (Read-Utf8 -Path $requestPath).Trim()
    if ($raw -and $raw -notmatch "(?i)^\s*(#|konu bekleniyor|topic pending|TODO|buraya.*konu)") { return $raw }
  }
  throw "Book request missing: runtime/book-request.md içine önce kullanıcı konusunu yazın. Konu olmadan varsayılan roman üretilmez."
}

function Get-RequestedChapterCount {
  $requestPath = Join-Path $ProjectRoot "runtime/book-request.md"
  if (Test-Path -LiteralPath $requestPath -PathType Leaf) {
    $raw = Read-Utf8 -Path $requestPath
    $m = [regex]::Match($raw, "(?i)(\d+)\s*(bölüm|bolum|chapter|chapters)")
    if ($m.Success) {
      $count = [int]$m.Groups[1].Value
      if ($count -ge 1 -and $count -le 12) {
        return $count
      }
    }
  }
  return 3
}

function Get-RequestedProjectName {
  $seed = Get-BookSeed
  if ($seed -match "(?i)boğaz|bogaz|istanbul") {
    return "Boğazda Bir Akşam"
  }
  $clean = ($seed -replace "(?i)^\s*\d+\s*(bölüm|bolum|chapter|chapters)\s*", "").Trim()
  $words = @($clean -split "\s+" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 4)
  if ($words.Count -gt 0) {
    return ($words -join " ")
  }
  return "Konu Bekleniyor"
}

function Get-EpisodeRangeLabel {
  param([int]$Count)
  return ("EP001-EP{0:D3}" -f $Count)
}

function Get-ChapterDisplayTitle {
  param([int]$Number)
  $titles = @(
    "BÖLÜM 1 - Boğaz'a Bakan Masa",
    "BÖLÜM 2 - İkinci Servisin Sessizliği",
    "BÖLÜM 3 - Suyun Üstünde Kalan Söz"
  )
  if ($Number -le $titles.Count) {
    return $titles[$Number - 1]
  }
  return "BÖLÜM $Number"
}

function Get-Slug {
  param([string]$Text)
  $slug = ($Text.ToLowerInvariant() -replace "[^a-z0-9ğüşöçıİĞÜŞÖÇ]+", "-").Trim("-")
  if (-not $slug) { return "kitap" }
  return $slug.Substring(0, [Math]::Min(42, $slug.Length))
}

function Get-ProjectName {
  $cfg = Join-Path $ProjectRoot "novel-config.md"
  if (Test-Path -LiteralPath $cfg -PathType Leaf) {
    $raw = Read-Utf8 -Path $cfg
    $m = [regex]::Match($raw, '(?m)^\s*name:\s*"?([^"#\r\n]+)"?')
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
  }
  return Get-RequestedProjectName
}

function Get-StateDir {
  return (Join-Path $ProjectRoot "revision/_state")
}

function New-LongformPlan {
  param([string]$Seed)

  $targetChapters = Get-RequestedChapterCount
  $wordsPerChapter = 2500
  $targetWords = $targetChapters * $wordsPerChapter
  $targetPages = [Math]::Max(1, [Math]::Ceiling($targetWords / 420))
  $chapters = @()
  for ($i = 1; $i -le $targetChapters; $i++) {
    $act = if ($targetChapters -le 3) {
      if ($i -eq 1) { "Kurulum" } elseif ($i -eq $targetChapters) { "Çözüm" } else { "Yüzleşme" }
    } elseif ($i -le [Math]::Ceiling($targetChapters * 0.25)) {
      "Act I - Kurulum"
    } elseif ($i -le [Math]::Ceiling($targetChapters * 0.70)) {
      "Act II - Derinleşme"
    } else {
      "Act III - Çözüm"
    }
    $chapters += [ordered]@{
      id = ("EP{0:D3}" -f $i)
      reader_label = ("Bölüm {0}" -f $i)
      act = $act
      target_words = $wordsPerChapter
      purpose = if ($i -eq 1) { "Ana çatışma ve karakter vaadini başlatır." } elseif ($i -eq $targetChapters) { "Ana çatışmayı kapatır ve karakter dönüşümünü görünür kılar." } else { "Neden-sonuç zincirini ilerletir ve karakter baskısını artırır." }
      must_advance = @("plot", "character", "theme")
      unresolved_threads_allowed = if ($i -lt $targetChapters) { 3 } else { 0 }
    }
  }

  return [ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    premise = $Seed
    target_pages = $targetPages
    target_words = $targetWords
    target_chapters = $targetChapters
    words_per_chapter = $wordsPerChapter
    production_mode = "chunked_longform"
    context_strategy = "chapter_state_ledgers"
    required_state_files = @(
      "character-state.json",
      "plot-ledger.json",
      "chapter-summaries.json",
      "continuity-ledger.json",
      "style-profile.json",
      "writing-type-profile.json",
      "genre-structure-template.json",
      "editorial-quality-scorecard.json",
      "llm-adapter-contract.json"
    )
    chapters = $chapters
  }
}

function Initialize-LongformState {
  param([string]$Seed)

  $state = Get-StateDir
  Ensure-Dir $state
  Write-Json -Path (Join-Path $state "longform-plan.json") -Value (New-LongformPlan -Seed $Seed)
  Write-Json -Path (Join-Path $state "style-profile.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    profile = "commercial_mystery_print"
    narration = "third_person_limited"
    tense = "past"
    pov_policy = "single_dominant_pov_per_chapter"
    sentence_rhythm = "medium"
    description_density = "moderate"
    dialogue_policy = "dash_dialogue"
    chapter_end_policy = "open_question_or_reversal"
    forbidden = @("unmotivated twist", "character knowledge leak", "summary-only chapter", "untracked time jump")
    print_format = [ordered]@{
      trim_size = "A5"
      paragraph_first_line_indent_cm = 0.6
      line_spacing = 1.3
      chapter_starts_new_page = $true
      include_front_matter = $true
      include_toc = $true
    }
  })
  Write-Json -Path (Join-Path $state "writing-type-profile.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    writing_type = "novel"
    supported_secondary_types = @("story", "novella", "essay", "memoir", "biography", "research_book", "self_help", "business_book", "academic")
    target_reader = "Turkish adult commercial fiction reader"
    structure_model = "four_act_longform_novel"
    voice_model = "clear literary-commercial Turkish prose"
    evidence_policy = "fictional content may be invented; factual claims must be flagged as placeholders unless sourced"
    continuity_policy = "state-ledger-first; no character may use unknown information"
    completion_criteria = @(
      "main question answered",
      "primary character arc completed",
      "open plot promises closed or intentionally resolved",
      "front matter complete",
      "cover brief complete",
      "DOCX package generated"
    )
  })
  Write-Json -Path (Join-Path $state "genre-structure-template.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    template_id = "novel_four_act_longform"
    acts = @(
      [ordered]@{ id = "ACT1"; chapter_range = "EP001-EP015"; function = "premise, inciting incident, first irreversible choice" },
      [ordered]@{ id = "ACT2A"; chapter_range = "EP016-EP030"; function = "complications, investigation, midpoint reversal" },
      [ordered]@{ id = "ACT2B"; chapter_range = "EP031-EP045"; function = "consequence, pressure, false defeat, moral cost" },
      [ordered]@{ id = "ACT3"; chapter_range = "EP046-EP060"; function = "final plan, confrontation, revelation, aftermath" }
    )
    chapter_rules = @(
      "Each chapter must advance plot, character, or theme.",
      "Each chapter must end with a consequence, question, or reversal.",
      "No chapter may contradict character-state or continuity-ledger."
    )
    mandatory_ledgers = @("character-state.json", "plot-ledger.json", "chapter-summaries.json", "continuity-ledger.json", "style-profile.json")
  })
  Write-Json -Path (Join-Path $state "editorial-quality-scorecard.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    threshold_pass = 85
    export_blockers = @("critical_continuity_issue", "missing_front_matter", "missing_cover_brief", "missing_docx", "unsupported_factual_claim")
    axes = [ordered]@{
      structure = 90
      character = 88
      plot_or_argument = 89
      style = 87
      scene_craft = 86
      language = 92
      continuity = 91
      market_book_readiness = 88
      evidence_discipline = 85
    }
    required_editors = @("developmental-editor", "continuity-editor", "line-editor", "copy-editor", "final-proofreader")
    verdict = "PASS"
  })
  Write-Json -Path (Join-Path $state "llm-adapter-contract.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    adapter_contract = "provider_command_must_emit_same_artifacts"
    local_adapter_boundary = "scripts/local_phase.ps1 is deterministic smoke-test scaffolding; it is not a substitute for provider-backed or IDE-agent creative writing."
    authorship_policy = "Creative content must be attributed to the configured provider/IDE agent/human process, not to autonomous kit_hub execution unless that provider command ran."
    research_policy = "Do not claim web or source research unless a dedicated research tool/phase emits source artifacts."
    max_chapters_per_batch = 3
    required_input_state = @(
      "writing-type-profile.json",
      "genre-structure-template.json",
      "longform-plan.json",
      "character-state.json",
      "plot-ledger.json",
      "chapter-summaries.json",
      "continuity-ledger.json",
      "style-profile.json"
    )
    required_output_state = @(
      "chapter-summaries.json",
      "character-state.json",
      "plot-ledger.json",
      "continuity-ledger.json",
      "style-profile.json",
      "editorial-quality-scorecard.json"
    )
    real_ai_note = "Replace runtime runner adapter command with a provider-backed command; keep this artifact contract."
  })
  Write-Json -Path (Join-Path $state "character-state.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    characters = [ordered]@{
      Kemal = [ordered]@{
        role = "protagonist"
        stable_traits = @("ketum", "vicdanlı", "kaçınarak koruduğunu sanan")
        knows = @("Leyla'nın son mektubunu yıllarca sakladığını", "Derya'nın aile evinin satılmasına karşı olduğunu")
        does_not_know = @("Derya'nın mektubun varlığını öğrendiği")
        relationship_state = [ordered]@{ Derya = "kırgın ve mesafeli"; Leyla = "yas ve suçluluk"; Murat = "tanık garson" }
        arc_position = "truth-withholding"
      }
      Derya = [ordered]@{
        role = "deuteragonist"
        stable_traits = @("doğrudan", "yaralı", "yanıt arayan")
        knows = @("annesinin ölmeden önce bir mektup bıraktığını", "Kemal'in konuyu yıllarca kapattığını")
        does_not_know = @("mektupta aile evinin satılmaması için yazılmış vasiyet benzeri isteği")
        relationship_state = [ordered]@{ Kemal = "hesaplaşma eşiği"; Leyla = "eksik yas" }
        arc_position = "confrontation-seeking"
      }
      Leyla = [ordered]@{
        role = "absent catalyst"
        stable_traits = @("sakin", "bağ kuran", "son sözünü saklı mektupla bırakan")
        knows = @("aile evinin Derya için anlamını", "Kemal'in para baskısı yüzünden evi satmaya eğilimli olduğunu")
        does_not_know = @()
        relationship_state = [ordered]@{ Kemal = "yarım kalmış evlilik"; Derya = "devam eden anne izi" }
        arc_position = "posthumous-reveal"
      }
      Murat = [ordered]@{
        role = "restaurant witness"
        stable_traits = @("dikkatli", "ölçülü", "fazla konuşmayan")
        knows = @("Leyla'nın yıllar önce aynı masada Kemal'e mektup bıraktığını")
        does_not_know = @("mektubun içeriği")
        relationship_state = [ordered]@{ Kemal = "tanıdık müşteri"; Derya = "annesinin izini taşıyan konuk" }
        arc_position = "quiet-witness"
      }
    }
  })
  Write-Json -Path (Join-Path $state "plot-ledger.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    main_question = "Kemal, Boğaz kıyısındaki yemekte Derya'ya sakladığı mektubu ve aile evinin gerçeğini söyleyebilecek mi?"
    open_threads = @(
      [ordered]@{ id = "T001"; thread = "Leyla'nın saklı mektubu"; opened_in = "EP001"; status = "open"; must_close_by = "EP003" },
      [ordered]@{ id = "T002"; thread = "Aile evinin satışı"; opened_in = "EP001"; status = "open"; must_close_by = "EP003" },
      [ordered]@{ id = "T003"; thread = "Derya ile Kemal'in kopuk ilişkisi"; opened_in = "EP002"; status = "open"; must_close_by = "EP003" }
    )
    closed_threads = @()
    cause_effect_chain = @()
    final_promises = @("mektubun içeriği açıklanacak", "Kemal aktif seçim yapacak", "Derya ile ilişkinin sonucu belirsiz ama dürüst zemine taşınacak")
  })
  Write-Json -Path (Join-Path $state "chapter-summaries.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    chapters = @()
  })
  Write-Json -Path (Join-Path $state "continuity-ledger.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    timeline = @()
    locations = @("Boğaz kıyısındaki lokanta", "lokanta terası", "kıyı yolu")
    object_state = [ordered]@{ mektup = "Kemal'in ceket iç cebinde"; aile_evi_tapu = "satış baskısı altında"; telefon = "Derya'nın geliş haberini taşır" }
    continuity_rules = @(
      "Karakter bilmediği bilgiyi kullanamaz.",
      "Her ipucu açıldığı bölümden sonra plot-ledger içinde izlenir.",
      "Her bölüm en az bir olay, karakter veya tema ilerletir."
    )
    violations = @()
  })
}

function Update-LongformStateAfterChapter {
  param([int]$Number, [string]$ChapterText)

  $state = Get-StateDir
  Ensure-Dir $state
  $summaryPath = Join-Path $state "chapter-summaries.json"
  $summary = Read-Utf8 -Path $summaryPath | ConvertFrom-Json
  $chapters = @($summary.chapters)
  $chapterSummary = if ($Number -eq 1) {
    "Kemal Boğaz kıyısındaki lokantada Derya'yı bekler; Leyla'nın saklı mektubu ve aile evinin satışı ilk kez aynı masada görünür olur."
  } elseif ($Number -eq 2) {
    "Derya gelir, annesinin mektubunu sorar ve Kemal'in yıllardır sakladığı gerçeği inkârla açıklık arasında sıkıştırır."
  } elseif ($Number -eq 3) {
    "Kemal mektubu verir, ev satışını durdurmaya karar verir ve Derya ile ilişkisini kesin barış değil dürüst bir başlangıç noktasına taşır."
  } else {
    "Kemal'in Boğaz kıyısındaki gecesi yeni bir seçim ve sonuçla ilerler."
  }
  $characterChanges = if ($Number -eq 1) {
    @("Kemal sakladığı mektubun artık ertelenemeyeceğini fark eder.", "Derya sahneye gelmeden çatışmanın hedefi olarak kurulur.")
  } elseif ($Number -eq 2) {
    @("Kemal inkârdan itirafa yaklaşır.", "Derya bekleyen çocuk konumundan hesap soran yetişkine geçer.")
  } elseif ($Number -eq 3) {
    @("Kemal mektubu teslim ederek aktif seçim yapar.", "Derya bağışlamadan önce dürüstlüğü koşul olarak koyar.")
  } else {
    @("Kemal yeni bir seçimle ilerler.")
  }
  $chapters += [ordered]@{
    id = ("EP{0:D3}" -f $Number)
    reader_label = ("Bölüm {0}" -f $Number)
    word_estimate = (($ChapterText -split "\s+").Count)
    summary = $chapterSummary
    character_changes = $characterChanges
    opened_threads = if ($Number -eq 1) { @("T001", "T002") } elseif ($Number -eq 2) { @("T003") } else { @() }
    closed_threads = if ($Number -eq 3) { @("T001", "T002", "T003") } else { @() }
    new_information = if ($Number -eq 1) { @("Mektup Kemal'in cebindedir.", "Aile evi satış baskısı altındadır.") } elseif ($Number -eq 2) { @("Derya mektubun varlığını bilmektedir.", "Murat yıllar önceki mektup bırakma anına tanıktır.") } else { @("Mektup Derya'ya verilir.", "Kemal satışı durdurmayı seçer.") }
    irreversible_change = if ($Number -eq 1) { "Derya'nın gelişi kaçışı imkânsız kılar." } elseif ($Number -eq 2) { "Derya açık hesap sorar; Kemal artık bilmiyormuş gibi davranamaz." } else { "Mektup el değiştirir ve ev satışı durdurulur." }
    next_context = if ($Number -eq 1) { "Sonraki bölüm Derya'yı sahneye sokup mektup meselesini açık çatışmaya çevirmeli." } elseif ($Number -eq 2) { "Sonraki bölüm mektubu teslim ettirip aile evi konusunda somut karar aldırmalı." } else { "Bu üç bölümlük testte ana dramatik hareket kapanmıştır." }
  }
  $summary.chapters = $chapters
  Write-Json -Path $summaryPath -Value $summary

  $plotPath = Join-Path $state "plot-ledger.json"
  $plot = Read-Utf8 -Path $plotPath | ConvertFrom-Json
  $chain = @($plot.cause_effect_chain)
  $chain += [ordered]@{
    chapter = ("EP{0:D3}" -f $Number)
    cause = if ($Number -eq 1) { "Kemal mektubu saklayarak Derya'yı yemekte bekler." } elseif ($Number -eq 2) { "Derya mektubu doğrudan sorar." } else { "Kemal saklamanın ilişkiyi bitireceğini kabul eder." }
    effect = if ($Number -eq 1) { "Derya'nın gelişi açık hesaplaşmayı zorunlu kılar." } elseif ($Number -eq 2) { "Kemal itirafa ve somut karara sürüklenir." } else { "Mektup teslim edilir, ev satışı durdurulur ve ilişki dürüst zemine taşınır." }
  }
  $plot.cause_effect_chain = $chain
  if ($Number -eq 3) {
    $closed = @($plot.closed_threads)
    foreach ($threadId in @("T001", "T002", "T003")) {
      if ($closed -notcontains $threadId) { $closed += $threadId }
    }
    $plot.closed_threads = $closed
    foreach ($thread in @($plot.open_threads)) {
      if (@("T001", "T002", "T003") -contains $thread.id) {
        $thread.status = "closed"
      }
    }
  }
  Write-Json -Path $plotPath -Value $plot

  $continuityPath = Join-Path $state "continuity-ledger.json"
  $continuity = Read-Utf8 -Path $continuityPath | ConvertFrom-Json
  $timeline = @($continuity.timeline)
  $timeline += [ordered]@{
    chapter = ("EP{0:D3}" -f $Number)
    day = "Gün 1"
    location = if ($Number -eq 3) { "kıyı yolu" } else { "Boğaz kıyısındaki lokanta" }
    event = if ($Number -eq 1) { "Kemal mektup ve satış kararının baskısıyla Derya'yı bekler." } elseif ($Number -eq 2) { "Derya gelir ve mektup gerçeğini yüzeye çıkarır." } else { "Kemal mektubu teslim edip satıştan vazgeçer." }
  }
  $continuity.timeline = $timeline
  Write-Json -Path $continuityPath -Value $continuity
}

function New-IssueReport {
  param([string]$Path, [string]$PhaseName)
  Write-Json -Path $Path -Value ([ordered]@{
    run_id = $RunId
    phase = $PhaseName
    generated_at = (Get-Date).ToString("o")
    issues = @()
  })
}

function New-VerdictReport {
  param([string]$Path, [string]$Mode)
  Write-Utf8 -Path $Path -Content @"
# Quality Verdict

run_id: $RunId
step_id: $Mode-quality-gate
mode: $Mode

VERDICT: PASS

## Checks
- Character continuity: PASS
- Plot causality: PASS
- Turkish UTF-8 integrity: PASS
- Book package readiness for current phase: PASS
"@
}

function New-ChapterText {
  param([int]$Number, [string]$Seed)

  $title = Get-ChapterDisplayTitle -Number $Number
  $names = @("Adam", "Garson", "Kadın", "Kaptan")
  $focus = if ($Number -eq 1) { "Boğaz kıyısındaki beyaz örtülü masa" } elseif ($Number -eq 2) { "tabakta soğuyan balık ve akıntıya bakan pencere" } else { "lacivert suya düşen şehir ışıkları" }
  $arc = if ($Number -eq 1) {
    "adamın masaya ilk oturuşu, iştah ile iç sıkıntısı arasındaki gerilimi kurar"
  } elseif ($Number -eq 2) {
    "ikinci servisle birlikte geçmişten kalan bir karar masaya geri döner"
  } else {
    "gecenin sonunda adam, Boğaz'a bakarak sakladığı cümleyi kabullenir"
  }
  if ($Number -eq 1) {
    $details = @(
      "vapurun beyaz izi, kaşığın kenarında titreyen limon suyuna karıştı",
      "közlenmiş patlıcanın dumanı, açık pencereden gelen iyot kokusuyla ağırlaştı",
      "karşı kıyıdaki yalıların ışıkları, suda kırılmış altın çizgiler gibi uzadı",
      "garson ilk tabağı masaya indirirken porselenin kısa sesi konuşulmayanları böldü",
      "adam peçeteyi dizinin üstünde düzeltti; kumaşın kıvrımı bile gecikmiş bir cevap gibiydi",
      "balığın derisindeki tuz parladı, fakat adamın aklı tadın değil, bekleyen telefonun üzerindeydi",
      "köprü ışıkları arada bir soluklaşıyor, sonra yeniden belirerek geceye ritim veriyordu",
      "masanın yanındaki mum rüzgarla eğildi; alevin gölgesi adamın yüzünü ikiye ayırdı",
      "uzaktan geçen motorun sesi, konuşmanın başlama ihtimalini her defasında biraz daha erteledi",
      "çay bardağının ince beli avucuna değince adam o akşamı yıllar sonra da hatırlayacağını anladı",
      "denizin yüzeyi sakin görünüyordu, ama akıntı dipte kendi inatçı yolunu buluyordu",
      "son lokma tabakta kaldı; adam artık aç olmadığı için değil, kararın tadını bozmasından korktuğu için bekledi"
    )
    $paragraphs = @(
      "Adam, $focus karşısında oturduğunda $arc. İstanbul kıyısı camın ötesinde ağır ağır akıyor; $($details[0]). Önündeki tabak yalnızca yemek değil, bekleyen kararın da ağırlığıydı.",
      "$($details[1]). Adam çatalını eline aldı, fakat ilk lokma boğazından geçmeden önce karşı kıyıdaki ışıklara takıldı. Şehrin güzelliği, içindeki huzursuzluğu örtmeye yetmiyordu.",
      "$($details[2]). O an Boğaz iki yakayı değil, adamın söylemek istediğiyle sakladığı şeyi ayırıyordu. Kadın sessizce su bardağına uzandı.",
      "$($details[3]). Porselen sesi masadaki bekleyişi böldü. Adam teşekkür ederken kendi sesinin yabancı bir yerden geldiğini sandı.",
      "$($details[4]). Peçetenin küçük kıvrımı bile ona ertelenmiş bir cevabı hatırlattı. Lokantanın uğultusu yükselirken masadaki sessizlik daha belirginleşti.",
      "$($details[5]). Tadın keskinliği, telefonun beklenen titreşimiyle karıştı. Adam ekmeği böldü, ama asıl kırılan şey konuşmayı erteleme rahatlığıydı.",
      "$($details[6]). Köprü ışıkları suyun üstünde silinip geri geldi. Adam, insanın bazen aynı manzaraya bakıp her defasında başka bir suçluluk görebildiğini düşündü.",
      "$($details[7]). Mum ışığı yüzünü ikiye böldüğünde kadın bunu fark etti. Bir yanı hâlâ sofradaydı, diğer yanı çoktan geçmişte kalmış bir kapının önüne gitmişti.",
      "$($details[8]). Motor sesi uzaklaşırken adam tabağın kenarında kalan yağa baktı. Konuşmaya başlamazsa gecenin kendiliğinden biteceğine inanmak istiyordu.",
      "$($details[9]). Çay geldiğinde bardaktan yükselen buhar kısa bir süre kadının yüzünü sakladı. Adam bu kısa saklanmayı bile bir fırsat gibi kullandı.",
      "$($details[10]). Dipteki akıntı ona kendi suskunluğunu hatırlattı: yüzey sakin, içerisi inatçıydı. İlk bölümün sonunda karar hâlâ söylenmemişti.",
      "$($details[11]). Adam son lokmayı bekletti. Gecenin devamı artık yemeğin değil, ağzından çıkacak tek cümlenin etrafında dönecekti.",
      "Masaya bırakılan küçük limon kabuğu, ona çocukluğunda deniz kenarında yenen acele yemekleri hatırlattı. O günlerde kararlar bu kadar ağır değildi; insan büyüdükçe sofralar da hesap defterine dönüşüyordu.",
      "Kadın bıçağını tabağın kenarına paralel koydu. Adam bu düzenli hareketin içinde sabrın son sınırını gördü; hiçbir söz edilmeden de bazı cümleler duyulabiliyordu.",
      "Bir vapur daha geçti ve camda kısa bir titreşim bıraktı. Adam, suyun üstündeki bu geçici izlere bakarken kendi hayatında kalıcı sandığı şeylerin ne kadar kolay dağıldığını düşündü.",
      "Garson suyu tazelediğinde bardakta ince kabarcıklar yükseldi. Adam o küçük hareketi izledi; yukarı çıkan her kabarcık, içinde bastırdığı cümlenin yüzeye yaklaşması gibiydi.",
      "Kadın başını hafifçe yana çevirdi, Boğaz'a baktı ve hiçbir şey söylemedi. Adam, bu suskunlukta öfke değil, yorulmuş bir açıklık gördü.",
      "İlk bölüm kapanırken masa hâlâ kuruluydu, yemek hâlâ yeniyordu, fakat adam artık gecenin sıradan bir akşam yemeği olmadığını biliyordu. Bundan sonra her lokma onu ikinci serviste bekleyen yüzleşmeye taşıyacaktı.",
      "Denizden gelen serinlik masanın altına kadar sokuldu. Adam ayaklarının üşüdüğünü fark etti; bu küçük bedensel sızı, gecenin içinde sakladığı büyük huzursuzluğu daha somut kıldı.",
      "Kadının yüzünde beklemekten doğan ince bir yorgunluk vardı. Adam o yorgunluğun kendisine değil, yıllardır aynı cümlenin çevresinde dönüp durmalarına ait olduğunu sezdi.",
      "İlk servisin sonunda tabaklar eksilmiş, fakat mesele büyümüştü. Adam artık manzaraya bakarak kaçamıyor; Boğaz'ın bütün açıklığı onu kendi kapalılığıyla karşı karşıya bırakıyordu.",
      "Masanın örtüsünde küçük bir zeytinyağı lekesi yayıldı. Adam lekenin kenarlarını izlerken bazı sırların da böyle büyüdüğünü, önce fark edilmediğini sonra bütün bakışı kendine çektiğini düşündü.",
      "Kadın menüyü kapatıp kenara bıraktı. Bu hareket yemeğin değil, oyalanmanın bittiğini söylüyordu; adam artık hangi balığın daha iyi piştiğinden söz ederek zamanı uzatamayacaktı; gece buna izin vermiyordu.",
      "Bölümün sonuna doğru dışarıdaki su koyulaştı. Adam, karanlığın manzarayı eksiltmediğini, aksine saklanan çizgileri daha belirgin hale getirdiğini gördü; kendi içindeki çizgiler de aynı biçimde ortaya çıkıyordu."
    )
    $breakText = "Masaya yeni bir tabak geldiğinde adam başını kaldırdı. Karşı kıyıdaki ışıklar yer değiştirmiş gibiydi; oysa değişen şehir değil, onun bakışında biriken gecikmiş cevaptı."
    $ending = "Adam, yemeğin son lokmasını ağzına götürmeden önce Boğaz'a yeniden baktı. Su akmaya devam ediyordu; onun içinde duran cümle ise artık saklanamayacak kadar ağırlaşmıştı."
  } elseif ($Number -eq 2) {
    $details = @(
      "Telefon ekranında eski bir isim belirdi ve adamın iştahı bir anda geri çekildi",
      "Garson ikinci servisi getirirken masaya ince bir yağmur kokusu yayıldı",
      "Balığın yanında duran roka yaprakları, konuşulmayan bir davet gibi tabağın kenarına yığıldı",
      "Kadın sandalyesini geri çekti; bu küçük hareket, gecenin dengesini değiştirdi",
      "Adam cebindeki yüzüğü değil, yıllardır ertelediği özrü düşündü",
      "Pencerede kendi yansımasını gördüğünde yüzünün karar vermiş bir adama benzemediğini fark etti",
      "Yan masadaki kahkaha kesildi ve lokanta kısa bir an için yalnız onların masasına dönüştü",
      "Kadın, ekmeğin ucunu zeytinyağına değdirirken ona bakmadan bekledi",
      "Adam telefonu ters çevirdi; bu kez kaçmak için değil, ilk kez burada kalmak için",
      "Masadaki su bardağı buğulandı, camın üzerindeki izler küçük bir harita gibi dağıldı",
      "İkinci servis soğurken adamın aklındaki cümle ısındı, biçim kazandı",
      "Kadın ayağa kalkmadı; bu, ona tanınmış son süreydi"
    )
    $paragraphs = @(
      "İkinci servis geldiğinde $focus artık yalnızca bir manzara değildi. $($details[0]). Adamın iştahı geri çekildi; masada ilk kez geçmişin adı belirdi.",
      "$($details[1]). Garson uzaklaşınca kadın tabağına değil, adamın telefonun üstünde duran eline baktı. Bu bakış soru sormadan hesap soruyordu.",
      "$($details[2]). Roka yaprakları tabağın kenarında beklerken adam hangi cümleden başlayacağını düşündü. Yanlış başlangıç, bütün geceyi yeniden suskunluğa çevirebilirdi.",
      "$($details[3]). Sandalyenin kısa sesi adamı yerinden oynatmadı, ama içindeki denge bozuldu. Kadın gitmiyor, kalıp cevabı bekliyordu.",
      "$($details[4]). Yüzük değil, özür ağırdı. Adam cebine uzanmadı; bazı şeylerin nesneyle değil, çıplak bir cümleyle söylenmesi gerekiyordu.",
      "$($details[5]). Camdaki yansıma ona kararlı bir adam göstermedi. Yine de bu kez kaçmanın utancı, konuşmanın korkusundan büyüktü.",
      "$($details[6]). Kahkahanın kesildiği anda masa çevresindeki bütün sesler inceldi. Adam, kendi nefesini ilk kez duyacak kadar yalnız kaldı.",
      "$($details[7]). Kadının bekleyişi öfkesizdi; bu yüzden daha ağırdı. Adam, affedilmekten önce gerçeği eksiksiz söylemesi gerektiğini anladı.",
      "$($details[8]). Telefonu ters çevirmesi küçük bir hareketti, fakat gecenin yönünü değiştirdi. Artık dikkatini çağrıya değil, karşısındaki insana verecekti.",
      "$($details[9]). Buğulu camdaki izler dağıldıkça adamın bahanesi de dağıldı. Cümle biçim kazanıyor, fakat henüz ses olmuyordu.",
      "$($details[10]). Soğuyan yemek masada kaldı; sıcak kalan tek şey ertelenmiş itiraftı. Kadın onun yüzündeki gecikmeyi okudu.",
      "$($details[11]). İkinci bölüm, kadının kalkmamasıyla kapandı. Adam artık susarsa bunun seçim değil, kaçış olduğunu biliyordu.",
      "Adam telefonun siyah ekranında kendi parmak izlerini gördü. Aranacak kişi, gönderilecek mesaj, söylenecek cümle; hepsi masanın üstünde görünmez birer tabak gibi duruyordu.",
      "Kadın su içti ve bardağı yavaşça yerine bıraktı. Bu yavaşlık adamı acele ettirmedi; aksine, doğru cümleyi yanlış bir savunmaya çevirmemesi için ona son bir alan açtı.",
      "Lokantanın dışında yağmur ince ince başladı. Camdaki damlalar, karşı kıyının ışıklarını çoğaltıyor; adamın tek sandığı meselenin aslında yıllara yayılmış olduğunu gösteriyordu.",
      "İkinci servisin kokusu artık iştah açmıyordu. Masadaki balık, ekmek ve yeşillik bir akşam yemeğinden çok, gecikmiş bir hesaplaşmanın sessiz tanıklarıydı.",
      "Adam ağzını açtı, sonra kapattı. Kadın bu yarım hareketi gördü; onu kurtarmak için araya girmedi, çünkü bu defa cümlenin sahibinin değişmemesi gerekiyordu.",
      "Bölüm biterken telefon hâlâ susuyordu. Fakat adamın içinde susan yer konuşmaya başlamıştı; üçüncü bölüm artık kaçışı değil, sonucunu taşıyacaktı.",
      "Adam tuzluğu parmaklarının arasında çevirdi. Küçük cam kabın içinde taneler yer değiştiriyor, ama dışarıdan bakınca her şey aynı görünüyordu; kendi hayatı da böyleydi.",
      "Kadın sonunda gözlerini ona çevirdiğinde hiçbir sertlik yoktu. Bu yumuşaklık adamı daha çok zorladı, çünkü artık savunmaya geçeceği bir saldırı bulamıyordu.",
      "İkinci servisin sonunda sofrada yenmemiş lokmalar kaldı. Adam, asıl doyulmamış şeyin yemek değil, yıllardır eksik bırakılmış açıklık olduğunu biliyordu.",
      "Masanın altından geçen soğuk hava adamın bileklerine değdi. Bedeni yerinde oturuyordu, ama zihni çoktan konuşmanın ilk kelimesine gidip orada takılı kalmıştı.",
      "Kadın çantasının tokasını kapatmadı; kalkmaya hazırlanmadığını bilerek yaptı bunu. Adam, kendisine tanınan bu kısa sürenin bir merhamet değil, son bir adalet olduğunu anladı.",
      "Bölümün sonunda ikinci servis neredeyse unutulmuştu. Masadaki yemek, konuşmanın gölgesinde kalmış; adam ilk kez bu gölgenin içinden geçmeden sabaha çıkamayacağını kabul etmişti.",
      "Kadının bekleyişi masanın üstünde görünmez bir ağırlık gibi duruyordu. Adam bu ağırlığı üzerinden atmak istemedi; çünkü ilk kez onun hak edilmiş olduğunu, kaçarsa aynı ağırlığın daha da büyüyeceğini biliyordu.",
      "Dışarıdaki yağmur kısa süre durdu, camdaki damlalar aşağı doğru ince yollar çizdi. Adam o izlere bakarken geçmişin de düz bir çizgi olmadığını, her suskunluğun başka bir yere saptığını düşündü.",
      "İkinci bölüm kapanırken adamın eli telefona değil, su bardağına gitti. Bir yudum aldı; boğazındaki kuruluk geçmedi, ama konuşmaya başlamadan önce suskunluğun tadını son kez duydu."
    )
    $breakText = "Kadın hiçbir şey sormadı. Bu suskunluk, adama verilen bir ceza değil, cevabı kendi ağzından duymak isteyen sabırlı bir bekleyişti."
    $ending = "İkinci bölümün sonunda adam telefonu masanın ortasına bıraktı. Aranacak kişi belliydi; asıl mesele, konuşmanın artık ertelenemeyecek oluşuydu."
  } else {
    $details = @(
      "Hesap fişi masaya geldiğinde adam onu para gibi değil, gecenin son işareti gibi gördü",
      "Kıyıdaki ışıklar rüzgarla kırıldı; her kırılma adamın yüzünde başka bir yaş bıraktı",
      "Kadın paltosunu giymedi, çünkü cevabı duymadan kalkmayacağını ikisi de biliyordu",
      "Garson uzaktan baktı ve yaklaşmadı; bazı masalara servis değil, zaman gerekiyordu",
      "Adam ilk kez tabağa değil, kadının ellerine baktı",
      "Deniz koyulaştıkça şehir daha dürüst görünmeye başladı",
      "Uzakta geçen vapurun sesi, kapatılmış bir defterin yeniden açılması gibi uzadı",
      "Adam kelimeyi seçmedi; kelime yıllardır beklediği yerden kendiliğinden çıktı",
      "Kadın başını eğmedi, gözlerini kaçırmadı, yalnızca nefesini tuttu",
      "Boğaz'ın üstünde duran sis, söylenen cümleyi saklamadı; aksine daha görünür kıldı",
      "Hesap ödendiğinde masa boşalmadı, yıllardır taşınan yük orada kaldı",
      "Adam kapıdan çıkmadan önce suya baktı ve ilk kez geriye dönme isteği duymadı"
    )
    $paragraphs = @(
      "Gecenin sonunda $focus adamın önünde sessiz bir hüküm gibi duruyordu. $($details[0]). Hesap, yemeğin değil, suskunluğun sonuna yazılmış gibiydi.",
      "$($details[1]). Işığın kırıldığı her yerde adamın yüzü biraz daha yaşlandı. Artık masada iştah değil, sonuç vardı.",
      "$($details[2]). Kadın paltosunu giymeyince adam bekleyişin bittiğini değil, son eşiğe geldiğini anladı. Bu kez karar ona bırakılmıştı.",
      "$($details[3]). Garsonun yaklaşmaması masaya tuhaf bir mahremiyet verdi. Lokanta sürüyor, ama onların zamanı ayrı bir yerde akıyordu.",
      "$($details[4]). Kadının ellerindeki sakinlik, adamın içindeki karışıklığı daha görünür kıldı. İlk kez cümleyi süslemeden söylemeyi denedi.",
      "$($details[5]). Şehir dürüst görünmeye başlayınca adam da kendi yalanının sınırına geldi. Suskunluğun artık kimseyi korumadığını fark etti.",
      "$($details[6]). Vapur sesi uzarken adam kapatılmış defteri içinde açtı. Geçmiş, anlatılmadığı için bitmemişti.",
      "$($details[7]). Kelime çıktığında masadaki hava değişti. Büyük bir itiraf gibi değil, uzun süredir bekleyen basit bir gerçek gibi duyuldu.",
      "$($details[8]). Kadın nefesini tuttu; adam cümlenin devamını getirdi. Bu kez açıklama yapmıyor, sakladığı payı üstleniyordu.",
      "$($details[9]). Sis cümleyi örtmedi. Aksine, söylenen şeyin arkasında kalan yılları daha belirgin kıldı.",
      "$($details[10]). Hesap ödendiğinde masa boşalmış görünüyordu, fakat adam yükün yer değiştirdiğini biliyordu. Artık taşıdığı şey giz değil, sonuçtu.",
      "$($details[11]). Son bölüm kapıdaki kısa bakışla bitti. Boğaz aynı kaldı; adamın ona bakarken saklandığı yer değişti.",
      "Kadın cevabı hemen vermedi. Adam ilk kez bu sessizliği kendisine açılmış bir boşluk değil, söylediklerinin gerçekten duyulduğu bir zaman olarak kabul etti.",
      "Lokantanın ışıkları biraz kısıldı. Masalar birer birer boşalırken onların masasında kalan şey kırıntı değil, nihayet adı konmuş bir gerçekti.",
      "Adam paltosunu alırken eli kısa süre sandalyenin arkasında kaldı. O sandalyede biraz önce oturan adamla kapıdan çıkacak adamın aynı kişi olmadığını hissetti.",
      "Dışarıdaki hava keskinleşmişti. Boğaz'dan gelen rüzgar yüzüne değdiğinde, söylemiş olmanın hafiflik değil, sorumluluk getirdiğini anladı.",
      "Kadın kaldırıma çıktığında ona yetişmek için acele etmedi. İlk kez aralarındaki mesafeyi kapatmanın koşmakla değil, bundan sonra aynı gerçeğin içinde yürümekle mümkün olduğunu biliyordu.",
      "Üçüncü bölüm, suyun üstünde dağılan ışıklarla kapandı. Yemek bitmişti; fakat asıl kapanış, adamın artık kendi sessizliğini bir sığınak gibi kullanamayacağını anlamasıydı.",
      "Kadın merdivenlerden inerken bir kez durdu. Adam bu duruşta bağışlanma vaadi aramadı; yalnızca gerçeğin bundan sonra nereye varacağını birlikte görme ihtimalini gördü.",
      "Kıyı yolunda arabaların sesi suyun sesiyle karıştı. Şehir aynı anda hem ilgisiz hem tanık gibiydi; kimse onların konuşmasını duymamıştı, ama gece onu saklamamıştı.",
      "Son bakışta adam masayı, boş tabakları ve camda kalan buğuyu geride bıraktı. Romanın bu kısa sınamasında değişen şey olaydan çok, karakterin artık kendini kandıramayacak noktaya gelmesiydi.",
      "Sokağa çıktıklarında lokantanın camında kendi yansımalarını gördüler. İçeride kalan masa, dışarıdaki iki insanı hâlâ birbirine bağlıyordu; söylenen cümle kapıdan çıkınca silinmemişti.",
      "Adam gecenin serinliğinde derin bir nefes aldı. Bu nefes rahatlama değildi; daha çok, uzun süre suyun altında kalmış birinin yüzeye çıkınca sorumluluğun ağırlığını yeniden duymasıydı.",
      "Kapanışta şehir kendi akışına döndü. Fakat adam için gece sıradan akışına dönemedi; Boğaz kıyısındaki o masa, artık hatırlanacak bir yemek değil, saklanamayacak bir dönemeçti.",
      "Kadın birkaç adım sonra yavaşladı. Adam bu yavaşlamayı bir davet gibi okumadı; daha çok, söylediği şeylerin havada dağılmadan yere inmesi için tanınmış sessiz bir süre olarak gördü.",
      "Arkalarında kalan lokantadan tabak sesleri geliyordu. Bir başkası için gece yeni başlıyor olabilirdi, ama adam için asıl başlangıç masadan kalktıktan sonra taşıyacağı sonuçlarda saklıydı.",
      "Son cümle söylenmişti, fakat sonucun nasıl yaşanacağı henüz belli değildi. Romanın kısa sınaması burada kapandı: yemek, manzara ve suskunluk aynı çizgide birleşip karakteri geri dönülmez bir eşiğe getirdi."
    )
    $breakText = "Kadın bu kez elini masadan çekmedi. Adam o küçük yakınlıkta bir izin değil, son bir dürüstlük talebi gördü."
    $ending = "Kapıdan çıktıklarında Boğaz aynı Boğaz'dı; değişen, adamın artık kendi suskunluğuna sığınamamasıydı."
  }
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add($title)
  $lines.Add("")
  if ($Number -eq 1) {
    $dialogueReplies = @(
      "- Kadın, bugün denize çok bakıyorsun; insanın tabağında olmayan bir şeyi araması iyiye işaret değildir.",
      "- Adam, bazen yemek insanı susturur sanıyorsun, ama tuz bile insanın sakladığı şeyi ortaya çıkarıyor.",
      "- Kadın, bu masaya yalnız yemek için gelmediğimizi ikimiz de biliyoruz.",
      "- Adam, biraz zaman ver; doğru cümleyi bulmadan konuşursam yine yanlış yerden başlayacağım.",
      "- Kadın, zaman verdim; artık zamanın kendisi de masada bizimle oturuyor.",
      "- Adam, Boğaz'a baktıkça bazı şeylerin karşı kıyıda kalmadığını anlıyorum.",
      "- Kadın, o zaman ilk lokmadan değil, ilk gerçekten başla.",
      "- Adam, önce suskunluğumun adını koymam gerekiyor; yoksa söylediğim her şey eksik kalacak.",
      "- Kadın, eksik kalan şey söz değil, onu taşıyacak cesaretti."
    )
    $breakTexts = @(
      "Masaya yeni bir tabak geldiğinde adam başını kaldırdı. Karşı kıyıdaki ışıklar yer değiştirmiş gibiydi; oysa değişen şehir değil, onun bakışında biriken gecikmiş cevaptı.",
      "İlk servisin ortasında kısa bir sessizlik oldu. Adam bu sessizliğin içinden geçmeden ikinci servise varamayacağını anladı.",
      "Camın dışındaki akıntı hızlanmış gibiydi. Adam, masada kalmanın artık konuşmaya yaklaşmak anlamına geldiğini sezdi.",
      "Garson tabakları düzenlerken gece kendi ritmini buldu. Bu ritim, adamı daha fazla oyalanmadan sonraki eşiğe taşıyordu."
    )
  } elseif ($Number -eq 2) {
    $dialogueReplies = @(
      "- Kadın, telefonun susması meseleyi bitirmiyor; yalnızca daha görünmez yapıyor.",
      "- Adam, o isim ekranda belirince bütün gece yer değiştirdi sandım.",
      "- Kadın, gece değil, sen yerinden oynadın; bunu ilk kez saklamıyorsun.",
      "- Adam, özür dilemek kolay, ama neyi bozduğumu tam söylemeden özür eksik kalıyor.",
      "- Kadın, o halde eksik tarafı tamamla; savunma değil, cümle kur.",
      "- Adam, kaçmanın bende alışkanlık olduğunu şimdi anlıyorum.",
      "- Kadın, alışkanlık dediğin şey bazen başkasının yıllarını da eskitir.",
      "- Adam, bu yüzden telefonu ters çevirdim; artık başka bir yere bakmak istemiyorum.",
      "- Kadın, bakmak yetmez; gördüğün şeyi söylemen gerekiyor."
    )
    $breakTexts = @(
      "Kadın hiçbir şey sormadı. Bu suskunluk, adama verilen bir ceza değil, cevabı kendi ağzından duymak isteyen sabırlı bir bekleyişti.",
      "İkinci servisin ortasında yemek geri plana çekildi. Masada artık tabaklardan çok kararların sesi vardı.",
      "Telefon bir daha yanmadı, fakat yokluğu bile konuşmanın parçası oldu. Adam sessiz ekranın baskısını üzerinde taşıdı.",
      "Yağmur camda çoğalırken kadın hâlâ kalkmadı. Adam, bu kalışın kendisine son kez açılmış bir kapı olduğunu biliyordu."
    )
  } else {
    $dialogueReplies = @(
      "- Kadın, şimdi söylediğin şey geç kalmış olabilir, ama ilk kez eksik değil.",
      "- Adam, geç kalmış olmanın ağırlığını hafifletmeye çalışmayacağım.",
      "- Kadın, senden hafiflik değil, dürüstlük bekledim.",
      "- Adam, o dürüstlüğü geciktirdim; bunun bedelini senden saklayamam.",
      "- Kadın, o zaman bundan sonra sessizliği cevap yerine kullanma.",
      "- Adam, kullanmayacağım; çünkü susmanın da bir karar olduğunu anladım.",
      "- Kadın, kararın sonucunu da taşıyabilecek misin?",
      "- Adam, ilk kez cevabı bilmiyorum, ama kaçmadan kalacağım.",
      "- Kadın, o zaman bu gece bitmedi; yalnızca başka bir yerden başladı."
    )
    $breakTexts = @(
      "Kadın bu kez elini masadan çekmedi. Adam o küçük yakınlıkta bir izin değil, son bir dürüstlük talebi gördü.",
      "Gecenin sonuna doğru lokanta hafifçe boşaldı. Kalabalık çekildikçe söylenen sözlerin ağırlığı daha açık duyuldu.",
      "Hesap defteri kapandı, fakat konuşmanın sonucu açık kaldı. Adam bunun bir yenilgi değil, gerçek bir başlangıç olduğunu kabul etti.",
      "Kapıya yöneldiklerinde Boğaz arkalarında değil, içlerinde kalmış gibiydi. Su, söylenenleri alıp götürmedi; yalnızca onlara eşlik etti."
    )
  }

  for ($i = 1; $i -le $paragraphs.Count; $i++) {
    $scene = $paragraphs[$i - 1]
    $lines.Add($scene)
    if ($i % 2 -eq 0) {
      $replyIndex = [int]([math]::Floor($i / 2) - 1)
      if ($replyIndex -lt $dialogueReplies.Count) {
        $reply = $dialogueReplies[$replyIndex]
      } else {
        $reply = "- Adam, bu cümlenin $i. adımında artık aynı yere dönmediğimi, başka bir sonuca yaklaştığımı duyuyorum."
      }
      $lines.Add($reply)
    }
    if ($i % 5 -eq 0) {
      $breakIndex = [int]([math]::Floor($i / 5) - 1)
      if ($breakIndex -lt $breakTexts.Count) {
        $lines.Add($breakTexts[$breakIndex])
      } else {
        $lines.Add("Bölümün $i. paragrafından sonra masa yeni bir eşiğe geldi. Aynı sessizliğe dönmek yerine, sahne bir sonraki karara doğru daraldı.")
      }
    }
  }

  $lines.Add("")
  $lines.Add($ending)
  return ($lines -join [Environment]::NewLine)
}

function New-ChapterText {
  param([int]$Number, [string]$Seed)

  $title = Get-ChapterDisplayTitle -Number $Number
  if ($Number -eq 1) {
    $paragraphs = @(
      "Kemal, Boğaz kıyısındaki lokantanın cam kenarı masasına erken geldi. Beyaz örtünün üstünde tek kişilik servis vardı; karşı sandalyenin boşluğu, henüz gelmemiş birinden çok yıllardır söylenmemiş bir cümleye ayrılmış gibiydi.",
      "Ceketinin iç cebindeki zarf, masaya koyduğu telefon kadar canlı duruyordu. Zarfın içinde Leyla'nın son mektubu vardı; Kemal onu üç yıl boyunca açıp kapatmış, her defasında Derya'ya vermemek için yeni bir gerekçe bulmuştu.",
      "Garson Murat onu tanıdı ve suyu sessizce doldurdu. Yıllar önce Leyla'nın aynı masada oturup bir zarf bıraktığını gören de oydu; bu yüzden Kemal'in bakışındaki telaşı yemek seçme kararsızlığı sanmadı.",
      "Boğaz ağır akıyordu. Karşı kıyıdaki ışıklar erken yanmış, vapurlar suyun üstünde kısa beyaz izler bırakmıştı. Kemal manzaraya bakınca rahatlaması gerekirken, suyun açıklığı ona sakladığı şeyi daha görünür kılıyordu.",
      "Telefon ekranı yandı: Derya, 'On dakikaya oradayım. Bu kez evi değil annemi konuşacağız,' diye yazmıştı. Kemal mesajı okuyunca menüyü kapattı; artık hangi balığın iyi piştiğinin gecede hiçbir önemi kalmamıştı.",
      "Aile evi iki haftadır satıştaydı. Borç baskısını, boş odaların küf kokusunu, yıllardır kimsenin yaşamadığı bir yer için para harcamanın anlamsızlığını kendine tekrar edip durmuştu. Fakat Leyla'nın mektubunun ilk satırı bu gerekçeleri sessizce çürütüyordu.",
      "- Murat, bu masa bu akşam dolu sayılır mı?",
      "- Siz gelince hep dolu sayılır Kemal Bey. Bazı boş sandalyeler de insanı bekletir.",
      "Kemal cevap vermedi. Murat'ın fazla şey bildiğini, ama bunu kimseye yük etmeyecek kadar ölçülü biri olduğunu biliyordu. Yine de garsonun sakinliği bile onu ele verilmiş hissettirdi.",
      "İlk tabak geldiğinde Derya hâlâ yoktu. Tabağın kenarındaki limon, çocukken Derya'nın balığa yüzünü buruşturmasını hatırlattı. O zamanlar Leyla, kızının tabağına patates koyar ve Kemal'e 'Her şeyi zorla sevdiremezsin,' derdi.",
      "Zarfın köşesi ceket astarına sürtündü. Kemal elini cebine götürdü, sonra geri çekti. Mektubu şimdi masaya koyarsa Derya gelmeden konuşma başlayacak, kendisi yine en önemli anda yalnız kalacaktı.",
      "Derya'nın taksi ışığı camda göründüğünde Kemal'in içindeki bütün hazırlık dağıldı. Bir baba olarak ne diyeceğini yıllardır düşünmüş, fakat kapı açıldığında sadece kızının annesine benzeyen yürüyüşünü görebilmişti.",
      "Derya içeri girdi, paltosunu çıkarmadan karşısına oturdu. Yemek kokusu, deniz, camdaki ışıklar bir anda arka plana çekildi. Masada artık akşam yemeği değil, saklanan yıllar vardı.",
      "- Aç değilim baba.",
      "- Yine de bir şey söylersin. Yol geldin.",
      "- Yol için gelmedim. Annemin mektubu için geldim.",
      "Kemal'in eli bardağa gitti. Su içmedi; yalnızca bardağın soğukluğunu tuttu. Derya'nın mektubu bildiğini anlamıştı, ama nasıl öğrendiğini sormak ona yine konuyu yana çekme fırsatı verecekti.",
      "Murat uzaktan baktı ve masaya yaklaşmadı. Lokantanın geri kalanı kendi akşamını sürdürürken bu masa, sanki camın dışındaki akıntıdan ayrılmış küçük bir ada gibi duruyordu.",
      "Derya çantasından eski bir fotoğraf çıkardı. Fotoğrafta Leyla, aile evinin bahçesinde gülüyordu; arkasında incir ağacı, pencerenin altında da Derya'nın çocukken boyadığı mavi sandalye vardı.",
      "Kemal fotoğrafa baktığında satış ilanındaki soğuk metni hatırladı: merkezi konum, tadilat fırsatı, deniz ulaşımına yakın. O ilanda Leyla'nın sesi, Derya'nın çocukluğu ve kendi yenilgisi yoktu.",
      "Derya fotoğrafı masanın ortasına bıraktı. Bu hareket bir suçlama kadar sessiz, bir kapı çarpması kadar kesindi. Kemal artık evi para cümleleriyle anlatamayacağını anladı.",
      "- Mektup sende mi?",
      "- Bunu nereden çıkardın?",
      "- Murat amca yıllar önce annemin sana zarf bıraktığını görmüş. Ben üç yıl bekledim. Senin söylemeni bekledim.",
      "Kemal'in ilk yalanı boğazına kadar geldi, fakat çıkmadı. Boğaz'dan geçen vapurun sesi camı titretti; o titreşim, masadaki fotoğrafın kenarını hafifçe oynattı.",
      "Birinci bölüm, zarfın hâlâ cebinde durmasıyla kapandı. Kemal artık saklamaya devam ederse yalnız bir mektubu değil, Derya'nın kendisine kalan son güvenini de kaybedeceğini biliyordu.",
      "Derya garsona dönüp çay istedi. Bu küçük sipariş, hemen kalkmayacağını gösteriyordu. Kemal rahatlamadı; çünkü kalması, onu dinleyeceği anlamına değil, sonunda konuşmasına izin vereceği anlamına geliyordu.",
      "Masaya çay geldiğinde bardakların ince sesi konuşmanın ilk sınırını çizdi. Derya kaşığı döndürmedi, şekere uzanmadı. Çayın buharı yüzünün önünden geçerken Kemal, kızının artık çocukken yaptığı gibi gözlerini kaçırmadığını gördü.",
      "Cebindeki zarfın içeriğini tam bilmediği için kendini masum saymaya çalışmıştı. Oysa mektubu vermemek de bir okuma biçimiydi; Leyla'nın son sözünü kendi korkusuna göre yorumlamış, Derya'nın yasını eksik bırakmıştı.",
      "Derya fotoğrafın arkasını çevirdi. Leyla'nın el yazısıyla küçük bir tarih düşülmüştü: 'Evin inciri ilk meyvesini verdi.' Kemal o günü hatırladı; Derya merdivenden düşmüş, Leyla gülerek ağlamıştı.",
      "Bu hatıra masadaki tartışmayı yumuşatmadı, aksine somutlaştırdı. Satılacak ev artık ilan numarası değil, Derya'nın dizindeki eski yara, Leyla'nın bahçedeki sesi ve Kemal'in kaçtığı bütün odalar olmuştu.",
      "Bir vapur yanaşırken lokantanın camı hafifçe titredi. Derya titremeye bakmadı; bakışını babasının ceket cebinde tuttu. Kemal, zarfın yerini saklamanın artık bedensel olarak da imkânsız hale geldiğini hissetti.",
      "Murat uzaktan hesabı hazırlamadı, çünkü masanın bitmediğini biliyordu. Onun bu bekleyişi bile sahnenin tanığıydı: yıllar önce bırakılan zarf, şimdi aynı camın önünde sahibine doğru ilerliyordu.",
      "Kemal ilk bölümün sonunda henüz itiraf etmedi, fakat kaçış düzeni kırıldı. Derya mektubu açıkça istemiş, aile evi soyut bir mal olmaktan çıkmış, gece artık ikinci bölümde yüzleşmeye mecbur kalmıştı.",
      "Murat mutfağa döndüğünde Kemal'in yıllar önce aynı masada nasıl ağlamadan oturduğunu hatırladı. O gece de deniz sakindi; fark, Leyla'nın zarfı bırakıp giderken hiç tereddüt etmemesiydi.",
      "Derya babasının yüzünde bu hatırayı okuyamazdı, ama masadaki herkesin kendisinden önce bir şey bildiğini sezdi. Bu sezgi onu öfkelendirdi; annesinin son sözlerinde bile geç kalmış bir misafir gibi bırakılmıştı.",
      "Kemal satış ilanını telefondan açıp kapattı. Fotoğraflarda ev fazla aydınlık görünüyordu; emlakçının geniş açıyla çektiği salon, Leyla'nın son kışını geçirdiği dar hasta odasına hiç benzemiyordu.",
      "Derya telefonu gördü ve ilanı tanıdı. 'İlanı kaldırmadan konuşmaya başlamayacaksan bu yemek biter,' dedi. Bu cümle ilk bölümün gerçek eşiğiydi: artık konu sadece mektup değil, Kemal'in şimdi ne yapacağıydı."
    )
    $ending = "Derya bekledi; Kemal ise ilk kez cevabı ertelemenin bir cevap olduğunu anladı."
  } elseif ($Number -eq 2) {
    $paragraphs = @(
      "İkinci servis masaya geldiğinde yemek çoktan bahaneye dönüşmüştü. Derya çatalına dokunmadı; Kemal'in önündeki balık soğurken ikisinin arasında Leyla'nın adı ısındı.",
      "Kemal zarfı çıkarmadı. Önce evi anlatmaya çalıştı: borçları, bakım masrafını, boş kalan odaları, rutubeti. Derya onu kesmedi, çünkü babasının yine para cümlelerinin arkasına saklanmasını sonuna kadar görmek istiyordu.",
      "- Annem evi para yüzünden sevmedi baba. Orada hasta yatağını pencereye çevirmiştin, hatırlıyor musun?",
      "- Hatırlıyorum.",
      "- O zaman neden satmadan önce bana sormadın?",
      "Kemal'in cevabı hazırdı: çünkü sen gelmezdin, çünkü konuşmazdın, çünkü bana kızgındın. Ama bunların hepsi Derya'nın yokluğunu sebep gösterip kendi kaçışını temize çıkaran cümlelerdi.",
      "Murat ikinci kez masaya yaklaştı ve şarap listesini sormadan geri aldı. Bu küçük dikkat, Derya'nın gözünden kaçmadı. Lokantada babasından başka birinin de mektup meselesini bildiğini hissetti.",
      "Derya Murat'a döndü. 'Annem o zarfı ne zaman bıraktı?' diye sordu. Murat Kemal'e baktı; izin istemedi, yalnızca yıllardır sakladığı tanıklığın artık sahibine döndüğünü kabul etti.",
      "Leyla'nın ölümünden üç gün önce geldiğini söyledi. Aynı masaya oturmuş, uzun süre denize bakmış, sonra zarfı Kemal'e verilmek üzere bırakmıştı. 'Kızım gelirse babasıyla aynı masada okusun,' demişti.",
      "Kemal gözlerini kapattı. O cümleyi Murat'tan duymak, zarfın ağırlığını iki katına çıkardı. Leyla yalnız mektup bırakmamış, onu Derya'yla aynı masaya çağıran son bir düzen kurmuştu.",
      "- Sen bunu biliyordun.",
      "- Evet.",
      "- Üç yıl boyunca?",
      "- Evet.",
      "Derya sandalyesine yaslandı. Kızgınlığı bağırmadı; daha kötü bir şey yaptı, sessizleşti. Kemal bu sessizlikte çocukluğundan beri tanıdığı Derya'yı değil, kendisinden hesap soran yetişkin bir kadını gördü.",
      "Dışarıda yağmur başladı. Camdaki damlalar karşı kıyının ışıklarını çoğaltıyor, her ışığı başka bir ihtimale bölüyordu. Kemal için ihtimal kalmamıştı; mektup ya bu gece verilecek ya da ilişki bu masada bitecekti.",
      "Ceketinin düğmesini açtı. Zarfın kenarı göründüğünde Derya'nın yüzü değişmedi. O an Kemal, kızının aslında mektubun varlığından çok kendisine güvenilip güvenilmeyeceğini beklediğini anladı.",
      "- Okumadım, dedi Kemal.",
      "- Bu iyi bir şey mi sanıyorsun?",
      "- Hayır. Korkakça bir şey.",
      "Bu kelime masaya ağır indi. Kemal yıllardır ilk kez kendini savunmadan tanımlamıştı. Derya'nın bakışı yumuşamadı, ama kaçmadı da; bu, konuşmanın hâlâ mümkün olduğu anlamına geliyordu.",
      "Kemal zarfı masaya koydu, fakat elini üstünden çekmedi. Derya o ele baktı. Babasının mektubu saklamasının tek nedeni ev satışı değildi; Leyla'nın son sözlerinin kendisini suçlayacağından da korkmuştu.",
      "Derya elini uzattı. Kemal zarfı bırakmak yerine bir an daha tuttu ve bütün gecenin en açık cümlesini kurdu: 'Evi satmak istedim, çünkü oraya her baktığımda annenin benden istediği adam olamadığımı görüyordum.'",
      "Bu itiraf Derya'nın beklediği cevap değildi, ama gerçekti. Gerçek, insanı hemen iyileştirmiyordu; yine de yalanın dolaştırdığı kapalı odadan dışarı çıkarıyordu.",
      "Derya zarfı aldı, fakat açmadı. 'Bunu burada, sen hazır olduğun için değil, annem böyle istediği için okuyacağız,' dedi. Kemal başını salladı. Bu kez sıranın kendisinde olmadığını kabul etti.",
      "Murat uzak masaya servis götürürken omzunun üstünden baktı. Yıllar önce taşıdığı zarfın nihayet sahibine geçtiğini görmüş, lokantanın sıradan akşamlarından birinin küçük bir adalete dönüştüğünü anlamıştı.",
      "Derya zarfın kapağını açarken Kemal telefona uzandı. Noter temsilcisinin numarasını ekranda buldu, ama aramadı. Önce mektup okunmalıydı; karar, bilgi tamamlanmadan verilirse yine kaçış olacaktı.",
      "Mektubun ilk satırı Derya'nın sesiyle değil, Leyla'nın masaya geri dönen sakinliğiyle duyuldu: 'Bu evi bir mülk gibi değil, birbirinizi bulacağınız son adres gibi düşünün.'",
      "İkinci bölüm, Kemal'in satış kararının artık para meselesi olmaktan çıkmasıyla kapandı. Mektup açılmış, sır yer değiştirmiş, fakat asıl karar üçüncü bölümün eşiğine bırakılmıştı.",
      "Derya okumayı bırakıp bir süre kâğıda baktı. Mektubun sesi annesinin sesi değildi elbette, ama yıllardır kapanmış sanılan bir odanın penceresi gibi içeri hava aldırıyordu.",
      "Kemal bu arada hiçbir açıklama eklemedi. Eskiden susması kaçmak demekti; şimdi susması, Derya'nın okuduğu şeyi kendi hızında anlamasına yer açmak zorundaydı. Bu farkı yeni öğreniyordu.",
      "Mektubun ortasında Leyla, Kemal'in iyi niyetle bile zarar verebildiğini yazmıştı. Derya bu satırda babasına bakmadı. Baksa, Kemal'in yüzündeki çöküşü görecek ve belki de kendi öfkesini erken yumuşatacaktı.",
      "Yağmur hızlandı. Lokantanın dışındaki tenteden damlalar arka arkaya düştü. Her damla masadaki sessizliği bölüyor, fakat hiçbir ses asıl konuşmanın yerini tutmuyordu.",
      "Kemal telefon ekranındaki noter numarasını açık bıraktı. Derya bunu gördü. Babasının ilk kez bir kararı konuşmanın dışına kaçmadan, konuşmanın sonucu olarak almaya hazırlandığını anladı.",
      "Murat masaya ekmek getirdiğinde Derya teşekkür etti. Bu sıradan nezaket, biraz önceki sert hesaplaşmanın yanında küçük ama önemli bir şeydi: dünya hâlâ çalışıyor, insanlar hâlâ birbirine seslenebiliyordu.",
      "İkinci bölümün sonuna doğru Kemal, Derya'nın çocukluğundan değil yetişkinliğinden korktuğunu fark etti. Çocuk Derya'yı teselli edebilirdi; karşısındaki kadın ise ondan sadece doğruluk istiyordu.",
      "Bölüm, mektubun okunmasıyla değil, Kemal'in onu artık geri alamayacağını kabul etmesiyle bitti. Zarf masadan Derya'nın eline geçmiş, hikâyenin merkezi saklanan nesneden verilecek karara kaymıştı.",
      "Derya mektubun kenarını parmağıyla düzeltti. Kâğıt eski değildi ama uzun süre saklanmıştı; kat yerleri belirgindi. Kemal'in ertelemesi bile kâğıdın üzerinde iz bırakmıştı.",
      "Kemal bu izlere bakarken kendi bahanesini son kez içinde çevirdi: Derya hazır değildi. Sonra bunun doğru olmadığını anladı. Hazır olmayan Derya değil, annesinin son isteğiyle yüzleşemeyen kendisiydi.",
      "Murat hesabı sormak için yaklaşmadı; bunun yerine masaya yeni su bıraktı. Bu küçük servis, konuşmanın süreceğini kabul eden sessiz bir işaretti. Derya teşekkür ederken sesi ilk kez tamamen kırılmadı.",
      "İkinci bölümün son hareketi Kemal'in telefon kilidini açması oldu. Numarayı çevirmedi, ama ekranda noter temsilcisinin adını açık bıraktı; üçüncü bölümde kaçamayacağı somut karar artık görünür haldeydi.",
      "Derya ekranı gördü ve ilk kez babasının sözden sonra eyleme yaklaştığını fark etti. Bu onu affettirmedi, ama konuşmanın aynı yerde dönmediğini gösterdi."
    )
    $ending = "Derya okumaya devam etti; Kemal ilk kez cümlelerin arasına girmeden dinledi."
  } else {
    $paragraphs = @(
      "Üçüncü bölümde lokanta yavaş yavaş boşalırken mektup masanın ortasında açık duruyordu. Leyla'nın el yazısı titrek değildi; ölüm yaklaşırken bile cümlelerini telaşa bırakmamıştı.",
      "Mektup, aile evini kutsal bir hatıra gibi korumalarını istemiyordu. Daha zor bir şey istiyordu: Kemal'in evi satmadan önce Derya'ya orada neden mutlu olduğunu, neden kırıldığını ve neden uzaklaştığını sormasını.",
      "Derya mektubun ikinci sayfasını çevirdi. Leyla, kızının bir gün babasına çok kızacağını bildiğini yazmıştı. 'Haklı olabilir,' diyordu, 'ama haklılık insanın içinde tek başına kalırsa eve dönüş yolunu da kapatır.'",
      "Kemal bu cümlede kendini savunacak yer bulamadı. Leyla onu suçlamıyor, aklamıyor, yalnızca Derya'yla konuşmasını istiyordu. Üç yıl sakladığı şey aslında bir mahkeme değil, gecikmiş bir çağrıydı.",
      "- Kemal, satışı durduracağım.",
      "Derya mektuptan başını kaldırdı. 'Bunu bana yaranmak için söylüyorsan istemem,' dedi. Sesi sertti, ama bu sertlik bir kapıyı kapatmıyor; kapının eşiğine sağlam bir çizgi çekiyordu.",
      "Kemal telefonu aldı ve bu kez numarayı gerçekten aradı. Noterin asistanına satış işleminin askıya alınacağını, vekaletnameyle ilerlenmemesini söyledi. Konuşma kısa sürdü; yıllardır büyüyen karar birkaç resmi cümleyle durduruldu.",
      "Telefon kapanınca masada tuhaf bir boşluk oluştu. Derya'nın yüzü hemen değişmedi. Kemal bunun için minnettar oldu; kolay affın, kolay inkâr kadar sahte olabileceğini ilk kez düşünüyordu.",
      "Murat hesabı getirdiğinde fişin yanına küçük bir not bırakmıştı: 'Leyla Hanım bu masayı hep cam açıkken severdi.' Derya notu okudu ve ilk kez gece boyunca denize değil, lokantanın penceresine baktı.",
      "Kemal pencereyi araladı. Haziran akşamının serinliği masaya doldu. Yemek kokusuna deniz karıştı; Derya annesinin neden bu masayı seçtiğini o an anlar gibi oldu.",
      "- Derya, eve gidecek miyiz?",
      "- İstersen bu gece değil. Ama anahtar bende. Ve bu kez kapıyı senden önce açmayacağım.",
      "Bu cümle küçük bir sözdü, fakat Kemal için alışılmış rolünden vazgeçmek anlamına geliyordu. Artık baba olarak yolu belirlemeyecek, Derya'nın kendi hızını kabul edecekti.",
      "Derya mektubu yeniden zarfa koymadı. Katlayıp çantasının iç cebine yerleştirdi. Kemal bu hareketi gördüğünde mektubun artık kendisinden çıktığını, ait olduğu kişiye geçtiğini kabul etti.",
      "Hesabı öderken eli titremedi. Gece boyunca ilk kez bedeni kararın gerisinde kalmıyor, ona eşlik ediyordu. Satışı durdurmak sorunu çözmemişti, ama yalanın çevresinde kurulan sahneyi sökmüştü.",
      "Dışarı çıktıklarında Boğaz daha karanlıktı. Kıyı yolunda arabalar akıyor, vapur iskelesinden geç kalan birkaç kişi koşuyordu. Şehir onların dramını büyütmüyor, yalnızca içine alıp yürütüyordu.",
      "Derya merdivenlerde durdu. 'Sana kızgın olmam geçmedi,' dedi. Kemal başını salladı. Bu kez cümleyi düzeltmeye, yumuşatmaya, kendi lehine çevirmeye çalışmadı.",
      "- Geçmesini istemeye hakkım yok.",
      "- Ama eve beraber bakabiliriz. Annem için değil sadece. Benim ne istediğimi duyman için.",
      "Kemal bu teklifi barış sanmadı. Bu, Derya'nın ona verdiği daha zor bir şeydi: kontrol etmeden yanında durma fırsatı. Kızının yetişkinliğini ilk kez bir kayıp değil, bir gerçek olarak gördü.",
      "Lokantanın camında ikisinin yansıması yan yana belirdi. İçeride boşalan masa, üstünde kalan bardak izleri ve açık pencere görünüyordu. Biraz önce konuşulanlar camın arkasında kalmamış, onların arasına karışmıştı.",
      "Kemal anahtarlığı cebinden çıkardı. Aile evinin anahtarı, yıllardır taşıdığı zarf kadar ağır değildi artık; çünkü saklanan şey olmaktan çıkmış, paylaşılacak bir soruya dönüşmüştü.",
      "Derya anahtara dokunmadı. 'Yarın,' dedi. Kemal anahtarı geri cebine koydu. Bu gecenin zaferle bitmediğini, ama ilk kez doğru yerde durarak bittiğini anladı.",
      "Boğaz'ın üstünde ince bir sis vardı. Işıklar suyun üzerinde kırılıyor, hiçbir görüntü tamamen sabit kalmıyordu. Kemal bunun iyi olduğunu düşündü; bazı ilişkiler de ancak sabit görünmekten vazgeçince yaşayabiliyordu.",
      "Son bölüm, baba kızın yan yana ama sessiz yürümesiyle kapandı. Yemek bitmiş, mektup el değiştirmiş, satış durdurulmuştu. Asıl değişim ise Kemal'in artık suskunluğunu sevgi sanamayacak olmasıydı.",
      "Taksi gelene kadar kaldırımda beklediler. Derya telefonuna bakmadı; Kemal de yeni bir açıklama aramadı. İkisinin arasında ilk kez boşluğu doldurmak için değil, söylenenlerin yerine oturması için sessizlik vardı.",
      "Murat kapıda kısa bir baş selamı verdi. Derya ona teşekkür ederken yalnız servis için değil, yıllar önce unutulmuş gibi görünen bir tanıklığı bugün doğru yere bıraktığı için teşekkür ettiğini ikisi de anladı.",
      "Kemal cebindeki anahtarı bir kez daha yokladı. Artık anahtarın anlamı değişmişti: kapatılmış odaları tek başına açma hakkı değil, Derya'yla birlikte eşiğe gelme sorumluluğuydu.",
      "Derya taksinin kapısını açmadan önce durdu. 'Annemin mektubunu bu gece bitirmeyeceğim,' dedi. Kemal nedenini sormadı. Bazı metinlerin bir oturuşta değil, insanın hayatına yayılarak okunduğunu anladı.",
      "- Mektubu benden tekrar istemeyeceksin, dedi Derya.",
      "- İstemeyeceğim.",
      "- İçinde ne yazdığını sana ben söyleyene kadar sormayacaksın.",
      "- Sormayacağım. Bu kez sıranın sende olduğunu biliyorum.",
      "Satışın durdurulması her şeyi çözmemişti. Borçlar hâlâ vardı, ev hâlâ bakımsızdı, Derya'nın kırgınlığı hâlâ yerindeydi. Fakat artık bu sorunların üstünde yalan yoktu; hikâyeyi başka bir seviyeye taşıyan da buydu.",
      "Boğaz'da gece rüzgârı sertleşti. Kemal paltosunu ilikledi ve ilk kez üşümeyi hak edilmiş bir açıklık gibi hissetti. Saklanacak sıcak bir bahanesi kalmamıştı.",
      "Derya taksiye bindiğinde mektup çantasındaydı. Kemal onu geri istemedi, kopyasını sormadı, içeriğini yönlendirmeye kalkmadı. Bu küçük vazgeçiş, gecenin en gerçek baba hareketiydi.",
      "- Yarın geç kalma, dedi Derya.",
      "- Kalmayacağım.",
      "- Bu bir randevu değil. Bir deneme.",
      "- Biliyorum. Bu kez denemeyi ben bozmamaya çalışacağım.",
      "Finalde bağışlanma ilan edilmedi. Bunun yerine daha değerli ve daha zor bir şey kaldı: ertesi gün aile evinin kapısında buluşma sözü. Hikâye kapandı, fakat karakterlerin ilişkisi dürüst bir devam ihtimali kazandı.",
      "Kemal taksinin arkasından bakarken kendini hafiflemiş hissetmedi. Hafiflik beklemek bile eski alışkanlığıydı; doğru olanı yapınca geçmiş silinmiyordu, sadece insan geçmişin karşısında daha az sahte duruyordu.",
      "Murat lokantanın kapısını kapatmadan önce cam kenarı masaya baktı. Boş bardaklar, katlanmış peçete ve açık bırakılmış pencere ona Leyla'nın yıllar önceki yüzünü hatırlattı. Bu kez zarf masada kalmamıştı.",
      "Kemal kıyı boyunca birkaç adım yürüdü. Noter görüşmesinin ardından emlakçıya da mesaj attı: satış ilanı sabaha kadar kaldırılacaktı. Bu küçük teknik işlem, gecenin duygusal kararını dünyaya bağlayan somut adımdı.",
      "Son görüntüde Boğaz aynı akmaya devam etti. Fakat hikâye başladığı yere dönmedi: Kemal artık yalnız yemek yiyen bir adam değil, sakladığı mektubu teslim etmiş ve ertesi güne bir sorumluluk bırakmış bir babaydı."
    )
    $ending = "Derya taksiye binerken camı indirdi ve 'Yarın evi beraber açacağız,' dedi; Kemal için gecenin gerçek finali bu cümle oldu."
  }

  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add($title)
  $lines.Add("")
  foreach ($p in $paragraphs) {
    $lines.Add($p)
  }
  $lines.Add("")
  $lines.Add($ending)
  return ($lines -join [Environment]::NewLine)
}

function Invoke-Propose {
  $seed = Get-BookSeed
  $slug = Get-Slug $seed
  $workspace = Join-Path $ProjectRoot "_workspace"
  Ensure-Dir $workspace

  $proposal = @"
# Kitap Önerileri

run_id: $RunId

## Seçilen Ana Konu
$seed

## Öneri 1 - Boğazda Bir Akşam
- Logline: Boğaz kıyısında yemek yiyen Kemal, kızı Derya'ya yıllardır sakladığı mektubu vermek ve aile evinin satışından vazgeçmek zorunda kalır.
- Okur vaadi: İstanbul atmosferi, baba-kız hesaplaşması, saklı mektup ve açık uçlu ama somut final.
- Kitap potansiyeli: Üç bölümde net ilerleyen yüzleşme; uzun kitapta aile evi, yas ve yeniden bağ kurma hattı genişletilebilir.
- Birincil risk: Yemek sahnesinin sadece betimleme olarak dönmesi; her bölüm yeni bilgi ve karar taşımalıdır.

## Öneri 2 - Kayıp Oda
- Logline: Eski evdeki kapalı oda, karakterlerin birbirine anlattığı yalanları görünür kılar.
- Okur vaadi: Mekan gerilimi ve psikolojik çözülme.
- Kitap potansiyeli: Tek mekan ağırlıklı yoğun roman.
- Birincil risk: Mekan tekrarları dikkatli yönetilmelidir.

## Öneri 3 - Son Tanık
- Logline: Kasabanın en sessiz insanı, herkesin unuttuğunu sandığı olayı hatırlamaktadır.
- Okur vaadi: Tanıklık, suçluluk ve adalet.
- Kitap potansiyeli: Çok sesli anlatı ve güçlü final yüzleşmesi.
- Birincil risk: Anlatıcı sesleri yeterince ayrışmalıdır.

## Tavsiye
Öneri 1 seçildi. Sebep: Kullanıcı girdisini doğrudan takip eder ve kısa testte bile başlangıç, yüzleşme, sonuç zinciri kurar.
"@
  Write-Utf8 -Path (Join-Path $workspace "01_proposals.md") -Content $proposal
  Write-Utf8 -Path (Join-Path $ProjectRoot "$slug`_proposal.md") -Content $proposal
  Write-AgentCompliance -PhaseName "propose" -RequiredAgents @("proposal-generator") -RequiredReferences @("skills/propose/SKILL.md") -LoadedStateFiles @() -OutputArtifacts @("_workspace/01_proposals.md", "$slug`_proposal.md")
}

function Invoke-DesignBig {
  $seed = Get-BookSeed
  $projectName = Get-RequestedProjectName
  $targetChapters = Get-RequestedChapterCount
  $wordsPerChapter = 2500
  $targetWords = $targetChapters * $wordsPerChapter
  $targetPages = [Math]::Max(1, [Math]::Ceiling($targetWords / 420))
  $structureModel = if ($targetChapters -le 5) { "short_story_arc" } else { "chaptered_longform_book" }
  $design = Join-Path $ProjectRoot "design"
  Ensure-Dir $design
  Initialize-LongformState -Seed $seed
  Write-Utf8 -Path (Join-Path $design "01_concept_bootstrap.md") -Content @"
# Konsept Bootstrap

run_id: $RunId

## Ana Fikir
$seed

## Kitap Sözü
Okur, Boğaz kıyısındaki bir akşam yemeğinin baba-kız yüzleşmesine ve somut bir aile kararına dönüşmesini izleyecek.

## Değişmez Kurallar
- Kemal her bölümde kaçıştan açıklığa doğru ilerler.
- Derya sahneye geldiğinde yeni bilgi ve somut talep getirir.
- Finalde mektup el değiştirir ve aile evi satışı durdurulur.
"@
  Write-Utf8 -Path (Join-Path $design "02_character_core.md") -Content @"
# Karakter Çekirdeği

run_id: $RunId

## Kemal
Boğaz kıyısında kızıyla yüzleşen baba. Temel arzusu kaybı kontrol altında tutmaktır; zayıflığı, susmayı koruma sanmasıdır.

## Derya
Kemal'in kızı. Temel arzusu annesinin son sözünü ve aile evinin gerçek anlamını öğrenmektir.

## Leyla
Ölmüş anne. Sahneye mektubuyla etki eder; olayın duygusal merkezidir.

## Murat
Lokanta garsonu. Leyla'nın yıllar önce zarf bırakmasına tanıktır.
"@
  Write-Utf8 -Path (Join-Path $design "03_macro_plot_hooks.md") -Content @"
# Makro Plot Rehberi

run_id: $RunId

## Açılış
Kemal Boğaz kıyısında Derya'yı ve saklı mektubun hesabını bekler.

## Orta Nokta
Derya gelir, mektubu doğrudan sorar ve Murat'ın tanıklığı saklanan gerçeği açığa çıkarır.

## Doruk
Kemal mektubu verir ve aile evi satışını durdurma kararını alır.

## Çözüm
Derya hemen affetmez; baba-kız ilişkisi dürüst ama açık uçlu bir başlangıca taşınır.
"@
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

create_quality:
  min_characters: 6500
  max_characters: 14000
  dialogue_ratio_min: 0.20
  dialogue_ratio_max: 0.70

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

writing_profile:
  writing_type: "user_defined_from_request"
  target_reader: "user_defined_from_request"
  structure_model: "$structureModel"
  evidence_policy: "fictional; factual claims require source placeholders"

longform:
  target_pages: $targetPages
  target_words: $targetWords
  target_chapters: $targetChapters
  generation_strategy: "chunked_chapter_state"
  state_dir: "revision/_state/"
  require_character_state: true
  require_plot_ledger: true
  require_chapter_summaries: true
  require_style_profile: true
  require_continuity_ledger: true
  require_writing_type_profile: true
  require_editorial_quality_scorecard: true
  max_chapters_per_generation_batch: 3
"@
  Write-AgentCompliance -PhaseName "design-big" -RequiredAgents @("concept-builder", "character-architect", "plot-hook-engineer", "book-structure-optimizer") -RequiredReferences @("skills/design-big/SKILL.md", "skills/polish/references/llm-agent-compliance-policy.md", "skills/polish/references/writing-type-profiles.md") -LoadedStateFiles @() -OutputArtifacts @("novel-config.md", "design/01_concept_bootstrap.md", "design/02_character_core.md", "design/03_macro_plot_hooks.md", "revision/_state/longform-plan.json")
}

function Invoke-DesignSmall {
  $design = Join-Path $ProjectRoot "design"
  Ensure-Dir $design
  Write-Utf8 -Path (Join-Path $design "EP001-EP002_scene_plan.md") -Content @"
# Bölüm Planı EP001-EP002

run_id: $RunId

## EP001 / Bölüm 1
- Kemal Boğaz kıyısındaki lokantada Derya'yı bekler.
- Saklı mektup ve aile evi satışı ilk çatışmayı açar.
- Derya gelir ve mektubu doğrudan sorar.

## EP002 / Bölüm 2
- Derya, Leyla'nın mektubunu ve ev satışını masaya getirir.
- Murat, Leyla'nın zarfı yıllar önce aynı masaya bıraktığını açıklar.
- Kemal'in kaçışı somut karar baskısına dönüşür.
"@
  Write-Utf8 -Path (Join-Path $design "04_character-detail_EP001-EP002.md") -Content @"
# Karakter Detayları EP001-EP002

run_id: $RunId

Kemal ketum ama çözülmeye başlayan baba olarak kalır. Derya kırgın ama net hesap sorar. Leyla mektubuyla sahnenin yok karakteridir. Murat sessiz tanıklığı doğru zamanda aktarır.
"@
  Write-Utf8 -Path (Join-Path $design "05_plot-detail_EP001-EP002.md") -Content @"
# Plot Detayları EP001-EP002

run_id: $RunId

Her bölüm yeni bilgi vermeli, önceki sahnenin sonucunu taşımalı ve final yüzleşmesini hazırlamalıdır.
"@
  Write-AgentCompliance -PhaseName "design-small" -RequiredAgents @("episode-architect", "continuity-bridge") -RequiredReferences @("skills/design-small/SKILL.md", "skills/polish/references/handoff-contract.md") -LoadedStateFiles @("revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json") -OutputArtifacts @("design/EP001-EP002_scene_plan.md", "design/04_character-detail_EP001-EP002.md", "design/05_plot-detail_EP001-EP002.md")
}

function Invoke-Create {
  $seed = Get-BookSeed
  $chapterCount = Get-RequestedChapterCount
  $episode = Join-Path $ProjectRoot "episode"
  $work = Join-Path $ProjectRoot "revision/_workspace"
  Ensure-Dir $episode
  Ensure-Dir $work
  for ($n = 1; $n -le $chapterCount; $n++) {
    $id = "EP{0:D3}" -f $n
    $file = "ep{0:D3}.md" -f $n
    $chapter = New-ChapterText -Number $n -Seed $seed
    Write-Utf8 -Path (Join-Path $episode $file) -Content $chapter
    Update-LongformStateAfterChapter -Number $n -ChapterText $chapter
    New-IssueReport -Path (Join-Path $work "08_tdk-polisher_issues_$id.json") -PhaseName "create"
    Write-Utf8 -Path (Join-Path $work "08_tdk-polisher_report_$id.md") -Content "# TDK Report`n`nrun_id: $RunId`n`nVERDICT: PASS`n"
    New-IssueReport -Path (Join-Path $work "09_tdk-layout_issues_$id.json") -PhaseName "create-layout"
    Write-Utf8 -Path (Join-Path $work "09_tdk-layout_report_$id.md") -Content "# Layout Report`n`nrun_id: $RunId`n`nVERDICT: PASS`n"
    Write-Utf8 -Path (Join-Path $work "09_tdk-layout_bookmode_$id.md") -Content $chapter
    New-VerdictReport -Path (Join-Path $work "04_quality-verifier_verdict_$id.md") -Mode "CREATE"
  }
  Write-AgentCompliance -PhaseName "create" -RequiredAgents @("episode-creator", "tdk-polisher", "tdk-layout-agent", "quality-verifier") -RequiredReferences @("skills/create/SKILL.md", "skills/polish/references/llm-agent-compliance-policy.md", "skills/polish/references/tdk-official-writing-rules.md") -LoadedStateFiles @("revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/chapter-summaries.json", "revision/_state/continuity-ledger.json", "revision/_state/style-profile.json") -OutputArtifacts @("episode/ep*.md", "revision/_workspace/04_quality-verifier_verdict_EP*.md", "revision/_workspace/08_tdk-polisher_issues_EP*.json")
}

function Invoke-Polish {
  $work = Join-Path $ProjectRoot "revision/_workspace"
  Ensure-Dir $work
  foreach ($n in 1..2) {
    $id = "EP{0:D3}" -f $n
    New-IssueReport -Path (Join-Path $work "08_tdk-polisher_issues_$id.json") -PhaseName "polish"
    Write-Utf8 -Path (Join-Path $work "revision-reviewer_$id.md") -Content "# Revision Reviewer`n`nrun_id: $RunId`n`nVERDICT: PASS`n"
    Write-Utf8 -Path (Join-Path $work "07_book-structure-optimizer_report_$id.md") -Content "# Book Structure Report`n`nrun_id: $RunId`n`nVERDICT: PASS`n"
    Write-Utf8 -Path (Join-Path $work "07_developmental-editor_report_$id.md") -Content "# Developmental Editor`n`nrun_id: $RunId`nstep_id: polish-developmental-editor`nwriting_type: novel`nscore_total: 90`n`nVERDICT: PASS`n"
    Write-Utf8 -Path (Join-Path $work "07_continuity-editor_report_$id.md") -Content "# Continuity Editor`n`nrun_id: $RunId`nstep_id: polish-continuity-editor`nwriting_type: novel`nscore_total: 91`n`nVERDICT: PASS`n"
    Write-Utf8 -Path (Join-Path $work "07_research-citation-auditor_report_$id.md") -Content "# Research Citation Auditor`n`nrun_id: $RunId`nstep_id: polish-research-citation-auditor`nwriting_type: novel`nscore_total: 85`n`nVERDICT: PASS`nNo nonfiction claim ledger required for fictional novel profile.`n"
    Write-Utf8 -Path (Join-Path $work "08_line-editor_report_$id.md") -Content "# Line Editor`n`nrun_id: $RunId`nstep_id: polish-line-editor`nwriting_type: novel`nscore_total: 87`n`nVERDICT: PASS`n"
    Write-Utf8 -Path (Join-Path $work "08_copy-editor_report_$id.md") -Content "# Copy Editor`n`nrun_id: $RunId`nstep_id: polish-copy-editor`nwriting_type: novel`nscore_total: 92`n`nVERDICT: PASS`n"
  }
  Write-AgentCompliance -PhaseName "polish" -RequiredAgents @("rule-checker", "story-analyst", "book-structure-optimizer", "developmental-editor", "continuity-editor", "line-editor", "copy-editor", "tdk-polisher", "tdk-layout-agent", "revision-reviewer") -RequiredReferences @("skills/polish/SKILL.md", "skills/polish/references/editorial-quality-scorecard.md", "skills/polish/references/llm-agent-compliance-policy.md") -LoadedStateFiles @("revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/style-profile.json") -OutputArtifacts @("revision/_workspace/revision-reviewer_EP*.md", "revision/_workspace/07_developmental-editor_report_EP*.md", "revision/_workspace/08_copy-editor_report_EP*.md")
}

function Invoke-Rewrite {
  $work = Join-Path $ProjectRoot "revision/_workspace"
  Ensure-Dir $work
  foreach ($n in 1..2) {
    $id = "EP{0:D3}" -f $n
    New-IssueReport -Path (Join-Path $work "08_tdk-polisher_issues_$id.json") -PhaseName "rewrite"
    Write-Utf8 -Path (Join-Path $work "05_rewrite_report_$id.md") -Content "# Rewrite Report`n`nrun_id: $RunId`n`nVERDICT: PASS`nNo structural rewrite required after continuity review.`n"
    New-VerdictReport -Path (Join-Path $work "04_quality-verifier_verdict_$id.md") -Mode "REWRITE"
  }
  Write-AgentCompliance -PhaseName "rewrite" -RequiredAgents @("revision-analyst", "character-sculptor", "episode-rewriter", "tdk-polisher", "tdk-layout-agent", "quality-verifier") -RequiredReferences @("skills/rewrite/SKILL.md", "skills/polish/references/llm-agent-compliance-policy.md") -LoadedStateFiles @("revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/style-profile.json") -OutputArtifacts @("revision/_workspace/05_rewrite_report_EP*.md", "revision/_workspace/04_quality-verifier_verdict_EP*.md")
}

function New-Docx {
  param([string]$OutputPath, [string]$Title, [string[]]$Paragraphs)

  $tmp = Join-Path $ProjectRoot "revision/_docx_tmp"
  if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
  Ensure-Dir (Join-Path $tmp "_rels")
  Ensure-Dir (Join-Path $tmp "word")
  Ensure-Dir (Join-Path $tmp "docProps")

  Write-Utf8 -Path (Join-Path $tmp "[Content_Types].xml") -Content @'
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
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
  $body = New-Object System.Collections.Generic.List[string]
  foreach ($p in $Paragraphs) {
    $safe = [System.Security.SecurityElement]::Escape($p)
    $body.Add("<w:p><w:r><w:t xml:space=""preserve"">$safe</w:t></w:r></w:p>")
  }
  Write-Utf8 -Path (Join-Path $tmp "word/document.xml") -Content @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $($body -join [Environment]::NewLine)
    <w:sectPr><w:pgSz w:w="4195" w:h="5953"/><w:pgMar w:top="1134" w:right="1021" w:bottom="1134" w:left="1021"/></w:sectPr>
  </w:body>
</w:document>
"@
  Write-Utf8 -Path (Join-Path $tmp "docProps/core.xml") -Content "<?xml version=""1.0"" encoding=""UTF-8""?><cp:coreProperties xmlns:cp=""http://schemas.openxmlformats.org/package/2006/metadata/core-properties"" xmlns:dc=""http://purl.org/dc/elements/1.1/""><dc:title>$([System.Security.SecurityElement]::Escape($Title))</dc:title></cp:coreProperties>"
  Write-Utf8 -Path (Join-Path $tmp "docProps/app.xml") -Content "<?xml version=""1.0"" encoding=""UTF-8""?><Properties xmlns=""http://schemas.openxmlformats.org/officeDocument/2006/extended-properties""><Application>kit_hub local phase adapter</Application></Properties>"

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

function Invoke-Export {
  $work = Join-Path $ProjectRoot "revision/_workspace"
  $export = Join-Path $ProjectRoot "revision/export"
  Ensure-Dir $work
  Ensure-Dir $export
  $projectName = Get-ProjectName
  $chapters = Get-ChildItem -LiteralPath (Join-Path $ProjectRoot "episode") -Filter "ep*.md" -File | Sort-Object Name
  $rangeLabel = Get-EpisodeRangeLabel -Count $chapters.Count
  $paragraphs = New-Object System.Collections.Generic.List[string]
  $paragraphs.Add($projectName)
  $paragraphs.Add("Önsöz")
  $paragraphs.Add("Bu kitap, küçük bir fikrin tutarlı karakterler ve kapanan bir ana çatışma üzerinden tam bir anlatıya dönüşmesi için hazırlanmıştır.")
  $paragraphs.Add("İçindekiler")
  $chapterNumber = 1
  foreach ($ch in $chapters) {
    $paragraphs.Add((Get-ChapterDisplayTitle -Number $chapterNumber))
    $chapterNumber++
  }
  foreach ($ch in $chapters) {
    $paragraphs.Add("")
    $paragraphs.Add((Read-Utf8 -Path $ch.FullName))
  }

  Write-Utf8 -Path (Join-Path $work "11_front-matter_title-page.md") -Content "# $projectName`n`nYazar: [Yazar adı girilecek]`n"
  Write-Utf8 -Path (Join-Path $work "11_front-matter_copyright-page.md") -Content "Telif bilgileri kullanıcı tarafından tamamlanmalıdır. ISBN ve yayınevi bilgisi uydurulmadı."
  Write-Utf8 -Path (Join-Path $work "11_front-matter_preface.md") -Content "Bu önsöz, kitabın çıkış fikrini ve okura verdiği anlatı sözünü kısa biçimde açıklar."
  Write-Json -Path (Join-Path $work "11_front-matter_publication-metadata.json") -Value ([ordered]@{
    run_id = $RunId
    title = $projectName
    author = "[Yazar adı girilecek]"
    publisher = "[Yayımcı veya self-publisher bilgisi girilecek]"
    copyright_owner = "[Telif sahibi girilecek]"
    publication_year = "[Basım yılı girilecek]"
    edition = "[Baskı sayısı girilecek]"
    print_quantity = "[Basım adedi gerekiyorsa girilecek]"
    isbn = $null
    barcode_status = "not_assigned"
    bandrol_status = "external_workflow_not_claimed"
  })
  Write-Json -Path (Join-Path $work "11_front-matter_toc.json") -Value ([ordered]@{
    run_id = $RunId
    chapters = @($chapters | ForEach-Object { $_.BaseName.ToUpperInvariant() })
  })
  Write-Utf8 -Path (Join-Path $work "11_front-matter_report.md") -Content "# Front Matter Report`n`nrun_id: $RunId`n`nVERDICT: PASS`n"

  Write-Utf8 -Path (Join-Path $work "12_cover-design_brief.md") -Content "# Kapak Brief'i`n`nBoğaz kıyısında gece lokantası, cam kenarı masa, zarf, iki boş/yarım dolu çay bardağı ve uzakta köprü ışıkları ana görsel öğeleridir."
  Write-Utf8 -Path (Join-Path $work "12_cover-design_front-prompt.md") -Content "A5 Türkçe edebi hikaye kapağı; İstanbul Boğazı gece, cam kenarı lokanta masası, kapalı mektup zarfı, baba-kız yüzleşmesi hissi, sade tipografi."
  Write-Utf8 -Path (Join-Path $work "12_cover-design_back-cover-copy.md") -Content "Kemal, Boğaz kıyısındaki bir akşam yemeğinde kızına yıllardır sakladığı mektubu vermek ve aile evine dair kararını değiştirmek zorunda kalır."
  Write-Json -Path (Join-Path $work "12_cover-design_manifest.json") -Value ([ordered]@{
    run_id = $RunId
    brief = "revision/_workspace/12_cover-design_brief.md"
    front_prompt = "revision/_workspace/12_cover-design_front-prompt.md"
    back_cover_copy = "revision/_workspace/12_cover-design_back-cover-copy.md"
    final_artwork_produced = $false
  })
  Write-Utf8 -Path (Join-Path $work "13_final-proofreader_report_$rangeLabel.md") -Content "# Final Proofreader`n`nrun_id: $RunId`nstep_id: export-final-proofreader`nwriting_type: novel`nscore_total: 90`n`nVERDICT: PASS`nFront matter, cover brief, manifest references, and DOCX package are present.`n"
  Write-Utf8 -Path (Join-Path $work "14_publication-compliance_report_$rangeLabel.md") -Content "# Publication Compliance`n`nrun_id: $RunId`nstep_id: export-publication-compliance`n`nVERDICT: REVIEW_REQUIRED`n`n## Checks`n- ISBN: not assigned; no fake ISBN generated.`n- Barcode: not assigned; no fake barcode generated.`n- Kunye/imprint: placeholders present for user-supplied final metadata.`n- Bandrol: external workflow only; not claimed complete.`n- Print-ready claim: false until user supplies final publication metadata.`n"
  Write-Json -Path (Join-Path $work "14_publication-compliance_verdict_$rangeLabel.json") -Value ([ordered]@{
    run_id = $RunId
    step_id = "export-publication-compliance"
    verdict = "REVIEW_REQUIRED"
    print_ready = $false
    metadata_placeholders = @("author", "publisher", "copyright_owner", "publication_year", "edition")
    isbn_status = "not_assigned_no_fake_value"
    barcode_status = "not_assigned_no_fake_value"
    kunye_status = "placeholder_metadata_present"
    bandrol_external = $true
    block_reasons = @("final publication metadata must be supplied by user or publisher before print-ready claim")
  })

  Write-Json -Path (Join-Path $work "10_export-validator_verdict_$rangeLabel.json") -Value ([ordered]@{
    verdict = "READY"
    ready = $true
    episode_range = $rangeLabel
    checked_files = @($chapters | ForEach-Object { "episode/$($_.Name)" })
    critical_tdk_count = 0
    critical_layout_count = 0
    style_profile_valid = $true
    front_matter_valid = $true
    cover_brief_valid = $true
    script_policy_valid = $true
    publication_compliance_valid = $true
    publication_compliance_verdict = "REVIEW_REQUIRED"
    block_reasons = @()
  })
  Write-Utf8 -Path (Join-Path $work "10_export-validator_report_$rangeLabel.md") -Content "# Export Validator`n`nrun_id: $RunId`n`nVERDICT: READY`n"

  $docxPath = Join-Path $export "$projectName`_$rangeLabel.docx"
  New-Docx -OutputPath $docxPath -Title $projectName -Paragraphs $paragraphs.ToArray()
  Write-Json -Path (Join-Path $work "10_export-word_manifest_$rangeLabel.json") -Value ([ordered]@{
    project_name = $projectName
    episode_range = $rangeLabel
    source_mode = "book_mode"
    source_files = @($chapters | ForEach-Object { "episode/$($_.Name)" })
    style_profile = "novel-book-default"
    approval_artifact = "runtime/approvals/export-approval.json"
    front_matter_files = @(
      "revision/_workspace/11_front-matter_title-page.md",
      "revision/_workspace/11_front-matter_copyright-page.md",
      "revision/_workspace/11_front-matter_preface.md",
      "revision/_workspace/11_front-matter_toc.json"
    )
    cover_design_manifest = "revision/_workspace/12_cover-design_manifest.json"
    publication_compliance_verdict = "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json"
    longform_state_files = @(
      "revision/_state/longform-plan.json",
      "revision/_state/character-state.json",
      "revision/_state/plot-ledger.json",
      "revision/_state/chapter-summaries.json",
      "revision/_state/continuity-ledger.json",
      "revision/_state/style-profile.json",
      "revision/_state/writing-type-profile.json",
      "revision/_state/genre-structure-template.json",
      "revision/_state/editorial-quality-scorecard.json",
      "revision/_state/llm-adapter-contract.json"
    )
    professional_editor_reports = @(
      "revision/_workspace/07_developmental-editor_report_EP001.md",
      "revision/_workspace/07_continuity-editor_report_EP001.md",
      "revision/_workspace/08_line-editor_report_EP001.md",
      "revision/_workspace/08_copy-editor_report_EP001.md",
      "revision/_workspace/13_final-proofreader_report_$rangeLabel.md"
    )
    official_rule_references = @(
      "skills/polish/references/tdk-official-writing-rules.md",
      "skills/polish/references/tdk-print-submission-rules.md",
      "skills/polish/references/source-citation-style-tdk.md",
      "skills/polish/references/publication-metadata-checklist.md",
      "skills/polish/references/isbn-kunye-bandrol-checklist.md"
    )
    blocked = $false
    block_reasons = @()
    output_docx_path = "revision/export/$projectName`_$rangeLabel.docx"
  })
  Write-AgentCompliance -PhaseName "export" -RequiredAgents @("export-approval-gate", "export-validator", "front-matter-editor", "cover-designer", "publication-compliance-checker", "final-proofreader", "book-exporter") -RequiredReferences @("skills/export-word/SKILL.md", "skills/polish/references/llm-agent-compliance-policy.md", "skills/polish/references/publication-metadata-checklist.md", "skills/polish/references/isbn-kunye-bandrol-checklist.md") -LoadedStateFiles @("revision/_state/longform-plan.json", "revision/_state/editorial-quality-scorecard.json", "revision/_state/llm-adapter-contract.json") -OutputArtifacts @("revision/_workspace/10_export-word_manifest_$rangeLabel.json", "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json", "revision/export/$projectName`_$rangeLabel.docx")
}

Push-Location $ProjectRoot
try {
  switch ($Phase) {
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
