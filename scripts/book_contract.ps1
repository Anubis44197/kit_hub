function Get-KitHubBookRequestField {
  param([string]$Text, [string[]]$Labels)
  foreach ($label in $Labels) {
    $escaped = [regex]::Escape($label)
    $pattern = "(?im)^\s*-\s*$escaped(?:[ \t]*/[^\r\n:]*)?[ \t]*:[ \t]*(.+?)\s*$"
    $match = [regex]::Match($Text, $pattern)
    if ($match.Success) { return $match.Groups[1].Value.Trim() }
  }
  return ""
}

function Get-KitHubBookRequestFieldByPattern {
  param([string]$Text, [string]$Pattern)
  $match = [regex]::Match($Text, $Pattern)
  if ($match.Success) { return $match.Groups[1].Value.Trim() }
  return ""
}

function Get-KitHubWritingFamily {
  param([string]$WritingType)
  $normalized = $WritingType.Trim()
  $fiction = @("Roman","Hikaye","Novella","Genç yetişkin","Fantastik kurgu","Bilimkurgu","Gizem / Gerilim","Romantik kurgu","Tarihi kurgu","Çocuk kitabı")
  $nonfiction = @("Biyografi","Anı","Deneme","Kişisel gelişim","İş kitabı","Gezi yazısı")
  $research = @("Araştırma kitabı")
  $academic = @("Akademik metin","Tez / Bitirme çalışması")
  $article = @("Makale","Blog yazısı")
  $instructional = @("Ders kitabı","Eğitim içeriği","Kullanım kılavuzu","Teknik doküman")
  $report = @("Rapor","Whitepaper")
  if ($fiction -contains $normalized) { return "fiction" }
  if ($nonfiction -contains $normalized) { return "nonfiction" }
  if ($research -contains $normalized) { return "research" }
  if ($academic -contains $normalized) { return "academic" }
  if ($article -contains $normalized) { return "article" }
  if ($instructional -contains $normalized) { return "instructional" }
  if ($report -contains $normalized) { return "report" }
  if ($normalized -eq "Senaryo") { return "screenplay" }
  if ($normalized -eq "Şiir kitabı") { return "poetry" }
  return "fiction"
}

function Get-KitHubWritingContractFromText {
  param([string]$Text, [string]$RunId = "")
  $writingType = Get-KitHubBookRequestField -Text $Text -Labels @("Tür", "Tur", "Yazı türü", "Yazi turu")
  if (-not $writingType) { $writingType = Get-KitHubBookRequestFieldByPattern -Text $Text -Pattern "(?im)^\s*-\s*T.{0,4}r\s*:\s*(.+?)\s*$" }
  $family = Get-KitHubWritingFamily -WritingType $writingType
  $familyLine = Get-KitHubBookRequestFieldByPattern -Text $Text -Pattern "(?im)^\s*-\s*T.{0,4}r ailesi\s*:\s*(.+?)\s*$"
  if ($familyLine -match "(?i)rapor|whitepaper") { $family = "report" }
  elseif ($familyLine -match "(?i)akademik|tez") { $family = "academic" }
  elseif ($familyLine -match "(?i)blog|makale") { $family = "article" }
  elseif ($familyLine -match "(?i)eğitim|egitim|rehber|ders") { $family = "instructional" }
  elseif ($familyLine -match "(?i)senaryo") { $family = "screenplay" }
  elseif ($familyLine -match "(?i)şiir|siir") { $family = "poetry" }
  $profiles = @{
    fiction = @{ title = "Kurgu şablonu"; planning = "Karakter, olay örgüsü, mekân, anlatıcı, final ve bölüm ritmi birlikte planlanır."; rule = "Kurgu öğeleri karakter, olay örgüsü, sahne ve final üzerinden kurulacak."; artifacts = @("character-state.json","plot-ledger.json","chapter-plan.json","continuity-ledger.json") }
    nonfiction = @{ title = "Kurgu dışı şablon"; planning = "Ana tez, okur vaadi, bölüm omurgası, örnek/vaka ve uygulanabilir sonuç planlanır."; rule = "Kurgu dışı öğeler ana tez, örnek/vaka, kaynak sınırı ve okur kazanımı üzerinden kurulacak."; artifacts = @("book-plan.json","chapter-plan.json","knowledge-graph.json","source-policy.json") }
    research = @{ title = "Araştırma kitabı şablonu"; planning = "Araştırma sorusu, kaynak disiplini, kapsam, bölüm tezi ve kanıt seviyesi planlanır."; rule = "Araştırma öğeleri kaynak politikası, kanıt seviyesi, kapsam ve doğrulanabilir iddia üzerinden kurulacak."; artifacts = @("research-plan.json","source-policy.json","knowledge-graph.json","chapter-plan.json") }
    academic = @{ title = "Akademik metin şablonu"; planning = "Araştırma sorusu, hipotez, yöntem, atıf stili, kapsam ve etik sınırlar planlanır."; rule = "Akademik öğeler araştırma sorusu, yöntem, literatür ve atıf disiplini üzerinden kurulacak."; artifacts = @("research-question.json","methodology-plan.json","citation-policy.json","section-plan.json") }
    article = @{ title = "Makale / blog şablonu"; planning = "Ana mesaj, hedef okur, başlık açısı, SEO/CTA ve kısa yapı planlanır."; rule = "Kısa yayın öğeleri ana mesaj, okur aksiyonu ve net yapı üzerinden kurulacak."; artifacts = @("article-outline.json","headline-angles.json","seo-brief.json","claim-checklist.json") }
    instructional = @{ title = "Eğitim / rehber şablonu"; planning = "Öğrenme hedefi, seviye, modül akışı, örnek, alıştırma ve uygulama çıktısı planlanır."; rule = "Eğitim öğeleri kazanım, modül, örnek, alıştırma ve uygulama çıktısı üzerinden kurulacak."; artifacts = @("learning-objectives.json","module-plan.json","exercise-plan.json","safety-checklist.json") }
    report = @{ title = "Rapor / whitepaper şablonu"; planning = "Karar sorusu, veri/kanıt politikası, bulgular, öneriler ve varsayım sınırları planlanır."; rule = "Rapor öğeleri karar sorusu, kanıt, bulgu, öneri ve varsayım sınırları üzerinden kurulacak."; artifacts = @("decision-question.json","evidence-policy.json","findings-plan.json","recommendations.json") }
    screenplay = @{ title = "Senaryo şablonu"; planning = "Logline, karakter, sahne/sekans yapısı, format ve görsel aksiyon planlanır."; rule = "Senaryo öğeleri logline, sekans, sahne, görsel aksiyon ve format disiplini üzerinden kurulacak."; artifacts = @("sequence-plan.json","scene-plan.json","character-state.json","format-policy.json") }
    poetry = @{ title = "Şiir kitabı şablonu"; planning = "Tema, ses, biçim, imge dünyası ve bölümleme planlanır; karakter zorunlu değildir."; rule = "Şiir öğeleri tema, ses, imge, biçim ve bölüm ritmi üzerinden kurulacak."; artifacts = @("theme-ledger.json","voice-profile.json","poem-cycle-plan.json","image-system.json") }
  }
  $profile = $profiles[$family]
  return [ordered]@{
    schema_version = "1.0.0"
    run_id = $RunId
    writing_type = $writingType
    writing_family = $family
    family_title = $profile.title
    output_target = (Get-KitHubBookRequestField -Text $Text -Labels @("Çıktı hedefi", "Cikti hedefi"))
    structure_template = (Get-KitHubBookRequestField -Text $Text -Labels @("Yapı", "Yapi"))
    target_pages = Get-KitHubBookRequestField -Text $Text -Labels @("Hedef sayfa")
    target_reader = Get-KitHubBookRequestField -Text $Text -Labels @("Hedef okur", "Okur")
    audience_level = Get-KitHubBookRequestField -Text $Text -Labels @("Okur seviyesi")
    book_purpose = Get-KitHubBookRequestField -Text $Text -Labels @("Kitap amacı", "Kitap amaci", "Calisma amacı", "Calisma amaci", "Çalışma amacı")
    premise = Get-KitHubBookRequestField -Text $Text -Labels @("Konu", "Ana konu", "Araştırma Sorusu", "Öğrenme Hedefi", "Problem")
    evidence_or_character_policy = Get-KitHubBookRequestField -Text $Text -Labels @("Karakterler", "Karakter", "Kaynaklar", "Kaynak / Kanıt Politikası", "Kaynak / Kanit Politikasi", "Kanıt", "Kanit", "Veri", "Örnekler", "Ornekler", "Örnek", "Ornek")
    scope_or_setting = Get-KitHubBookRequestField -Text $Text -Labels @("Dönem ve mekân", "Donem ve mekan", "Kapsam", "Seviye")
    method_or_narration = Get-KitHubBookRequestField -Text $Text -Labels @("Anlatıcı", "Anlatici", "Yöntem", "Yontem", "Analiz Yöntemi", "Öğretim Yaklaşımı")
    ending_or_outcome = Get-KitHubBookRequestField -Text $Text -Labels @("Final", "Sonuç", "Sonuc", "Okur Aksiyonu", "Uygulama Çıktısı", "Öneri")
    style_tone = Get-KitHubBookRequestField -Text $Text -Labels @("Üslup", "Uslup")
    boundaries = Get-KitHubBookRequestField -Text $Text -Labels @("Sınırlar", "Sinirlar", "Atıf", "Varsayım", "Güvenlik")
    source_policy = Get-KitHubBookRequestField -Text $Text -Labels @("Kaynak / gerçeklik kuralı", "Kaynak / gerceklik kurali", "Kaynak kuralı", "Kaynak kurali", "Gerçeklik kuralı", "Gerceklik kurali")
    success_criteria = Get-KitHubBookRequestField -Text $Text -Labels @("Başarı ölçütü", "Basari olcutu")
    planning_policy = $profile.planning
    generation_rule = $profile.rule
    required_planning_artifacts = $profile.artifacts
    ai_instruction = "AI bu sözleşmeyi üst kaynak kabul eder; seçilen aile dışındaki roman/karakter varsayımlarını zorlamaz."
  }
}

function Save-KitHubBookContract {
  param([string]$ProjectRoot, [string]$Text, [string]$RunId = "")
  $runtimeDir = Join-Path $ProjectRoot "runtime"
  if (-not (Test-Path -LiteralPath $runtimeDir -PathType Container)) {
    New-Item -ItemType Directory -Path $runtimeDir | Out-Null
  }
  $contract = Get-KitHubWritingContractFromText -Text $Text -RunId $RunId
  $path = Join-Path $runtimeDir "book-contract.json"
  $json = $contract | ConvertTo-Json -Depth 20
  [System.IO.File]::WriteAllText($path, $json, [System.Text.UTF8Encoding]::new($true))
  return $contract
}
