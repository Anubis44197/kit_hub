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

function Get-RequestedChapterCount {
  $raw = Get-BookSeed
  $m = [regex]::Match($raw, "(?i)(\d+)\s*(bölüm|bolum|chapter|chapters)")
  if ($m.Success) {
    $count = [int]$m.Groups[1].Value
    if ($count -ge 1 -and $count -le 120) { return $count }
  }
  return 12
}

function Get-CleanTitleFromText {
  param([string]$Text)
  $line = (($Text -split "\r?\n") | Where-Object { $_.Trim() -and $_ -notmatch "^\s*#" } | Select-Object -First 1)
  if (-not $line) { $line = $Text }
  $line = ($line -replace "(?i)^\s*\d+\s*(bölüm|bolum|chapter|chapters)\s*[:\-]?\s*", "").Trim()
  $words = @($line -split "\s+" | Where-Object { $_.Trim() } | Select-Object -First 5)
  if ($words.Count -lt 1) { return "Konu Bekleniyor" }
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
      if ($name -and $name -ne "Konu Bekleniyor") { return $name }
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

  $dir = Join-Path $ProjectRoot "runtime/agent-compliance"
  Ensure-Dir $dir
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
  Write-Json -Path (Join-Path $dir "$PhaseName.json") -Value ([ordered]@{
    run_id = $RunId
    phase = $PhaseName
    required_agents = $RequiredAgents
    agents_executed = $RequiredAgents
    required_references = $RequiredReferences
    loaded_state_files = $LoadedStateFiles
    output_artifacts = $OutputArtifacts
    artifact_hashes = $artifactHashes
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
  $bad = @($Paragraphs | Where-Object { $_ -match "(?i)\bEP\d{3}\b|^scene\s+\d+|^sahne\s+\d+|```|run_id\s*:" })
  if ($bad.Count -gt 0) {
    throw "Export blocked: user-facing manuscript contains technical markers such as EP001, scene labels, code fences, or run_id."
  }
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

  Write-AgentCompliance -PhaseName "propose" -RequiredAgents @("proposal-generator") -RequiredReferences @("skills/propose/SKILL.md") -LoadedStateFiles @("runtime/book-request.md") -OutputArtifacts @("_workspace/01_proposals.md", "$slug`_proposal.md", "runtime/approvals/story-choice.json")
}

function Invoke-DesignBig {
  $seed = Get-BookSeed
  $choice = Get-StoryChoice
  $projectName = Get-CleanTitleFromText -Text $seed
  $targetChapters = Get-RequestedChapterCount
  $wordsPerChapter = 2500
  $targetWords = $targetChapters * $wordsPerChapter
  $targetPages = [Math]::Max(1, [Math]::Ceiling($targetWords / 420))
  $structureModel = if ($targetChapters -le 5) { "short_story_arc" } else { "chaptered_longform_book" }
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
  for ($i = 1; $i -le $targetChapters; $i++) {
    $chapterId = ("EP{0:D3}" -f $i)
    $readerTitle = ("Bölüm {0}" -f $i)
    $chapters += [ordered]@{
      id = $chapterId
      reader_label = $readerTitle
      target_words = $wordsPerChapter
      purpose = "Bu bölüm olay, karakter veya tema açısından ölçülebilir yeni ilerleme taşımalıdır."
      must_advance = @("plot", "character", "theme")
    }
    $chapterPlan += [ordered]@{
      id = $chapterId
      reader_title = $readerTitle
      purpose = "Önceki bölümün sonucundan doğan yeni olay, karar veya çatışma üret."
      events = @("Yeni bilgi ortaya çıkar.", "Karakter bir seçim yapmak zorunda kalır.", "Bölüm sonunda geri alınamaz bir sonuç oluşur.")
      character_focus = @("Ana karakterin arzusu, korkusu ve bilgi sınırı güncellenir.")
      continuity_promises = @("Bölüm sonucu sonraki bölümün nedenini oluşturur.", "Tekrarlanan açılış ve teknik sahne etiketi kullanılmaz.")
      target_words = $wordsPerChapter
    }
  }

  $requiredStateFiles = @(
    "revision/_state/book-plan.json",
    "revision/_state/chapter-plan.json",
    "revision/_state/layout-plan.json",
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
"@

  Write-Utf8 -Path (Join-Path $design "05_chapter_plan.md") -Content @"
# Bölüm Planı

run_id: $RunId
plan_id: $planId

Her bölüm önceki bölümün sonucundan doğmalı, yeni bilgi üretmeli ve karakter/olay durumunu değiştirmelidir. Okur çıktısında EP kodu veya sahne etiketi kullanılamaz.
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
"@

  Write-Json -Path (Join-Path $state "book-plan.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    plan_id = $planId
    source_prompt = $seed
    approved_story_option = $choice.selected_option
    title_working = $projectName
    writing_type = "user_defined_book"
    genre = "user_defined_from_request"
    theme = "user_defined_from_request"
    premise = $seed
    narrative_pov = "to_be_confirmed_in_plan"
    tense = "to_be_confirmed_in_plan"
    characters = @(
      [ordered]@{
        role = "protagonist"
        name = "plan_required_before_writing"
        desire = "Somut arzu yazım başlamadan önce netleştirilecek."
        fear = "Somut korku yazım başlamadan önce netleştirilecek."
        arc = "Başlangıç, kırılma ve sonuç konumu plan onayında net olmalıdır."
      }
    )
    plot_arc = [ordered]@{
      opening_promise = "Açılış vaadi plan onayında net olmalıdır."
      inciting_incident = "Kışkırtıcı olay plan onayında net olmalıdır."
      midpoint_turn = "Orta nokta dönüşü plan onayında net olmalıdır."
      climax = "Doruk plan onayında net olmalıdır."
      resolution = "Kapanış vaatleri plan onayında net olmalıdır."
    }
    chapter_count = $targetChapters
    approval_required = $true
  })
  Write-Json -Path (Join-Path $state "chapter-plan.json") -Value ([ordered]@{ schema_version = "1.0.0"; run_id = $RunId; plan_id = $planId; chapters = $chapterPlan })
  Write-Json -Path (Join-Path $state "layout-plan.json") -Value ([ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    plan_id = $planId
    trim_size = "A5"
    font_family = "Times New Roman"
    font_size_pt = 11
    line_spacing = 1.15
    paragraph_first_line_indent_cm = 0.7
    words_per_page_estimate = 420
    target_pages = $targetPages
    target_words = $targetWords
    target_chapters = $targetChapters
    front_matter_pages_estimate = 6
    back_matter_pages_estimate = 0
    chapter_start_policy = "new_page"
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
    production_mode = "approval_gated_chunked_longform"
    chapters = $chapters
    required_state_files = $requiredStateFiles
  })
  Write-Json -Path (Join-Path $state "character-state.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; characters = @([ordered]@{ id = "protagonist"; name = "plan_required_before_writing"; stable_traits = @(); knows = @(); does_not_know = @(); arc_position = "planned" }); required = @("stable_traits", "knows", "does_not_know", "arc_position") })
  Write-Json -Path (Join-Path $state "plot-ledger.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; main_question = "Plan onayında netleştirilecek ana dramatik soru."; open_threads = @("Ana konu plan onayında somutlaştırılacak."); closed_threads = @(); cause_effect_chain = @(); final_promises = @("Açılış vaadi ve kapanış beklentisi plan onayında netleştirilecek.") })
  Write-Json -Path (Join-Path $state "chapter-summaries.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; chapters = @() })
  Write-Json -Path (Join-Path $state "continuity-ledger.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; timeline = @(); locations = @(); object_state = [ordered]@{}; violations = @() })
  Write-Json -Path (Join-Path $state "style-profile.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; profile = "Turkish print-ready prose"; narration = "Plan onayında bakış açısı ve zaman kesinleşir."; language = "tr-TR"; dialogue_policy = "dash_dialogue"; print_format = "A5, readable paragraphs, no technical labels in reader output"; forbidden = @("EP001 in reader output", "scene labels in reader output", "untracked time jump", "repeated chapter premise") })
  Write-Json -Path (Join-Path $state "writing-type-profile.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; writing_type = "user_defined"; target_reader = "user_defined"; structure_model = $structureModel; voice_model = "consistent book voice selected in approved plan"; evidence_policy = "No research/source claim without source artifacts."; supported_types = @("novel", "story", "novella", "essay", "memoir", "biography", "research_book", "self_help", "business_book", "academic"); continuity_policy = "state-ledger-first"; completion_criteria = @("approved book plan", "approved layout plan", "chapter continuity ledgers", "publication readiness gates") })
  Write-Json -Path (Join-Path $state "genre-structure-template.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; template_id = $structureModel; acts = @("setup", "development", "turn", "climax", "resolution"); chapter_rules = @("Each chapter must create new consequence.", "No chapter may restate the same situation without change.", "No character may use unknown information."); mandatory_ledgers = @("character-state.json", "plot-ledger.json", "continuity-ledger.json", "chapter-summaries.json") })
  Write-Json -Path (Join-Path $state "editorial-quality-scorecard.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; threshold_pass = 85; axes = @("continuity", "progression", "style", "language", "layout", "publication-readiness"); export_blockers = @("critical_continuity_issue", "missing_front_matter", "missing_cover_brief", "technical_marker_in_reader_output", "missing_story_choice_approval", "missing_book_plan_approval"); verdict = "DESIGN_PENDING_DETAIL" })
  Write-Json -Path (Join-Path $state "llm-adapter-contract.json") -Value ([ordered]@{ schema_version = "1.1.0"; run_id = $RunId; adapter_contract = "Provider or IDE agent must load approved plan/state, write only requested phase artifacts, and update state ledgers."; max_chapters_per_batch = 3; required_input_state = $requiredStateFiles; required_output_state = @("revision/_state/chapter-summaries.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/continuity-ledger.json"); local_adapter_boundary = "The local adapter creates scaffolding and export packages only from existing artifacts; it must not invent manuscript, preface, or cover copy."; authorship_policy = "Creative authorship belongs to provider command, IDE agent, or human writer."; research_policy = "No web/TDK/source research claim without source artifacts." })

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
  max_chapters_per_generation_batch: 3
  required_plan_approval: "runtime/approvals/book-plan-approval.json"
  plan_state_files:
    - "revision/_state/book-plan.json"
    - "revision/_state/chapter-plan.json"
    - "revision/_state/layout-plan.json"
"@

  Write-AgentCompliance -PhaseName "design-big" -RequiredAgents @("concept-builder", "character-architect", "plot-hook-engineer", "book-structure-optimizer") -RequiredReferences @("skills/design-big/SKILL.md", "skills/polish/references/llm-agent-compliance-policy.md") -LoadedStateFiles @("runtime/book-request.md", "runtime/approvals/story-choice.json") -OutputArtifacts @("novel-config.md", "design/01_concept_bootstrap.md", "design/02_character_core.md", "design/03_macro_plot_hooks.md", "design/04_book_plan.md", "design/05_chapter_plan.md", "design/06_layout_plan.md", "revision/_state/book-plan.json", "revision/_state/chapter-plan.json", "revision/_state/layout-plan.json", "revision/_state/longform-plan.json", "revision/_state/character-state.json", "revision/_state/plot-ledger.json", "revision/_state/chapter-summaries.json", "revision/_state/continuity-ledger.json", "revision/_state/style-profile.json", "revision/_state/writing-type-profile.json", "revision/_state/genre-structure-template.json", "revision/_state/editorial-quality-scorecard.json", "revision/_state/llm-adapter-contract.json")
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
  $last = [Math]::Min([int]$plan.target_chapters, 3)
  $range = "EP001-EP{0:D3}" -f $last
  Write-Utf8 -Path (Join-Path $design "$range`_scene_plan.md") -Content @"
# Bölüm Planı $range

run_id: $RunId

Her bölüm için IDE ajanı/provider şu alanları doldurmalıdır:
- Okur başlığı
- Sahne amacı
- Yeni bilgi
- Karakter değişimi
- Kapanış sonucu
- Bir sonraki bölüme neden olan bağ

Tekrarlanan bölüm kurulumu, EP kodu ve teknik sahne etiketi kullanıcı çıktısına giremez.
"@
  Write-Utf8 -Path (Join-Path $design "04_character-detail_$range.md") -Content "# Karakter Detayları $range`n`nrun_id: $RunId`n`nKarakter bilgi sınırları, arzular, korkular ve bölüm sonu değişimleri burada somutlaştırılmalıdır.`n"
  Write-Utf8 -Path (Join-Path $design "05_plot-detail_$range.md") -Content "# Plot Detayları $range`n`nrun_id: $RunId`n`nHer bölüm önceki bölümün sonucu olarak başlamalı ve yeni sonuç üretmelidir.`n"
  Write-AgentCompliance -PhaseName "design-small" -RequiredAgents @("episode-architect", "continuity-bridge") -RequiredReferences @("skills/design-small/SKILL.md", "skills/polish/references/handoff-contract.md") -LoadedStateFiles @("revision/_state/longform-plan.json", "revision/_state/book-plan.json", "revision/_state/chapter-plan.json", "revision/_state/layout-plan.json", "runtime/approvals/book-plan-approval.json") -OutputArtifacts @("design/$range`_scene_plan.md", "design/04_character-detail_$range.md", "design/05_plot-detail_$range.md")
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
  foreach ($ch in $chapters) {
    $heading = Get-ChapterHeadingFromText -Path $ch.FullName -Number $chapterNumber
    $tocItems += [ordered]@{ chapter = $chapterNumber; title = $heading; source = "episode/$($ch.Name)" }
    $paragraphs.Add($heading)
    $chapterNumber++
  }
  foreach ($ch in $chapters) {
    foreach ($p in (Convert-MarkdownToParagraphs -Path $ch.FullName)) { $paragraphs.Add($p) }
  }
  foreach ($p in (Convert-MarkdownToParagraphs -Path $cover.back_cover_copy)) { $paragraphs.Add($p) }

  Assert-ManuscriptClean -Paragraphs $paragraphs.ToArray()

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

  $docxPath = Join-Path $export "$projectName`_$rangeLabel.docx"
  New-Docx -OutputPath $docxPath -Title $projectName -Paragraphs $paragraphs.ToArray()
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
    approval_artifact = "runtime/approvals/export-approval.json"
    front_matter_files = @($front.Keys | ForEach-Object { Get-RelativePath -Path $front[$_] })
    cover_design_manifest = Get-RelativePath -Path $cover.manifest
    cover_files = @($cover.Keys | ForEach-Object { Get-RelativePath -Path $cover[$_] })
    publication_compliance_verdict = "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json"
    local_adapter_boundary = "No manuscript, preface, or cover copy was invented during export."
    docx_sha256 = Get-FileSha256 -Path $docxPath
    output_docx_path = "revision/export/$projectName`_$rangeLabel.docx"
  })
  Write-AgentCompliance -PhaseName "export" -RequiredAgents @("export-approval-gate", "export-validator", "publication-compliance-checker", "final-proofreader", "book-exporter") -RequiredReferences @("skills/export-word/SKILL.md", "skills/polish/references/publication-metadata-checklist.md", "skills/polish/references/isbn-kunye-bandrol-checklist.md") -LoadedStateFiles @("runtime/approvals/export-approval.json", "revision/_state/llm-adapter-contract.json") -OutputArtifacts @("revision/_workspace/10_export-word_manifest_$rangeLabel.json", "revision/_workspace/14_publication-compliance_verdict_$rangeLabel.json", "revision/export/$projectName`_$rangeLabel.docx")
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
