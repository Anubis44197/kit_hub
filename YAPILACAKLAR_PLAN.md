# Yapilacaklar Plani

Bu dosya proje yol haritasi icin tek kaynak olarak kullanilir.
Yeni tespit edilen her is bu dosyaya eklenir.

## Kullanim Kurali
- Her satirda durum, oncelik ve tarih zorunludur.
- Tamamlanan maddelerde `[ ]` yerine `[x]` kullanilir.
- Buyuk isler alt gorevlere bolunur.
- Bu plan, repo gercegine uymayan maddeleri barindiramaz.

## Durum Etiketleri
- `TODO`: Baslanmadi
- `IN_PROGRESS`: Devam ediyor
- `BLOCKED`: Engel var
- `DONE`: Tamamlandi

## Oncelik
- `P0`: Kritik
- `P1`: Yuksek
- `P2`: Orta
- `P3`: Dusuk

## Guncel Durum Ozeti (2026-04-18)
- [x] `DONE` `P0` `2026-04-18` `agents/tdk-polisher.md` eklendi ve zorunlu cikti sozlesmesi tanimlandi.
- [x] `DONE` `P0` `2026-04-18` `agents/tdk-layout-agent.md` eklendi ve kitap modu layout akisi tanimlandi.
- [x] `DONE` `P0` `2026-04-18` `skills/create`, `skills/polish`, `skills/rewrite` akislarina zorunlu TDK/layout adimlari eklendi.
- [x] `DONE` `P0` `2026-04-18` `quality-verifier` ve `revision-reviewer` icin TDK/layout raporu okunmadan PASS verememe kurali eklendi.
- [x] `DONE` `P1` `2026-04-18` TDK resmi kaynak ve editor-side WCAG referanslari dokumante edildi.

## Tespit Edilen Mantik Hatalari ve Duzeltmeler
- [x] `DONE` `P0` `2026-04-18` Plan satirlarinda tarih zorunlulugu ihlal ediliyordu; tum yeni maddeler tarihli formata cekildi.
- [x] `DONE` `P0` `2026-04-18` "TDK sonraki faz" varsayimi guncel duruma uymuyordu; entegrasyon tamamlandi olarak guncellendi.
- [x] `DONE` `P1` `2026-04-18` Smoke test akisi yeni zorunlu agentlari icermiyordu; yeni akisa gore revize edildi.

## Aktif Isler

### 1) Model Uyum Katmani (Model-Agnostic Adapter)
- [x] `DONE` `P0` `2026-04-18` Ortak gorev semasi tasarla (`task`, `inputs`, `constraints`, `output_contract`).
- [x] `DONE` `P0` `2026-04-18` Mevcut `skills/` ve `agents/` akisini ortak semaya haritala.
- [x] `DONE` `P1` `2026-04-18` Claude/Codex adapteri yaz.
- [x] `DONE` `P1` `2026-04-18` Diger model adapteri yaz (IDE entegrasyonu ile calisan model).
- [x] `DONE` `P1` `2026-04-18` Verdict/rapor formatlarini standardize et (`PASS/REWRITE`, rapor alanlari).
- [x] `DONE` `P2` `2026-04-18` Ayni bolum icin coklu model karsilastirma testi ekle.

### 2) Cekirdek Dokumantasyon ve Kimlik
- [x] `DONE` `P1` `2026-04-18` README'yi urun vizyonu + teknik mimari + kullanim akisi olarak genislet.
- [x] `DONE` `P2` `2026-04-18` `agents/` ve `skills/` icin kisa mimari harita cikar.
- [x] `DONE` `P2` `2026-04-18` Degisiklik gunlugu dosyasi ekle (`CHANGELOG.md`).

### 3) Konfig ve Dogrulama
- [x] `DONE` `P0` `2026-04-18` `novel-config.md` icin zorunlu alan dogrulama semasi yaz.
- [x] `DONE` `P0` `2026-04-18` `book_mode` ve `language_profile` alanlari icin schema dogrulamasi ekle.
- [x] `DONE` `P1` `2026-04-18` Platform/kanonik deger kontrolunu modelden bagimsiz validatora tasi.
- [x] `DONE` `P1` `2026-04-18` Bolum araligi cakisma kontrolunu ortak utility yap.

### 4) Test ve Kalite
- [x] `DONE` `P0` `2026-04-18` Ornek proje fixturelari ekle (`design/`, `episode/`, `revision/`).
- [x] `DONE` `P0` `2026-04-18` Pipeline smoke testi guncelle: `propose -> design -> create -> tdk-polisher -> tdk-layout-agent(book_mode) -> quality-verifier -> polish -> rewrite`.
- [x] `DONE` `P1` `2026-04-18` Regresyon testleri: timeline, number consistency, voice drift.
- [x] `DONE` `P1` `2026-04-18` TDK regresyon testleri: `de/da`, `ki`, `mi/mu`, kesme, noktalama bosluklari.
- [x] `DONE` `P1` `2026-04-18` Layout regresyon testleri: diyalog bloklama, paragraf yogunlugu, heading tutarliligi.
- [x] `DONE` `P2` `2026-04-18` Rapor ciktilari icin snapshot testleri.

### 5) Ajan Sertlestirme
- [x] `DONE` `P0` `2026-04-18` Ajan talimatlarini yuksek seviye anlatimdan olculebilir kurallara cevir (`ne yap`, `nasil olc`, `esik`).
- [x] `DONE` `P0` `2026-04-18` PASS/REWRITE kararini deterministik hale getir (ayni girdide benzer sonuc).
- [x] `DONE` `P0` `2026-04-18` Hook/voice/timeline/number icin sayisal puanlama ve fail esikleri tanimla.
- [x] `DONE` `P0` `2026-04-18` `quality-verifier` icin sayisal esitler ve fail kurallarini detaylandir.
- [x] `DONE` `P0` `2026-04-18` `create/polish/rewrite` icin zorunlu rapor JSON semasi ekle.
- [x] `DONE` `P1` `2026-04-18` `episode-creator` self-check adimlarini deterministic kurallara bagla.
- [x] `DONE` `P1` `2026-04-18` `continuity-bridge` cikti formatini sabitle (timeline, unresolved hooks, state delta).
- [x] `DONE` `P1` `2026-04-18` Ajanlar arasi mesajlasma sozlesmesini standartlastir (handoff contract).
- [x] `DONE` `P2` `2026-04-18` Her ajan icin ornek girdi-cikti (golden examples) dosyalari ekle.

### 6) TDK ve Kitap Modu Derinlestirme
- [x] `DONE` `P0` `2026-04-18` Dil politikasi sabitlendi: icerik Turkce, skill/agent sozlesmeleri Ingilizce, disallow script listesi tanimlandi.
- [x] `DONE` `P0` `2026-04-18` `tdk-polisher` icin JSON issue tiplerini enum olarak sabitle.
- [x] `DONE` `P0` `2026-04-18` `tdk-layout-agent` icin layout ihlal tiplerini enum olarak sabitle.
- [x] `DONE` `P1` `2026-04-18` TDK kurallari icin istisna listeleri ekle (kaliplasmis kullanimlar).
- [x] `DONE` `P1` `2026-04-18` Sayfa sonu/hece bolme kontrolu icin "auto-fix" ve "manual-review" ayrimini netlestir.
- [x] `DONE` `P1` `2026-04-18` Kitap modu hedefleri icin proje bazli profil seti ekle (web-roman, baski-onizleme, e-kitap).

### 7) Runtime ve Gozlemlenebilirlik
- [x] `DONE` `P0` `2026-04-18` Tum skill/ajan adimlari icin ortak run-id ve step-id uretimi ekle.
- [x] `DONE` `P1` `2026-04-18` `_workspace/` raporlari icin tekil index dosyasi ekle (`run-summary.json`).
- [x] `DONE` `P1` `2026-04-18` Basarisiz adimlarda standart hata kodu sozlugu tanimla (`E_SCHEMA`, `E_CONTINUITY`, `E_STYLE`).
- [x] `DONE` `P2` `2026-04-18` Pipeline sure/tekrar metrigi tut ve darboaz raporu uret.

### 8) CI, Lint ve Release Disiplini
- [x] `DONE` `P0` `2026-04-18` Markdown sozlesme linti ekle (zorunlu alanlar, verdict alanlari, cikti path kontrolu).
- [x] `DONE` `P1` `2026-04-18` PR kontrolu icin otomatik smoke test calistir (ornek fixture ile).
- [x] `DONE` `P1` `2026-04-18` SemVer ve surum notu akisi tanimla (`CHANGELOG.md` + release checklist).
- [x] `DONE` `P2` `2026-04-18` Golden-output drift kontrolu ekle (ajan degisikligi sonrasi fark analizi).
- [x] `DONE` `P0` `2026-04-18` Windows ortami icin PowerShell final-readiness denetim scripti ekle.

### 9) Guvenlik, Gizlilik ve Telif
- [x] `DONE` `P0` `2026-04-18` Prompt/rapor ciktilarinda PII redaksiyon kurali ekle.
- [x] `DONE` `P1` `2026-04-18` Kaynak/atifa dayali uretim modunda telif uyum checklisti ekle.
- [x] `DONE` `P1` `2026-04-18` Disa veri cikisini kapatan guvenli calisma profili tanimla (offline-first).
- [x] `DONE` `P2` `2026-04-18` Kullanici-proje bazli izolasyon kurallari tanimla (`WORK_DIR` sinirlari).

### 10) Model Yonetimi ve Prompt Versioning
- [x] `DONE` `P0` `2026-04-18` Ajan ve skill promptlari icin versiyon alanlari ekle (`prompt_version`).
- [x] `DONE` `P1` `2026-04-18` Model bazli capability matrisi dokumani hazirla (uzun baglam, JSON uyumu, maliyet).
- [x] `DONE` `P1` `2026-04-18` Fallback zinciri ve zaman asimi kurallari tanimla (primary/secondary model).
- [x] `DONE` `P2` `2026-04-18` A/B prompt deneyi altyapisi ekle (kalite puani + maliyet karsilastirma).

### 11) Word Disa Aktarim (Kitap Modu) ve Kullanici Onayi
- [x] `DONE` `P0` `2026-04-18` `export-word` skilli tasarla: kaynak olarak `tdk-polisher` + `tdk-layout-agent` ciktilarini kullan.
- [x] `DONE` `P0` `2026-04-18` Export onay kapisi ekle: kullanici acik onay vermeden `.docx` olusturma.
- [x] `DONE` `P0` `2026-04-18` DOCX cikti sozlesmesi tanimla (dosya yolu, bolum secimi, hata kodlari, metadata).
- [x] `DONE` `P0` `2026-04-18` `skills/export-word/SKILL.md` iskeletini olustur ve onayli export akis adimlarini yaz.
- [x] `DONE` `P0` `2026-04-18` `agents/book-exporter.md` agent iskeletini olustur (yalnizca dosya birlestirme, stil uygulama, docx cikti).
- [x] `DONE` `P0` `2026-04-18` `agents/export-approval-gate.md` iskeletini olustur (explicit user consent kontrolu).
- [x] `DONE` `P1` `2026-04-18` Kitap stili seti ekle (baslik stilleri, paragraf girintisi, satir araligi, sayfa boyutu, kenar bosluklari).
- [x] `DONE` `P1` `2026-04-18` Roman yapisina uygun otomatik bolumleme ekle (BOLUM basliklari, sahne ayraclari, sayfa sonu davranisi).
- [x] `DONE` `P1` `2026-04-18` Export-oncesi dogrulama adimi ekle: kritik TDK/layout issue varsa exportu blokla.
- [x] `DONE` `P1` `2026-04-18` Export ozet raporu uret: uygulanan stiller, duzeltme kaynaklari, bloklama nedenleri.
- [x] `DONE` `P2` `2026-04-18` Toplu export modu ekle (EP araligi secimi, tek dosya veya coklu dosya secenegi).
- [x] `DONE` `P2` `2026-04-18` Uyumluluk testi ekle (Word acilis testi, stiller korunumu, Turkce karakter butunlugu).

### 12) Orijinal Mantik Uyum Denetimi (Parity)
- [x] `DONE` `P0` `2026-04-18` Orijinal README kapsamindan dusen operasyon bolumlerini geri tasarla (kurulum, komutlar, workflow, axis/agent haritasi).
- [x] `DONE` `P0` `2026-04-18` TDK/Layout adimlarinin cikti birlesim kuralini netlestir: son `episode/epNNN.md` hangi artefakttan yazilacak.
- [x] `DONE` `P0` `2026-04-18` Verdict sozlugunu teklestir (`PASS/REWRITE/REVISE` uyumsuzlugunu gider).
- [x] `DONE` `P0` `2026-04-18` Soru eki placeholder gosterimlerini gercek Turkce formata cevir (`mi/mı/mu/mü`).
- [x] `DONE` `P1` `2026-04-18` Orijinal agent/skill detay kaybi icin parity kontrol listesi cikar (hangi zorunlu kurallar sadelesmede kayboldu).
- [x] `DONE` `P1` `2026-04-18` Zorunlu adim denetimi ekle: orchestrator, beklenen `_workspace` artefakti yoksa bir sonraki asamaya gecemesin.

## Tespit Kaydi (Yeni Is Ekleme Alani)

Yeni bulgu eklenecek satir formati:
- [ ] `TODO|IN_PROGRESS|BLOCKED|DONE` `P0|P1|P2|P3` `YYYY-MM-DD` Kisa is tanimi

Ornek:
- [x] `DONE` `P1` `2026-04-18` Rewrite asamasinda rapor formati birlestirme
