# KitHub Proje Yasam Dongusu

KitHub uygulama deposu bir motor olarak kalir. Roman, hikaye, deneme, biyografi veya baska bir kitap calismasi uygulama kokune yazilmaz.

## Yeni Proje Ac

```powershell
powershell -ExecutionPolicy Bypass -File scripts/new_project.ps1 -Name "Pera'da Alti Golge"
```

Varsayilan proje koku:

```text
Documents/KitHubProjects/<proje-adi>/
```

Bu klasorde `.kithub-project.json` bulunur. Runner yazim/export fazlarini uygulama deposu kokunde calistirmayi reddeder.

## Yazim ve Revizyon

Proje icindeki calisma dosyalari kullanici final karari verene kadar kalir:

```text
episode/
design/
revision/
runtime/
```

Export almak calisma dosyalarini silmez.

## Final Cikti

```powershell
powershell -ExecutionPolicy Bypass -File scripts/export_final.ps1 -ProjectRoot "<proje-koku>" -DestinationDirectory "$env:USERPROFILE\Desktop"
```

Bu komut son DOCX dosyasini secilen klasore kopyalar ve `runtime/final-export-manifest.json` yazar.

## Calisma Dosyalarini Kaldirma

Calisma dosyalari otomatik kaldirilmaz. Kullanici acikca kitabin bittigini ve calisma dosyalarinin kaldirilmasini onaylamalidir.

Onay dosyasi:

```text
runtime/approvals/cleanup-approval.json
```

Gerekli degerler:

```json
{
  "approved": true,
  "final_output_preserved": true
}
```

Ardindan:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/cleanup_project.ps1 -ProjectRoot "<proje-koku>"
```

Cleanup final DOCX/PDF ciktisina dokunmaz. Sadece proje calisma dosyalarini kaldirir.

## Uzunluk-Derinlik Onayi

Kisa sayfa hedefiyle cok karakterli veya karmasik tur istenirse sistem yazima baslamadan once kullanici onayi ister.

Ornek risk:

```text
10 sayfa + 6 karakter + tarihsel ajan romani
```

Onay dosyasi:

```text
runtime/approvals/length-depth-approval.json
```

Gerekli degerler:

```json
{
  "approved": true,
  "risk_acknowledged": true
}
```
