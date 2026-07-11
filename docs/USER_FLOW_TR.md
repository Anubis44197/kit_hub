# KitHub Kullanıcı Akışı

Bu uygulama, kitap üretim motorudur. Uygulama kökü temiz kalır; her kitap ayrı bir proje klasöründe çalışır.

## 1. Yeni Kitap Projesi Oluştur

Uygulama klasöründe:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kitap Adi"
```

Varsayılan proje yeri:

```text
Documents\KitHubProjects\<kitap-adi>
```

Roman, hikaye, deneme, biyografi veya başka bir yazı işi bu proje klasöründe yürür. Uygulama deposunun içine bölüm, çıktı veya test romanı yazılmaz.

## 2. Kullanıcı İsteğini Yaz

Proje klasöründe şu dosyayı oluştur:

```text
runtime/book-request.md
```

Bu dosyaya sadece kullanıcının gerçek isteği yazılır. Varsayılan konu, eski roman adı, test başlığı veya örnek hikaye kullanılmaz.

Örnek:

```text
10 sayfalık, 1930'larda Pera Palas'ta başlayan, 6 karakterli bir ajan hikayesi istiyorum.
Ataturk tarihsel saygı çerçevesinde konuya dahil olsun; sahte söz veya sahte alıntı kullanılmasın.
```

## 3. Intake: Yazmadan Önce Soru ve Brief

Pipeline önce kullanıcının isteğini kilitler:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase intake
```

Bu aşamada sistem şu dosyaları üretir:

- `runtime/book-brief.json`
- `runtime/book-dna.json`
- `runtime/layout-profile.json`
- `runtime/approvals/book-brief-approval.json`

Kullanıcı şu alanları netleştirmeden yazı başlamaz:

- yazı türü
- konu ve ana vaat
- hedef sayfa / bölüm / kelime
- tür ve alt tür
- hedef okur
- karakter sayısı ve karakter politikası
- dönem, mekan, anlatıcı, zaman
- üslup ve yazı tonu
- kapak, önsöz, içindekiler, künye gibi yayın paketi
- araştırma/kaynak gereksinimi

`book-brief-approval.json` yalnızca kullanıcı briefi kabul ettiğinde `approved=true` yapılır.

## 4. Propose: Hikaye Seçeneği

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase propose
```

Sistem seçenek üretir. Kullanıcı bir yön seçmeden uygulama kendi kafasına göre konu seçemez.

Zorunlu dosya:

```text
runtime/approvals/story-choice.json
```

Bu dosyada `approved=true` ve `selected_option` dolu olmalıdır.

## 5. Design: Kitap Planı

Önce büyük plan:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase design-big -ToPhase design-big
```

Sonra kullanıcı şu planları okur:

- `design/04_book_plan.md`
- `design/05_chapter_plan.md`
- `design/06_layout_plan.md`
- `revision/_state/book-plan.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/layout-plan.json`
- `revision/_state/longform-plan.json`
- `revision/_state/character-state.json`
- `revision/_state/plot-ledger.json`

Kullanıcı planı kabul ederse:

```text
runtime/approvals/book-plan-approval.json
```

`approved=true` yapılır. Plan kabul edilmeden bölüm yazımı başlamaz.

## 6. Create / Polish / Rewrite

Yazım aşaması:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase create -ToPhase create
```

Bu aşamada LLM veya IDE ajanı plana bağlı kalarak bölüm dosyalarını ve state güncellemelerini üretir.

Zorunlu kontrol başlıkları:

- bölüm ilerlemesi
- karakter tutarlılığı
- olay/tema sürekliliği
- tekrar kontrolü
- TDK/yazım kontrolü
- dizgi/layout kontrolü
- editoryal kalite döngüsü

`PASS` hilesi yapılamaz. Editoryal kalite raporu yoksa, düşük skor varsa, kritik/majör sorun varsa veya rewrite gerekiyorsa süreç durur.

## 7. Export

Export için kullanıcı onayı gerekir:

```text
runtime/approvals/export-approval.json
```

Sonra:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase export -ToPhase export
```

DOCX dosyası önce proje içinde `revision/export/` altında oluşur.

Kullanıcıya verilecek final dosya proje dışına kopyalanır:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_final.ps1 -ProjectRoot . -DestinationDirectory "$env:USERPROFILE\Desktop" -RequireExportApproval
```

Final hedefi proje klasörünün içinde olamaz.

## 8. Kullanıcı Okuma ve Revizyon

Roman veya kitap bittikten sonra çalışma dosyaları hemen silinmez.

Kullanıcı final dosyayı okuyabilir, eleştiri verebilir, bölüm ekletebilir, rewrite isteyebilir veya yeni export alabilir.

## 9. Kullanıcı Onaylı Temizlik

Yalnızca kullanıcı açıkça "bitti, çalışma alanını temizle" derse:

```text
runtime/approvals/cleanup-approval.json
```

şu değerlerle güncellenir:

```json
{
  "approved": true,
  "final_output_preserved": true
}
```

Sonra:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/cleanup_project.ps1 -ProjectRoot .
```

Cleanup final DOCX'i silmez. Final dosya proje dışında korunmuş değilse cleanup başlamaz.

## Yasaklar

- Eski DOCX dosyasını kopyalayıp yeni çıktı gibi göstermek yasaktır.
- Varsayılan konu veya test romanı ile yazı başlatmak yasaktır.
- Kullanıcı planı onaylamadan bölüm yazmak yasaktır.
- `PASS` raporu uydurmak yasaktır.
- Yayın notu, validator raporu, run id, EP001/Sahne etiketi gibi teknik metinleri okuyucu çıktısına koymak yasaktır.
- Uygulama köküne roman çalışma dosyası bırakmak yasaktır.
