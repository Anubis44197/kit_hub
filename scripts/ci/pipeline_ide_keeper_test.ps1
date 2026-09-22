# CI: IDE (manual) modunda defter doldurucu kancasinin fonksiyonel testi.
# Gercek run_pipeline.ps1 -FromPhase create -ToPhase create -Mode manual -NoWait kosulur.
# Kanitlar:
#   1) pipeline PASS (tum faz kapilari: compliance, state reducers, longform state, tasarim hash'i)
#   2) pipeline ciktisi keeper raporunu tasiyor (kanca manual faz sonrasi GERCEKTEN kosuldu;
#      deterministiklik icin model env temizlenir -> keeper fail-open olur, log satiri kanittir)
#   3) -ResponseJson ile ayni zeminde keeper kosusu: plot-ledger + character-state guncellenir
#   4) dokunulmayan karakter bozulmaz
#   5) keeper'in yazdigi defterler icin design-hashes.json kayitlari tazelenir (tasarim tabani gecerli kalir)
param(
  [string]$ProjectRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
)
$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$engineRoot = $ProjectRoot  # dot-source edilen betiklerin param blogu $ProjectRoot'u ezebilir; motor yolu ayri tutulur
$testRoot = Join-Path $ProjectRoot "_workspace/pipeline-ide-keeper-test"

function Write-JsonFile([string]$rel, $obj) {
  $path = Join-Path $testRoot $rel
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 20), $utf8Bom)
}
function Write-TextFile([string]$rel, [string]$content) {
  $path = Join-Path $testRoot $rel
  $dir = Split-Path -Parent $path
  if ($dir -and -not (Test-Path -LiteralPath $dir -PathType Container)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $utf8Bom = New-Object System.Text.UTF8Encoding($true)
  [System.IO.File]::WriteAllText($path, $content, $utf8Bom)
}
function Get-Sha256([string]$rel) {
  $path = Join-Path $testRoot $rel
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $stream = [System.IO.File]::OpenRead($path); try { return (($sha.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join "") } finally { $stream.Dispose() } }
  finally { $sha.Dispose() }
}

# Temiz baslangic
if (Test-Path $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $testRoot "runtime") -Force | Out-Null

# 1) Proje marker
Write-JsonFile ".kithub-project.json" ([ordered]@{ schema_version = "1.0.0"; project_name = "Pipeline Keeper Test"; project_slug = "pipeline-keeper-test"; project_root = $testRoot; status = "draft" })

# 2) novel-config: metin kalite esiklerini test metnine gore gevset
Write-TextFile "novel-config.md" (@"
min_characters: 200
max_characters: 20000
dialogue_ratio_min: 0.0
dialogue_ratio_max: 1.0
target_genre: dram
chapter_range: EP001-EP002
"@)

# 3) create fazinin zorunlu tasarim artifact'i
Write-TextFile "design/EP001-EP002_scene_plan.md" "# Scene Plan`n`nEP001: Deniz kulenin gergesinde saklanir, gece gemiye ulasir.`nEP002: Deniz limanda Mira ile bulusur, gemi denize acilir.`n"

# 4) revision/_state defterleri (tum kapilarin istedigi tam semalar)
Write-JsonFile "revision/_state/book-plan.json" ([ordered]@{
  schema_version = "1.1.0"; run_id = "run-planning"; plan_id = "plan-001"; source_prompt = "test"; approved_story_option = "1"
  title_working = "Kulenin Gergesi"; writing_type = "roman"; genre = "dram"; theme = "dayaniklilik"; premise = "Bir saat ustasinin ogrencisi kayip bir mektubun pesine duser."
  scale_tier = "standard"; target_pages = 100; target_words = 50000; narrative_pov = "ucuncu-kisi"; tense = "gecmis"
  characters = @([ordered]@{ role = "protagonist"; name = "Deniz"; desire = "gemiye ulasmak"; fear = "yakalanmak"; arc = "kacaktan sorumluluga" })
  plot_arc = [ordered]@{ opening_promise = "Mektup bulunur"; inciting_incident = "Kule kusatilir"; midpoint_turn = "Mira ile ittifak"; climax = "Liman kacisi"; resolution = "Denize acilis" }
  chapter_count = 2; max_chapters_per_batch = 1; audit_interval_chapters = 1; approval_required = $true
})
Write-JsonFile "revision/_state/longform-plan.json" ([ordered]@{
  schema_version = "1.1.0"; run_id = "run-planning"; target_pages = 100; target_words = 50000; target_chapters = 2
  chapters = @([ordered]@{ id = "EP001" }, [ordered]@{ id = "EP002" })
  required_state_files = @("revision/_state/world-state.json","revision/_state/relationship-graph.json","revision/_state/knowledge-graph.json","revision/_state/promise-payoff-ledger.json","revision/_state/timeline.json","revision/_state/theme-ledger.json","revision/_state/volume-plan.json")
  scale_tier = "standard"; structure_model = "three-act"; max_chapters_per_batch = 1; audit_interval_chapters = 1; continuity_model = "ledger"
})
Write-JsonFile "revision/_state/chapter-plan.json" ([ordered]@{
  schema_version = "1.1.0"; run_id = "run-planning"
  chapters = @(
    [ordered]@{ id = "EP001"; reader_title = "Kulenin Gergesi"; purpose = "kacis"; events = @("Mektup bulunur", "Kule kusatilir"); character_focus = @("Deniz"); continuity_promises = @("mektubun icerigi"); target_words = 1000 },
    [ordered]@{ id = "EP002"; reader_title = "Liman Sabahi"; purpose = "ittifak"; events = @("Mira ile bulusma", "Gemi kalkisi"); character_focus = @("Deniz","Mira"); continuity_promises = @("mektubun icerigi"); target_words = 1000 }
  )
})
Write-JsonFile "revision/_state/character-state.json" ([ordered]@{ schema_version = "1.1.0"; run_id = "run-planning"; characters = @(
  [ordered]@{ name = "Deniz"; location = "kule-golgesi"; condition = "yarali" },
  [ordered]@{ name = "Mira"; location = "liman"; condition = "saglikli" }
) })
Write-JsonFile "revision/_state/plot-ledger.json" ([ordered]@{
  schema_version = "1.1.0"; run_id = "run-planning"
  main_question = "Deniz kacaktan sorumluluga gecebilecek mi?"
  open_threads = @("mektubun icerigi"); closed_threads = @("kulenin kusatilmasi"); final_promises = @("mektubun icerigi acilacak")
  cause_effect_chain = @("Mektup bulundu, kule kusatildi")
  events = @([ordered]@{ summary = "Mektup bulundu ve kule kusatildi"; run_id = "run-planning" })
})
Write-JsonFile "revision/_state/chapter-summaries.json" ([ordered]@{ chapters = @([ordered]@{ id = "EP001"; summary = "Deniz kuleden kacar ve gemiye ulasir."; irreversible_change = "Kule terk edildi" }) })
Write-JsonFile "revision/_state/continuity-ledger.json" ([ordered]@{ violations = @() })
Write-JsonFile "revision/_state/world-state.json" ([ordered]@{ locations = @("kule","liman"); time_rules = @("gece-gunduz"); objects = @("mektup","tekne"); world_constraints = @("kusatma") })
Write-JsonFile "revision/_state/relationship-graph.json" ([ordered]@{ nodes = @("Deniz","Mira"); edges = @("ittifak"); change_log = @(); rule = "degisimler loglanir" })
Write-JsonFile "revision/_state/knowledge-graph.json" ([ordered]@{ character_knowledge = @("Deniz mektubu bilir"); secrets = @("mektubun icerigi"); rule = "sirlar koruyucu" })
Write-JsonFile "revision/_state/promise-payoff-ledger.json" ([ordered]@{ open_promises = @("mektubun icerigi"); paid_promises = @(); abandoned_promises = @(); rule = "vaatler odenir" })
Write-JsonFile "revision/_state/timeline.json" ([ordered]@{ chronology = @("gunduz","gece"); chapter_time_map = @(); rule = "kronoloji korunur" })
Write-JsonFile "revision/_state/theme-ledger.json" ([ordered]@{ primary_theme = "dayaniklilik"; motifs = @("kule","deniz"); theme_progression = @(); rule = "tema izlenir" })
Write-JsonFile "revision/_state/volume-plan.json" ([ordered]@{
  scale_tier = "standard"; target_pages = 100; target_words = 50000; target_chapters = 2; words_per_page_estimate = 500
  words_per_chapter = 25000; max_chapters_per_batch = 1; audit_interval_chapters = 1
  acts = @("kurulum","cozum"); audit_schedule = @(); rule = "hedeflerle uyumlu"
})
Write-JsonFile "revision/_state/style-profile.json" ([ordered]@{ profile = "edebi"; narration = "ucuncu-kisi"; dialogue_policy = "cizgili"; print_format = "5x8" })
Write-JsonFile "revision/_state/writing-type-profile.json" ([ordered]@{ writing_type = "roman"; target_reader = "yetiskin"; structure_model = "three-act"; voice_model = "yakin-ucuncu"; evidence_policy = "ic-kanit"; continuity_policy = "defter-zorunlu"; completion_criteria = "kapilar-gecer" })
Write-JsonFile "revision/_state/genre-structure-template.json" ([ordered]@{ template_id = "dram-standart"; acts = @("kurulum","cozum"); chapter_rules = @("olay-zinciri"); mandatory_ledgers = @("plot-ledger","character-state") })
Write-JsonFile "revision/_state/editorial-quality-scorecard.json" ([ordered]@{ threshold_pass = 80; axes = @("tutarlilik","akis"); export_blockers = @() })
Write-JsonFile "revision/_state/llm-adapter-contract.json" ([ordered]@{ adapter_contract = "state-only"; max_chapters_per_batch = 1; required_input_state = @(); required_output_state = @() })
Write-JsonFile "revision/_state/layout-plan.json" ([ordered]@{
  schema_version = "1.1.0"; run_id = "run-planning"; book_template = "roman"; book_template_label = "Roman"
  delivery_profiles = [ordered]@{ publisher_submission = [ordered]@{}; print_preview = [ordered]@{} }
  trim_size = "5x8"; width_mm = 127; height_mm = 203
  margin_top_mm = 20; margin_bottom_mm = 20; margin_inside_mm = 18; margin_outside_mm = 15
  font_family = "Georgia"; font_size_pt = 11; line_spacing = 1.15; paragraph_first_line_indent_cm = 0.5
  words_per_page_estimate = 500; target_pages = 100; target_words = 50000; target_chapters = 2
  scale_tier = "standard"; max_chapters_per_batch = 1; audit_interval_chapters = 1
  front_matter_pages_estimate = 6; back_matter_pages_estimate = 2; chapter_start_policy = "new-page"
})
Write-JsonFile "revision/_state/create-plan.json" ([ordered]@{
  schema_version = "1.1.0"; run_id = "run-planning"; plan_id = "create-001"; status = "active"; chapter_count = 2; max_chapters_per_batch = 1
  retry_policy = [ordered]@{ max_retries_per_chapter = 1 }
  chapters = @(
    [ordered]@{ id = "EP001"; reader_title = "Kulenin Gergesi"; target_words = 1000; min_words = 700; max_words = 1500; status = "drafted"; attempts = 1; required_before_pass = @("episode text","tdk-polisher","tdk-layout-agent","quality-verifier","chapter-summaries update") },
    [ordered]@{ id = "EP002"; reader_title = "Liman Sabahi"; target_words = 1000; min_words = 700; max_words = 1500; status = "pending"; attempts = 0; required_before_pass = @("episode text","tdk-polisher","tdk-layout-agent","quality-verifier","chapter-summaries update") }
  )
})

# 5) design-hashes.json: kilitli tasarim tabani (gercek hash'lerle; >=10 kaynak)
$hashRels = @(
  "novel-config.md",
  "revision/_state/book-plan.json",
  "revision/_state/chapter-plan.json",
  "revision/_state/layout-plan.json",
  "revision/_state/longform-plan.json",
  "revision/_state/character-state.json",
  "revision/_state/plot-ledger.json",
  "revision/_state/style-profile.json",
  "revision/_state/create-plan.json",
  "revision/_state/genre-structure-template.json"
)
$hashSources = @()
foreach ($rel in $hashRels) { $hashSources += [ordered]@{ path = $rel; sha256 = Get-Sha256 $rel } }
Write-JsonFile "revision/_state/design-hashes.json" ([ordered]@{
  schema_version = "1.0.0"; run_id = "run-planning"; plan_id = "plan-001"; hash_scope = "approved_design_baseline"
  sources = $hashSources
  rewrite_policy = "If any source hash changes after design-freeze, rewrite must emit a rewrite impact report."
})

# 6) Bolum metni (ASCII temiz; yasak desen yok; mojibake yok; min_words=700 ustunde)
$sentences = @(
  "Deniz kulenin gergesinde nefesini tuttu."
  "Kusatma sabahtan beri suruyordu ve tek yol gece karanliginda kayaliklardan inmekti."
  "Yarasi sol kolunda atesi yukseltiyordu ama durmasi olumdemendi."
  "Yarim ay bulutlarin arkasindan cikinca kayaliklara indi."
  "Taslar buz gibiydi ve her adimda bir ayakkabi sesi butun vadiye yayilacak gibi geliyordu."
  "Tekneye ulastiginda elleri titriyordu; kurekleri savururken omuzlarindaki yara yeniden acildi."
  "Liman isiklari doguda belirince bir an durakladi: rantiyeci Kemal'in adamlari iskelede dolasiyordu."
  "Fenerin isiginda Mira'nin yuzu gorundu ve Deniz'in bogazini dizen node bir anda bosaldi."
  "Konusmadilar; konusmaya gerek yoktu."
  "Mira halati cozdu, deniz yolculugu basladi."
  "Kuleyi son kez gordu; arkasinda biraktigi her sey simdi sadece bir hatiraydi."
  "Ruzgar sertlestikce tekne doguya yattikca Deniz ilk kez baska bir sey hissetti: korkunun yeri baska bir duyguyla dolmustu."
  "Deniz kulenin gergesinde nefesini tuttugunda kusatmanin ucuncu saatidir ve kayaliklar hala uzakta gorunuyordu."
  "Sol kolundaki yara bandajiye ragmen kanamayi surduruyordu ama bu dusunceyi kenara itti."
  "Gece ruzgarinin soguk nefesi ense dibinde dolaniyor, yildizlar bulut arasinda sikisip kaliyordu."
  "Kayaliklara inen patikayi daha once sadece cobanlar kullanirdi ve bu dusunce ona garip bir cesaret verdi."
  "Her tas parcasini ayagina takilmadan asarak ilerledi; nefesi buhar buzhar agzindan cikiyordu."
  "Teknenin kurek yuvasi curumustu ama halat saglamdi ve bu onun icin yeterliydi."
  "Suya uzanip halati cogaltdiginda parmaklari uyuadi ama denizin serinligi yarasinin atesini dindirdi."
  "Kemal'in adamlari iskelede fenerlerle geziniyor, her golgeyi tek tek aydinlatiyordu."
  "Mira sessizce yanina geldi ve eliyle guneyi gosterdi."
  "Iki kelime konusmadan anlastilar: acik deniz, kuzey ruzgari, kucuk bir tekne."
  "Deniz kuleye donup baktiginda kusatmacilarin ateslerini yakmakta oldugunu gordu."
  "O atesler onun icin artik bir tehdit degil, biraktigi hayatin mezar taslariydi."
  "Tekne liman agzindan ciktiginda ruzgar sertlesti ve yelken gerildi."
  "Mira basini kaldirip yildizlari saydi; saymak ona guven verdi."
  "Deniz'in omuzlarindaki yara sanci vurdukca vurdu ama o kurekleri savurmaktan vazgecmedi."
  "Acik denizin kokusu baska bir dunyanin kapisi gibiydi ve o kapidan iceri adim atiyorlardi."
  "Kulenin gergesinde tuttugu nefes simdi serbest hava olmustu."
  "Korku hala oradaydi ama artik yaninda baska seyler de tasiyordu."
  "Mira bir yorgan cikarip omuzlarina orttu; bu kucuk kibarlik onu beklenmedik olcude duygulandiardi."
  "Deniz uyumaya calismadi; uyku gelecek kadar guven degildi."
  "Sabahin ilk isigi ufukta gri bir cizgi olarak belirdiginde tekne hala ilerliyordu."
  "Ona dondu ve tek kelime etmeden gulumsetti; Mira bu gulumseyisi arkilikla karsiladi."
  "Yol uzun, hedef belirsiz ama yon kesindi: dogu."
  "Deniz kuleyi bir daha donup bakmadi."
)
$episodeText = (($sentences + $sentences) -join " ")
Write-TextFile "episode/ep001.md" $episodeText

# 7) create fazinin zorunlu raporlari
Write-TextFile "revision/_workspace/04_quality-verifier_verdict_EP001.md" (@"
VERDICT: PASS
Score: 92
Notes: Bolum kapilari gecti; metin tutarli.
Agent: quality-verifier
"@)
Write-JsonFile "revision/_workspace/08_tdk-polisher_issues_EP001.json" ([ordered]@{ issues = @(
  [ordered]@{ id = "TDK-001"; severity = "minor"; auto_fixable = $true; original = "kurekleri savurdu"; suggestion = "kurekleri savurdu" }
) })

# 8) Sozlesmeler (registry + status + create faz sozlesmesi) + governance ajan dosyalari
New-Item -ItemType Directory -Path (Join-Path $testRoot "agents") -Force | Out-Null
foreach ($agentName in @("episode-creator","quality-verifier","tdk-polisher")) {
  Copy-Item -LiteralPath (Join-Path $engineRoot "agents/$agentName.md") -Destination (Join-Path $testRoot "agents/$agentName.md") -Force
}
Copy-Item -LiteralPath (Join-Path $engineRoot "runtime/agent-compliance.schema.json") -Destination (Join-Path $testRoot "runtime/agent-compliance.schema.json") -Force
# Validate-StateReducers reducer betigini test projesi icinden cagirir — motor deposundan kopyala
New-Item -ItemType Directory -Path (Join-Path $testRoot "scripts/ci") -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $engineRoot "scripts/ci/validate_state_reducers.ps1") -Destination (Join-Path $testRoot "scripts/ci/validate_state_reducers.ps1") -Force
Write-JsonFile "runtime/agent-registry.json" ([ordered]@{
  schema_version = "1.0.0"; status_contract = "runtime/agent-status-contract.json"
  agents = @(
    [ordered]@{ name = "episode-creator"; allowed_phases = @("create"); required_references = @(); allowed_write_roots = @("episode/"); timeout_seconds = 600; max_turns = 10 },
    [ordered]@{ name = "quality-verifier"; allowed_phases = @("create","polish","rewrite"); required_references = @(); allowed_write_roots = @("revision/_workspace/"); timeout_seconds = 600; max_turns = 10 },
    [ordered]@{ name = "tdk-polisher"; allowed_phases = @("create","polish","rewrite"); required_references = @(); allowed_write_roots = @("revision/_workspace/"); timeout_seconds = 600; max_turns = 10 }
  )
})
Write-JsonFile "runtime/agent-status-contract.json" ([ordered]@{ schema_version = "1.0.0"; valid_status_values = @("completed","failed","blocked","timed_out","invalid_output") })
Write-JsonFile "runtime/phase-contracts/create.json" ([ordered]@{
  phase = "create"
  required_agents = @("episode-creator","quality-verifier","tdk-polisher")
  required_references = @(); required_state_files = @(); required_approvals = @()
  allowed_output_patterns = @("episode/ep*.md","revision/_workspace/*","revision/_state/*.json")
  denied_output_patterns = @()
  status_contract = "completed"
})

# 9) Onay kapilari (create: design-freeze + book-plan-approval approved=true)
Write-JsonFile "runtime/approvals/design-freeze.json" ([ordered]@{ approved = $true; approved_at = "2026-09-20T12:00:00.0000000Z" })
Write-JsonFile "runtime/approvals/book-plan-approval.json" ([ordered]@{ approved = $true; approved_at = "2026-09-20T12:00:00.0000000Z" })

# 10) Runner config: manual mod + gevsetilmis kalite kapilari
Write-JsonFile "runtime/runner-config.json" ([ordered]@{
  execution_mode = "manual"
  phase_commands = [ordered]@{}
  phase_prompts = [ordered]@{}
  quality_flags = [ordered]@{
    enable_dictionary_check = $false
    require_dictionary_provider = $false
    require_user_approvals = $true
    enforce_phase_contracts = $true
    enable_negative_enforcement = $true
    enable_text_quality_gates = $true
    require_executed_claims_for_critical_phases = $false
    enable_command_safety = $true
    enable_artifact_size_budget = $true
    max_text_artifact_bytes = 1500000
    approval_files = [ordered]@{ create = "runtime/approvals/design-freeze.json" }
    text_quality_gates = [ordered]@{
      max_duplicate_line_ratio = 1.0; max_repeated_paragraph_prefix = 99; paragraph_prefix_length = 95
      tell_sensory_ratio_max = 999.0; require_dash_dialogue = $false; forbid_mixed_dialogue_styles = $false; min_psychological_markers = 0
    }
    cross_chapter_gates = [ordered]@{ min_event_markers_per_chapter = 1 }
  }
})

# 11) IDE (manual) compliance manifesti — write_agent_compliance.ps1 in-session cagrilir
$compliancePath = Join-Path $testRoot "runtime/agent-compliance/create.json"
Push-Location $testRoot
try {
  . (Join-Path $engineRoot "scripts/ci/write_agent_compliance.ps1") -ProjectRoot $testRoot -Phase "create" -RunId "run-ide-keeper-test" `
    -RequiredAgents @("episode-creator","quality-verifier","tdk-polisher") `
    -OutputArtifacts @("episode/ep001.md","revision/_workspace/04_quality-verifier_verdict_EP001.md","revision/_workspace/08_tdk-polisher_issues_EP001.json") `
    -PhaseAuthority "manual_ide_agent" -ContractStatus "PASS"
} finally { Pop-Location }
if (-not (Test-Path $compliancePath)) { throw "IDE compliance manifesti yazilmadi." }

# 12) GERCEK pipeline kosusu (manuel mod, etkilesimsiz, deterministik: model env temiz)
foreach ($name in @("KITHUB_API_PROVIDER","KITHUB_API_MODEL","KITHUB_API_KEY","KITHUB_API_BASE_URL","KITHUB_API_ALLOW_EMPTY_KEY")) {
  Remove-Item "Env:$name" -ErrorAction SilentlyContinue
}
$output = & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $engineRoot "scripts/run_pipeline.ps1") `
  -ProjectRoot $testRoot -FromPhase create -ToPhase create -Mode manual -NoWait 2>&1
$exitCode = $LASTEXITCODE
$outText = ($output | Out-String)
if ($exitCode -ne 0) { throw "Pipeline FAIL (exit=$exitCode):`n$outText" }
Write-Host "[pipeline-keeper-test] 1. kanit OK (pipeline PASS, manual mod, tum kapilar)"

# 13) Kancanin gercekten kosuldugu kaniti: cikti keeper satiri tasiyor (fail-open deterministik)
if ($outText -notmatch "\[ledger-keeper\]") { throw "pipeline ciktisinda keeper raporu yok:`n$($outText.Substring(0, [Math]::Min(2000, $outText.Length)))" }
Write-Host "[pipeline-keeper-test] 2. kanit OK (kanca manual faz sonrasi kosuldu: $($outText | Select-String '\[ledger-keeper\]' | ForEach-Object { $_.Line.Trim() }))"

# 14) Deterministik defter yazimi: ayni zeminde -ResponseJson ile keeper kosusu
$resp = '{"character_updates":[{"name":"Deniz","location":"acik-deniz","condition":"iyilesiyor"}],"new_event":"Deniz kuleden kacip tekneyle limana ulasti","violations":[]}'
& (Join-Path $engineRoot "scripts/update_story_ledgers.ps1") -ProjectRoot $testRoot -RunId "run-ide-keeper-test" -Phase "create" -ResponseJson $resp | Out-Null
if ($LASTEXITCODE -ne 0) { throw "keeper exit 0 degil: $LASTEXITCODE" }
$plot = Get-Content (Join-Path $testRoot "revision/_state/plot-ledger.json") -Raw | ConvertFrom-Json
if (-not ($plot.PSObject.Properties.Name -contains "events") -or @($plot.events).Count -lt 2) { throw "plot-ledger olay almedi (count=$(@($plot.events).Count))" }
if (@($plot.events)[-1].summary -notmatch "Deniz kuleden kacip") { throw "olay ozeti hatali" }
$chars = Get-Content (Join-Path $testRoot "revision/_state/character-state.json") -Raw | ConvertFrom-Json
$deniz = @(@($chars.characters) | Where-Object { $_.name -eq "Deniz" })[0]
if ($deniz.location -ne "acik-deniz") { throw "karakter konumu guncellenmedi: $($deniz.location)" }
if (@(@($chars.characters) | Where-Object { $_.name -eq "Mira" })[0].location -ne "liman") { throw "dokunulmayan karakter bozuldu" }
Write-Host "[pipeline-keeper-test] 3-4. kanit OK (defterler IDE modu zeminden guncellendi, dokunulmayan korundu)"

# 15) Design-hash tazeleme kaniti: keeper'in yazdigi character-state hash'i tabanda gecerli olmali
$dh = Get-Content (Join-Path $testRoot "revision/_state/design-hashes.json") -Raw | ConvertFrom-Json
$csEntry = @(@($dh.sources) | Where-Object { ([string]$_.path) -eq "revision/_state/character-state.json" })[0]
$actual = Get-Sha256 "revision/_state/character-state.json"
if ([string]$csEntry.sha256 -ne $actual) { throw "design-hash tazelenmedi: taban=$($csEntry.sha256) gercek=$actual" }
Write-Host "[pipeline-keeper-test] 5. kanit OK (design-hashes keeper sonrasi gecerli)"

# Temizlik
Remove-Item -LiteralPath $testRoot -Recurse -Force
Write-Host "[pipeline-keeper-test] PASS"
exit 0
