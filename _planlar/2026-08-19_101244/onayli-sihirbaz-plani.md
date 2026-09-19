# Onaylı Sihirbaz + Tek Çıktı Planı (2026-08-19)

Kullanıcı onayladı. Akış: her adımda kullanıcı seçer → canlı ön izler → beğenirse onaylar (kilitlenir) → sonraki adım açılır.

## Adımlar (Sihirbaz Akışı)

- [ ] **Adım 0 — Mod:** IDE / API seçimi (mevcut ayarlar). API'de anahtar testi.
- [ ] **Adım 1 — Künye:** 9 alanlı brief sihirbazı. Eksikler kırmızı, "İsteği Oluştur" kilitli. Onay → kilit.
- [x] **Adım 2 — Sayfa Şablonu:** `layoutProfile`'u örnek sayfa galerisine çevir (11 kart, minik sayfa görseli). Seç → canlı ön izleme → Onayla.
- [x] **Adım 3 — Sayfa Tasarımı:** `pageDesign` 5 tasarım; her tasarım örnek sayfa görseliyle. Onayla.
- [x] **Adım 4 — Sayfa Boyutu:** `pageSize` + özel ölçü + baskı türü + ön bölüm; `previewMeta` canlı. Onayla.
- [x] **Adım 5 — Yazı Tipi:** 9 font + punto + satır aralığı preset; canlı örnek paragraf. Onayla.
- [x] **Adım 6 — Süsler:** bölüm süsü, drop cap (+köprü/ton), sahne süsü + boyut; "Süs Öner". Onayla.
- [x] **Adım 7 — Kenarlar + Paragraf:** üst/iç/dış, girinti, aralık, dul/yetim; sayfa şeması canlı. Onayla.
- [x] **Adım 8 — Üstbilgi + Numaralandırma:** bölüm başlangıcı, hiyerarşi, üstbilgi, sayfa no, İçindekiler, ön sayfa numarası. Onayla.
- [ ] **Adım 9 — Ön/Arka Sayfalar + Editoryal stil:** ön/arka bölümler, alıntı/diyalog/üç nokta stili, yazım denetimi. Onayla.
- [ ] **Adım 10 — Kapak:** Kapak Stüdyosu + "Konu İçin Görsel Üret" (API: görsel üret, IDE: görsel yükle). Onayla.
- [x] **Adım 11 — Toplu Onay:** 10 adımın seçimleri tek özet ekranda. "Hepsini Onayla" → bu onay olmadan yazım başlamaz.
- [ ] **Adım 12 — Yazım:** `Romanı Planla` → `Planı Onayla ve Yazdır` zincirlenir; her faz sonrası onay (kapatılabilir).
- [x] **Adım 13 — Tek Çıktı:** Masaüstünde `Kitap-Adı/` paketi: Kitap.docx + Kitap.pdf + kapak.png + epub + künye.txt. Tek buton.

## Yapılacak Kod Değişiklikleri

- [x] `index.html`: dizgi paneline Önceki/Sonraki + adım göstergesi (1/11); şablon/tasarım/font seçimleri kartlı galeriye; toplu onay özet dialogu.
- [x] `studio-wizard.js` (yeni modül): adım çubuğu, kartlı galeriler (şablon/tasarım/font), onay kilidi, toplu onay dialogu, localStorage + bridge kalıcılığı.
- [x] `studio_bridge.ps1`: `/api/wizard-state/read` + `/api/wizard-state/save` uç noktaları.
- [x] `local_phase.ps1`: tek paket masaüstü hedefi (`Masaüstü\Kitap-Adı\`: DOCX + PDF + kapak + Bilgi.txt), PDF için zaman aşımı koruması.
- [ ] Kapak: API modunda görsel üretim çağrısı; IDE modunda görsel yükleme. → [x] `/api/cover-asset/generate` (OpenAI images/generations, konudan prompt) + Studio'da "Görsel Yükle"/"Konu İçin Görsel Üret" araç çubuğu; yükleme/üretim otomatik onaylar. HTTP test edildi.
- [ ] `studio_bridge.ps1`: toplu onay sonrası faz zincirini tek akışta çalıştır, her faz sonunda onay iste. → [x] Sihirbazda "Tek Akışta Yaz & Çıkar" butonu: IDE modunda tek komut (intake→export), API modunda plan→yazım→çıktı zinciri köprü üzerinden sırayla.
- [ ] Tarayıcı doğrulaması: Studio açılıp sihirbazın çalıştığını görsel test.