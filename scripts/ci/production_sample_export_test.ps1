param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path,
  [string]$KeepOutputDirectory = ""
)

$ErrorActionPreference = "Stop"

function Write-Utf8BomText {
  param([string]$Path, [string]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) {
    New-Item -ItemType Directory -Path $dir | Out-Null
  }
  [System.IO.File]::WriteAllText($Path, $Value, [System.Text.UTF8Encoding]::new($true))
}

function Write-Utf8BomJson {
  param([string]$Path, [object]$Value)
  Write-Utf8BomText -Path $Path -Value ($Value | ConvertTo-Json -Depth 50)
}

function Read-Utf8Json {
  param([string]$Path)
  return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
}

function Invoke-CheckedPowerShell {
  param([string[]]$Arguments)
  $output = & powershell @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw ($output | Out-String).Trim()
  }
  return $output
}

function Get-FileSha256Local {
  param([string]$Path)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try {
    $stream = [System.IO.File]::OpenRead($Path)
    try {
      $hash = $sha.ComputeHash($stream)
      return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally { $stream.Dispose() }
  }
  finally { $sha.Dispose() }
}

function New-ChapterText {
  param(
    [int]$Index,
    [string]$Title,
    [string[]]$Characters
  )
  $places = @("Pera Palas lobisi", "Tepebaşı yokuşu", "Galata rıhtımı", "Sirkeci garı", "Dolmabahçe duvarı", "Karaköy hanı", "Beyoğlu pasajı", "eski sarnıç kapısı")
  $objects = @("gümüş anahtar", "lacivert defter", "kurşun mühür", "ıslak harita", "kırık saat", "ipek mendil", "paslı rozet", "kül rengi zarf")
  $verbs = @("öğrendi", "sordu", "söyledi", "verdi", "aldı", "açıkladı", "itiraf etti", "karar verdi", "durdurdu", "değişti", "gitti", "geldi", "çıktı", "başladı", "kapandı")
  $psych = @("şüphe", "kaygı", "vicdan", "panik", "paranoya", "suçluluk", "karabasan", "takıntı", "çözülme")
  $sensory = @("yağmur kokusu", "ıslak taş", "soğuk cam", "boğuk ses", "titreme", "nefes", "karanlık ışık", "tuzlu rüzgar")
  $chapterTerms = @(1..90 | ForEach-Object { "ozgun${Index}iz$_" })
  $paragraphs = New-Object System.Collections.Generic.List[string]
  $paragraphs.Add("# $Title")
  $paragraphs.Add(("Bu bölümün ayırt edici izleri: {0}. Bu sözcük alanı yalnız bu bölümde kullanılır ve olayın yönünü ayrı bir hatta taşır." -f ($chapterTerms -join ", ")))
  $paragraphs.Add(("{0}, {1} içinde {2} izini {3}; {4} pencerenin buğusunda kendi yüzünü değil, {5} gölgesini gördü. Bu bölümde karar değişti, bilgi geldi, sır açıklandı ve kapı kapandı." -f $Characters[0], $places[($Index - 1) % $places.Count], $objects[($Index - 1) % $objects.Count], $verbs[($Index - 1) % $verbs.Count], $Characters[1], $Characters[2]))
  for ($i = 0; $i -lt 18; $i++) {
    $a = $Characters[($i + $Index) % $Characters.Count]
    $b = $Characters[($i + $Index + 1) % $Characters.Count]
    $place = $places[($i + $Index) % $places.Count]
    $object = $objects[($i + $Index) % $objects.Count]
    $verb = $verbs[($i + $Index) % $verbs.Count]
    $sense = $sensory[($i + $Index) % $sensory.Count]
    $mind = $psych[($i + $Index) % $psych.Count]
    $uniqueSlice = ($chapterTerms[($i * 5)..($i * 5 + 4)] -join " ")
    $paragraphs.Add(("{0}, {1} çevresinde {2} tuttu; {3} sesi, {4} ve {5} arasında ince bir çizgi gibi uzandı. {6} bunu görünce {7}, çünkü önceki ipucu artık yalnız bir işaret değil, yeni bir sonuçtu. {8}" -f $a, $place, $object, $sense, $mind, $psych[($i + 2) % $psych.Count], $b, $verb, $uniqueSlice))
    $paragraphs.Add(("- {0}, bu iz bizi aynı kapıya götürmüyor; yeni bir bilgi {1} ve eski kararımız değişti." -f $a, $verb))
    $paragraphs.Add(("- {0}, defteri saklamayacağım. Yağmur, sokak ve bu soğuk taş bize kimin yalan söylediğini gösterdi." -f $b))
    $paragraphs.Add(("{0} cevap vermeden {1} aldı, sonra merdivene yöneldi. {2}, uzaktan gelen tramvay sesiyle birlikte {3}; açıklanan sır herkesin yerini değiştirdi." -f $a, $object, $Characters[($i + $Index + 2) % $Characters.Count], $verb))
  }
  $paragraphs.Add(("{0}, son sayfayı kapatırken {1} için yeni bir bağ kurdu: alınan şey geri verilecek, söylenen söz sınanacak, kapalı kapı bir sonraki bölümde açılacaktı." -f $Characters[0], $Characters[3]))
  return ($paragraphs -join "`n`n")
}

$projectsRoot = Join-Path $RepoRoot ".tmp/production-sample-export"
$projectRoot = Join-Path $projectsRoot "sisli-defterler-production"
$manualConfig = Join-Path $projectRoot "runtime/runner-config.ide-manual.json"
$createdDocx = $null
$keep = [bool]$KeepOutputDirectory

try {
  if (Test-Path -LiteralPath $projectsRoot) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/new_project.ps1"), "-Name", "Sisli Defterler Production", "-ProjectsRoot", $projectsRoot, "-Force") | Out-Null
  Copy-Item -LiteralPath (Join-Path $RepoRoot "runtime/runner-config.ide-manual.template.json") -Destination $manualConfig -Force

  Write-Utf8BomText -Path (Join-Path $projectRoot "runtime/book-request.md") -Value @'
Kitap Adı: Sisli Defterler
Tür: Tarihi Gerilim / Casusluk Romanı
Hedef Uzunluk: 45 sayfa
Karakter Sayısı: 6 ana karakter
Konu: 1930'lar İstanbul'unda Pera Palas'ta başlayan bir dosya, Galata ve Dolmabahçe hattında eski bir istihbarat ağını ortaya çıkarır.
'@

  foreach ($phase in @("intake")) {
    Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", $phase, "-ToPhase", $phase) | Out-Null
  }

  $briefApprovalPath = Join-Path $projectRoot "runtime/approvals/book-brief-approval.json"
  $briefApproval = Read-Utf8Json -Path $briefApprovalPath
  $briefApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $briefApproval | Add-Member -NotePropertyName accepted_answers -NotePropertyValue ([ordered]@{
    writing_type = "novel"
    premise = "1930'lar İstanbul'unda Pera Palas'ta başlayan bir dosya, Galata ve Dolmabahçe hattında eski bir istihbarat ağını ortaya çıkarır."
    target_length = "45 sayfa"
    target_pages = "45"
    target_reader = "Yetişkin roman okuru"
    genre = "tarihi gerilim"
    character_policy = "6 ana karakter"
    setting_period = "1930'lar İstanbul"
    pov_tense = "Üçüncü tekil, geçmiş zaman"
    style_tone = "Edebi, atmosferik, kontrollü gerilim"
    boundaries = "Teknik etiket yok, sahte alıntı yok, tekrar yok"
    publication_package = "A5 DOCX, kapak briefi, önsöz, içindekiler, künye"
  }) -Force
  Write-Utf8BomJson -Path $briefApprovalPath -Value $briefApproval

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "propose", "-ToPhase", "propose") | Out-Null
  $storyChoicePath = Join-Path $projectRoot "runtime/approvals/story-choice.json"
  $storyChoice = Read-Utf8Json -Path $storyChoicePath
  $storyChoice | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $storyChoice | Add-Member -NotePropertyName selected_option -NotePropertyValue 1 -Force
  Write-Utf8BomJson -Path $storyChoicePath -Value $storyChoice

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-big", "-ToPhase", "design-big") | Out-Null
  $bookPlanApprovalPath = Join-Path $projectRoot "runtime/approvals/book-plan-approval.json"
  $bookPlanApproval = Read-Utf8Json -Path $bookPlanApprovalPath
  $bookPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/book-plan.json")
  $longformPlan = Read-Utf8Json -Path (Join-Path $projectRoot "revision/_state/longform-plan.json")
  if ([string]$bookPlan.title_working -ne "Sisli Defterler") {
    throw "Production sample lost explicit user title. Expected 'Sisli Defterler', found '$($bookPlan.title_working)'."
  }
  $bookPlanApproval | Add-Member -NotePropertyName approved -NotePropertyValue $true -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_writing_type -NotePropertyValue ([string]$bookPlan.writing_type) -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_genre -NotePropertyValue ([string]$bookPlan.genre) -Force
  $bookPlanApproval | Add-Member -NotePropertyName accepted_targets -NotePropertyValue ([ordered]@{
    target_pages = [int]$longformPlan.target_pages
    target_words = [int]$longformPlan.target_words
    target_chapters = [int]$longformPlan.target_chapters
  }) -Force
  Write-Utf8BomJson -Path $bookPlanApprovalPath -Value $bookPlanApproval
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "design-small", "-ToPhase", "design-small") | Out-Null

  Write-Utf8BomJson -Path (Join-Path $projectRoot "runtime/approvals/design-freeze.json") -Value ([ordered]@{ approved = $true; approved_by = "production_sample_export_test"; note = "Approved design for production sample validation." })

  $characters = @($bookPlan.characters | ForEach-Object { [string]$_.name } | Where-Object { $_ })
  if ($characters.Count -lt 6) {
    $characters = @("Münevver", "Selim", "Nermin", "Kemal", "Eleni", "Rauf")
  }
  $titles = @("Mermerdeki İz", "Tepebaşı'nda Yağmur", "Galata Defteri", "Dolmabahçe Gölgesi", "Sarnıçtaki Ses", "Kayıp Mühür", "Karaköy'de İtiraf", "Sis Çekilirken")
  $episodeRels = @()
  for ($i = 1; $i -le 8; $i++) {
    $rel = "episode/ep{0:D3}.md" -f $i
    $episodeRels += $rel
    Write-Utf8BomText -Path (Join-Path $projectRoot $rel) -Value (New-ChapterText -Index $i -Title $titles[$i - 1] -Characters $characters)
  }

  $work = Join-Path $projectRoot "revision/_workspace"
  $state = Join-Path $projectRoot "revision/_state"
  New-Item -ItemType Directory -Path $work -Force | Out-Null
  Write-Utf8BomText -Path (Join-Path $work "04_quality-verifier_verdict_EP001-EP008.md") -Value "# Quality Verifier`n`nVERDICT: PASS`n`nEight chapters were reviewed for progression, chapter distinction, dash dialogue, Turkish characters, and continuity state updates."
  Write-Utf8BomJson -Path (Join-Path $work "08_tdk-polisher_issues_EP001-EP008.json") -Value ([ordered]@{ run_id = "production-sample"; phase = "create"; verdict = "PASS"; issues = @(); checked = @("encoding", "diacritics", "technical-labels") })
  Write-Utf8BomJson -Path (Join-Path $work "create_editorial-cycle_EP001-EP008.json") -Value ([ordered]@{
    run_id = "production-sample"
    step_id = "create-editorial-cycle"
    phase = "create"
    writing_type = "novel"
    verdict = "PASS"
    threshold_pass = 85
    scores = [ordered]@{ continuity = 90; progression = 90; "character_or_argument_depth" = 88; style = 89; language = 92; layout = 88; "publication-readiness" = 87; "type-fit" = 90 }
    issue_summary = [ordered]@{ critical = 0; major = 0; minor = 1; manual_review_required = $false }
    required_fixes = @()
    next_action = "continue"
    reviewed_artifacts = $episodeRels
  })
  foreach ($marker in @("EP005")) {
    Write-Utf8BomJson -Path (Join-Path $work "macro-continuity-audit_$marker.json") -Value ([ordered]@{
      run_id = "production-sample"
      through_chapter = $marker
      verdict = "PASS"
      checked_ledgers = @("character-state.json", "plot-ledger.json", "chapter-summaries.json", "continuity-ledger.json", "world-state.json", "relationship-graph.json", "knowledge-graph.json", "promise-payoff-ledger.json", "timeline.json", "theme-ledger.json")
      open_risks = @()
      required_fixes = @()
    })
    Write-Utf8BomText -Path (Join-Path $work "macro-continuity-audit_$marker.md") -Value "# Macro Continuity Audit $marker`n`nVERDICT: PASS`n"
  }

  $chapterSummaries = Read-Utf8Json -Path (Join-Path $state "chapter-summaries.json")
  $chapterSummaries.chapters = @()
  $previousLink = "Açılışta lacivert defter Münevver'i Pera Palas merdivenlerine çağırır."
  for ($i = 1; $i -le 8; $i++) {
    $nextLink = ("Ağın {0}. halkası öğrenildiği için {1} yeni eşiğe yönelir." -f $i, $characters[($i - 1) % $characters.Count])
    $chapterSummaries.chapters += [ordered]@{ id = ("EP{0:D3}" -f $i); summary = $titles[$i - 1]; previous_chapter_result = $previousLink; new_event = ("Yeni dosya parçası {0}. eşikte ortaya çıktı." -f $i); new_information = ("Ağın {0}. halkası öğrenildi." -f $i); irreversible_change = ("Karakterlerin bilgi dengesi {0}. bölüm sonunda geri dönülmez biçimde değişti." -f $i); next_causal_link = $nextLink; state_updates = @("character-state", "plot-ledger", "continuity-ledger") }
    $previousLink = $nextLink
  }
  Write-Utf8BomJson -Path (Join-Path $state "chapter-summaries.json") -Value $chapterSummaries
  $plotLedger = Read-Utf8Json -Path (Join-Path $state "plot-ledger.json")
  $plotLedger.cause_effect_chain = @()
  for ($i = 1; $i -le 8; $i++) {
    $plotLedger.cause_effect_chain += [ordered]@{
      cause = ("EP{0:D3} içinde bulunan iz karakterleri yeni karar almaya zorlar." -f $i)
      effect = ("EP{0:D3} sonunda ağın {1}. halkası açılır ve sonraki bölümün yönü değişir." -f $i, $i)
    }
  }
  Write-Utf8BomJson -Path (Join-Path $state "plot-ledger.json") -Value $plotLedger
  $outputArtifacts = @($episodeRels + @(
    "revision/_workspace/04_quality-verifier_verdict_EP001-EP008.md",
    "revision/_workspace/08_tdk-polisher_issues_EP001-EP008.json",
    "revision/_workspace/create_editorial-cycle_EP001-EP008.json",
    "revision/_workspace/macro-continuity-audit_EP005.json",
    "revision/_workspace/macro-continuity-audit_EP005.md",
    "revision/_state/chapter-summaries.json"
  ))
  $chiefReportRel = "runtime/agent-compliance/chief-editor-orchestrator_report_create.md"
  $chiefVerdictRel = "runtime/agent-compliance/chief-editor-orchestrator_verdict_create.json"
  Write-Utf8BomText -Path (Join-Path $projectRoot $chiefReportRel) -Value "# Chief Editor Orchestrator`n`nVERDICT: PASS`n"
  Write-Utf8BomJson -Path (Join-Path $projectRoot $chiefVerdictRel) -Value ([ordered]@{ run_id = "production-sample"; phase = "create"; agent = "chief-editor-orchestrator"; verdict = "PASS"; checked_output_artifacts = $outputArtifacts })
  $outputArtifacts += @($chiefReportRel, $chiefVerdictRel)
  Invoke-CheckedPowerShell -Arguments @(
    "-ExecutionPolicy", "Bypass",
    "-File", (Join-Path $RepoRoot "scripts/ci/write_agent_compliance.ps1"),
    "-ProjectRoot", $projectRoot,
    "-Phase", "create",
    "-RunId", "production-sample",
    "-RequiredAgents", "episode-creator",
    "-RequiredReferences", "skills/create/SKILL.md",
    "-LoadedStateFiles", "revision/_state/book-plan.json",
    "-OutputArtifacts", ($outputArtifacts -join ","),
    "-AgentEvidence", "chief-editor-orchestrator=$chiefReportRel|$chiefVerdictRel",
    "-PhaseAuthority", "manual_ide_agent"
  ) | Out-Null

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", $manualConfig, "-Mode", "manual", "-NoWait", "-FromPhase", "create", "-ToPhase", "create") | Out-Null

  Write-Utf8BomText -Path (Join-Path $work "11_front-matter_title-page.md") -Value "# Sisli Defterler`n`nTarihi gerilim romanı`n`nYazar: Kullanıcı tarafından belirlenecek"
  Write-Utf8BomText -Path (Join-Path $work "11_front-matter_copyright-page.md") -Value "Telif ve yayın bilgileri kullanıcı ve yayıncı tarafından kesinleştirilecektir. Bu dosyada sahte ISBN, barkod veya bandrol değeri yoktur."
  Write-Utf8BomText -Path (Join-Path $work "11_front-matter_preface.md") -Value "Bu roman, sisli bir İstanbul atmosferinde hafıza, sadakat ve saklı dosyaların açtığı vicdan hesaplaşmasını izler."
  Write-Utf8BomJson -Path (Join-Path $work "11_front-matter_publication-metadata.json") -Value ([ordered]@{ title = "Sisli Defterler"; author_or_editor = "Kullanıcı"; copyright_owner = "Kullanıcı"; publication_year = "2026"; format = "A5 DOCX"; metadata_status = "draft_user_review" })
  Write-Utf8BomJson -Path (Join-Path $work "11_front-matter_toc.json") -Value ([ordered]@{ chapters = @() })
  Write-Utf8BomJson -Path (Join-Path $work "12_cover-design_manifest.json") -Value ([ordered]@{ title = "Sisli Defterler"; status = "brief_only"; print_ready = $false })
  Write-Utf8BomText -Path (Join-Path $work "12_cover-design_brief.md") -Value "Kapak, 1930'lar İstanbul'unu, Pera Palas mermerlerini, yağmurla parlayan tramvay hattını ve lacivert bir defteri merkezde göstermelidir."
  Write-Utf8BomText -Path (Join-Path $work "12_cover-design_front-prompt.md") -Value "A5 roman kapağı; sisli İstanbul, Pera Palas atmosferi, lacivert defter, tarihi gerilim tonu, sade ve ciddi tipografi."
  Write-Utf8BomText -Path (Join-Path $work "12_cover-design_back-cover-copy.md") -Value "Münevver, Pera Palas'ta eline geçen lacivert defterin yalnız bir hatıra olmadığını anladığında İstanbul'un sisli sokakları eski bir istihbarat ağını yeniden uyandırır."
  Write-Utf8BomJson -Path (Join-Path $projectRoot "runtime/approvals/export-approval.json") -Value ([ordered]@{ approved = $true; approved_by = "production_sample_export_test"; note = "Export sample approved." })

  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $projectRoot "scripts/run_pipeline.ps1"), "-ProjectRoot", $projectRoot, "-ConfigPath", (Join-Path $projectRoot "runtime/runner-config.json"), "-FromPhase", "export", "-ToPhase", "export") | Out-Null
  $manifest = Get-ChildItem -LiteralPath (Join-Path $projectRoot "revision/_workspace") -Filter "10_export-word_manifest_EP*.json" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $manifest) { throw "Production sample export manifest missing." }
  $exportManifest = Read-Utf8Json -Path $manifest.FullName
  $createdDocx = Join-Path $projectRoot ([string]$exportManifest.output_docx_path)
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_integrity.ps1"), "-DocxPath", $createdDocx, "-MinSizeBytes", "512") | Out-Null
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_content_match.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifest.FullName) | Out-Null
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_reader_clean.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifest.FullName) | Out-Null
  Invoke-CheckedPowerShell -Arguments @("-ExecutionPolicy", "Bypass", "-File", (Join-Path $RepoRoot "scripts/ci/verify_docx_layout_profile.ps1"), "-ProjectRoot", $projectRoot, "-ManifestPath", $manifest.FullName) | Out-Null
  if ($KeepOutputDirectory) {
    New-Item -ItemType Directory -Path $KeepOutputDirectory -Force | Out-Null
    Copy-Item -LiteralPath $createdDocx -Destination (Join-Path $KeepOutputDirectory "Sisli Defterler Production_EP001-EP008.docx") -Force
    Copy-Item -LiteralPath $manifest.FullName -Destination (Join-Path $KeepOutputDirectory "Sisli Defterler Production_manifest.json") -Force
  }

  Write-Host "[production-sample-export-test] PASS"
  Write-Host "docx=$createdDocx"
}
finally {
  if (-not $keep -and (Test-Path -LiteralPath $projectsRoot)) {
    Remove-Item -LiteralPath $projectsRoot -Recurse -Force
  }
}
