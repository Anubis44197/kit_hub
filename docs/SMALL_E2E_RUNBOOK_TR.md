# Kucuk E2E Test Runbook

Bu runbook uzun kitap testinden once kucuk ve kontrollu dogrulama yapmak icindir. Amac edebi kaliteyi degil, uygulama kapilarinin dogru calistigini kanitlamaktir.

## Test Amaci

Sunlar dogrulanir:

- proje uygulama deposu disinda olusur
- konu kullanici isteginden gelir
- brief onayi olmadan planlama ilerlemez
- plan onayi olmadan yazim baslamaz
- editoryal kalite raporu olmadan `PASS` kabul edilmez
- final DOCX proje disina kopyalanir
- kullanici cleanup onayi vermeden calisma dosyalari silinmez

## 1. Proje Olustur

Uygulama deposunda:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Kucuk E2E Test"
```

Terminalde yazan proje yoluna gec:

```powershell
Set-Location "$env:USERPROFILE\Documents\KitHubProjects\kucuk-e2e-test"
```

## 2. Kullanici Istegini Yaz

PowerShell 5.1 ve PowerShell 7 uyumlu UTF-8 BOM yazimi:

```powershell
$text = "10 sayfalik, 6 karakterli, 1930'larda Pera Palas'ta baslayan tarihsel ajan hikayesi. Ataturk tarihsel saygi cercevesinde konuya dahil olsun; sahte soz veya sahte alinti kullanilmasin."
[System.IO.File]::WriteAllText((Join-Path (Get-Location) "runtime/book-request.md"), $text, [System.Text.UTF8Encoding]::new($true))
```

## 3. IDE Manual Config

```powershell
Copy-Item runtime/runner-config.ide-manual.template.json runtime/runner-config.ide-manual.json -Force
```

## 4. Intake Fazini Calistir

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase intake -ToPhase intake
```

`runtime/approvals/book-brief-approval.json` dosyasini yalnizca brief dogruysa onayla.

## 5. Proposal ve Plan Fazlari

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase propose -ToPhase propose
```

`runtime/approvals/story-choice.json` icinde bir secenek sec ve onayla.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase design-big -ToPhase design-big
```

Plan dosyalarini oku. Kabul edersen `runtime/approvals/book-plan-approval.json` onaylanir.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase design-small -ToPhase design-small
```

## 6. Create / Polish / Rewrite / Export

IDE ajani her fazda ilgili dosyalari uretir. Runner dosyalari dogrular.

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run_pipeline.ps1 -ProjectRoot . -ConfigPath runtime/runner-config.ide-manual.json -FromPhase create -ToPhase export
```

Bu komut sirasinda faz onaylari ve eksik dosyalar varsa runner durur. Durmasi basarisizlik degil, dogru kapi davranisidir.

## 7. Final Dosyayi Masaustune Kopyala

Export onayli ve DOCX olusmussa:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_final.ps1 -ProjectRoot . -DestinationDirectory "$env:USERPROFILE\Desktop" -RequireExportApproval
```

Bu komut eski DOCX kopyalama hilesinin yerine kullanilan tek guvenli yoldur.

## 8. Cleanup Testi

Once onaysiz cleanup denenir; bloklanmalidir:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/cleanup_project.ps1 -ProjectRoot .
```

Kullanici gercekten "bitti, temizle" derse `runtime/approvals/cleanup-approval.json` onaylanir ve cleanup calistirilir.

## Basari Olcutu

Test ancak su kosullarda basarilidir:

- final DOCX masaustunde acilabilir
- DOCX icerigi guncel bolum metniyle eslesir
- okuyucu ciktisinda validator notu, yayin notu, run id, EP001/Sahne etiketi yoktur
- proje icinde final cikti saklanmaz
- cleanup kullanici onayi olmadan calismaz
