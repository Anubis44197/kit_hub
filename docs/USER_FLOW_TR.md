# KitHub Kullanici Akisi

Bu uygulama kitap uretim motorudur. Uygulama koku temiz kalir; her kitap ayri bir proje klasorunde calisir.

## 1. Yeni Kitap Projesi Olustur

Uygulama klasorunde:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kitap Adi"
```

Varsayilan proje yeri:

```text
Documents\KitHubProjects\<kitap-adi>
```

Roman, hikaye, deneme, biyografi veya baska bir yazi isi bu proje klasorunde yurur. Uygulama deposunun icine bolum, cikti veya test romani yazilmaz.

## 2. Kullanici Istegini Yaz

Proje klasorunde su dosyayi olustur:

```text
runtime/book-request.md
```

Bu dosyaya sadece kullanicinin gercek istegi yazilir. Varsayilan konu, eski roman adi, test basligi veya ornek hikaye kullanilmaz.

Ornek:

```text
10 sayfalik, 1930'larda Pera Palas'ta baslayan, 6 karakterli bir ajan hikayesi istiyorum.
Ataturk tarihsel saygi cercevesinde konuya dahil olsun; sahte soz veya sahte alinti kullanilmasin.
```

## 3. Intake: Yazmadan Once Soru ve Brief

Pipeline once kullanicinin istegini kilitler:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase intake
```

Bu asamada sistem su dosyalari uretir:

- `runtime/book-brief.json`
- `runtime/book-dna.json`
- `runtime/layout-profile.json`
- `runtime/approvals/book-brief-approval.json`

Kullanici su alanlari netlestirmeden yazi baslamaz:

- yazi turu
- konu ve ana vaat
- hedef sayfa / bolum / kelime
- tur ve alt tur
- hedef okur
- karakter sayisi ve karakter politikasi
- donem, mekan, anlatici, zaman
- uslup ve yazi tonu
- kapak, onsoz, icindekiler, kunye gibi yayin paketi
- arastirma/kaynak gereksinimi

`book-brief-approval.json` yalnizca kullanici briefi kabul ettiginde `approved=true` yapilir.

## 4. Propose: Hikaye Secenegi

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase propose
```

Sistem secenek uretir. Kullanici bir yon secmeden uygulama kendi kafasina gore konu secemez.

Zorunlu dosya:

```text
runtime/approvals/story-choice.json
```

Bu dosyada `approved=true` ve `selected_option` dolu olmalidir.

## 5. Design: Kitap Plani

Once buyuk plan:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase design-big -ToPhase design-big
```

Sonra kullanici su planlari okur:

- `design/04_book_plan.md`
- `design/05_chapter_plan.md`
- `design/06_layout_plan.md`
- `revision/_state/book-plan.json`
- `revision/_state/chapter-plan.json`
- `revision/_state/layout-plan.json`
- `revision/_state/longform-plan.json`
- `revision/_state/character-state.json`
- `revision/_state/plot-ledger.json`

Kullanici plani kabul ederse:

```text
runtime/approvals/book-plan-approval.json
```

`approved=true` yapilir. Plan kabul edilmeden bolum yazimi baslamaz.

## 6. Create / Polish / Rewrite

Yazim asamasi:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase create -ToPhase create
```

Bu asamada LLM veya IDE ajani plana bagli kalarak bolum dosyalarini ve state guncellemelerini uretir.

Zorunlu kontrol basliklari:

- bolum ilerlemesi
- karakter tutarliligi
- olay/tema surekliligi
- tekrar kontrolu
- TDK/yazim kontrolu
- dizgi/layout kontrolu
- editoryal kalite dongusu

`PASS` hilesi yapilamaz. Editoryal kalite raporu yoksa, dusuk skor varsa, kritik/major sorun varsa veya rewrite gerekiyorsa surec durur.

## 7. Export

Export icin kullanici onayi gerekir:

```text
runtime/approvals/export-approval.json
```

Sonra:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase export -ToPhase export
```

DOCX dosyasi once proje icinde `revision/export/` altinda olusur.

Kullaniciya verilecek final dosya proje disina kopyalanir:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_final.ps1 -ProjectRoot . -DestinationDirectory "$env:USERPROFILE\Desktop" -RequireExportApproval
```

Final hedefi proje klasorunun icinde olamaz.

## 8. Kullanici Okuma ve Revizyon

Roman veya kitap bittikten sonra calisma dosyalari hemen silinmez.

Kullanici final dosyayi okuyabilir, elestiri verebilir, bolum ekletebilir, rewrite isteyebilir veya yeni export alabilir.

Revizyon artik proposal-first calisir. Sistem once taslagi kilitler ve kart uretir; onay almadan `episode/` dosyalarini degistirmez:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/revision_proposals.ps1 -ProjectRoot .
```

Bu komut su dosyalari uretir:

```text
revision/_workspace/draft-v1-lock.json
revision/_workspace/revision-proposals.json
revision/_workspace/revision-proposals.md
```

Kullanici sadece istedigi kartlari onaylar:

```text
runtime/approvals/revision-proposals-approval.json
```

Ornek:

```json
{
  "approved": true,
  "approved_proposal_ids": ["REV-001"]
}
```

IDE/API yazari onaylanan kart icin dar replacement dosyasini `revision/_workspace/proposed/` altina koyar. Sonra sadece onayli kart uygulanir:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/apply_revision.ps1 -ProjectRoot . -ProposalId REV-001
```

Revizyon uygulama komutu once hedef bolumu yedekler, replacement metninde teknik etiket/encoding/kontrol metni olup olmadigini kontrol eder ve yalnizca onayli proposal id icin episode dosyasini degistirir.

`rewrite` fazi artik bu proposal-first dosyalari olmadan gecemez:

```text
revision/_workspace/draft-v1-lock.json
revision/_workspace/revision-proposals.json
runtime/approvals/revision-proposals-approval.json
```

## 9. Kullanici Onayli Temizlik

Yalnizca kullanici acikca "bitti, calisma alanini temizle" derse:

```text
runtime/approvals/cleanup-approval.json
```

su degerlerle guncellenir:

```json
{
  "approved": true,
  "final_output_preserved": true,
  "user_confirmed_book_finished": true
}
```

Sonra:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/cleanup_project.ps1 -ProjectRoot .
```

Cleanup final DOCX'i silmez. Final dosya proje disinda korunmus degilse cleanup baslamaz.

## Yasaklar

- Eski DOCX dosyasini kopyalayip yeni cikti gibi gostermek yasaktir.
- Varsayilan konu veya test romani ile yazi baslatmak yasaktir.
- Kullanici plani onaylamadan bolum yazmak yasaktir.
- `PASS` raporu uydurmak yasaktir.
- Yayin notu, validator raporu, run id, EP001/Sahne etiketi gibi teknik metinleri okuyucu ciktisina koymak yasaktir.
- Uygulama kokune roman calisma dosyasi birakmak yasaktir.
