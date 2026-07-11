# Küçük E2E Test Runbook

Bu runbook uzun kitap testinden önce küçük ve kontrollü doğrulama yapmak içindir. Amaç edebi kaliteyi değil, uygulama kapılarının doğru çalıştığını kanıtlamaktır.

## Test Amacı

Şunlar doğrulanır:

- proje uygulama deposu dışında oluşur
- konu kullanıcı isteğinden gelir
- brief onayı olmadan planlama ilerlemez
- plan onayı olmadan yazım başlamaz
- editoryal kalite raporu olmadan `PASS` kabul edilmez
- final DOCX proje dışına kopyalanır
- kullanıcı cleanup onayı vermeden çalışma dosyaları silinmez

## 1. Proje Oluştur

Uygulama deposunda:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kucuk E2E Test"
```

Terminalde yazan proje yoluna geç:

```powershell
Set-Location "$env:USERPROFILE\Documents\KitHubProjects\kucuk-e2e-test"
```

## 2. Kullanıcı İsteğini Yaz

```powershell
Set-Content -LiteralPath runtime/book-request.md -Encoding utf8BOM -Value "10 sayfalik, 6 karakterli, 1930'larda Pera Palas'ta baslayan tarihsel ajan hikayesi. Ataturk tarihsel saygi cercevesinde konuya dahil olsun; sahte soz veya sahte alinti kullanilmasin."
```

## 3. IDE Manual Config

```powershell
Copy-Item runtime/runner-config.ide-manual.template.json runtime/runner-config.ide-manual.json -Force
```

## 4. Intake Fazını Çalıştır

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase intake
```

`runtime/approvals/book-brief-approval.json` dosyasını yalnızca brief doğruysa onayla.

## 5. Proposal ve Plan Fazları

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase propose
```

`runtime/approvals/story-choice.json` içinde bir seçenek seç ve onayla.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase design-big -ToPhase design-big
```

Plan dosyalarını oku. Kabul edersen `runtime/approvals/book-plan-approval.json` onaylanır.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase design-small -ToPhase design-small
```

## 6. Create / Polish / Rewrite / Export

IDE ajanı her fazda ilgili dosyaları üretir. Runner dosyaları doğrular.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase create -ToPhase export
```

Bu komut sırasında faz onayları ve eksik dosyalar varsa runner durur. Durması başarısızlık değil, doğru kapı davranışıdır.

## 7. Final Dosyayı Masaüstüne Kopyala

Export onaylı ve DOCX oluşmuşsa:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_final.ps1 -ProjectRoot . -DestinationDirectory "$env:USERPROFILE\Desktop" -RequireExportApproval
```

Bu komut eski DOCX kopyalama hilesinin yerine kullanılan tek güvenli yoldur.

## 8. Cleanup Testi

Önce onaysız cleanup denenir; bloklanmalıdır:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/cleanup_project.ps1 -ProjectRoot .
```

Kullanıcı gerçekten "bitti, temizle" derse `runtime/approvals/cleanup-approval.json` onaylanır ve cleanup çalıştırılır.

## Başarı Ölçütü

Test ancak şu koşullarda başarılıdır:

- final DOCX masaüstünde açılabilir
- DOCX içeriği güncel bölüm metniyle eşleşir
- okuyucu çıktısında validator notu, yayın notu, run id, EP001/Sahne etiketi yoktur
- proje içinde final çıktı saklanmaz
- cleanup kullanıcı onayı olmadan çalışmaz
