# UI/UX Yeniden Tasarım Planı — 2026-09-20 başlangıç

**Amaç:** KitHub Studio'yu (AI ile baştan sona kitap üreten editör) sıkışık arayüzden,
sade + adım adım + kapaktan son sayfaya kadar kılavuzluk eden bir editöre dönüştürmek.

**Kullanıcının özeti:** "Kullanıcı istediğini yazacak, işaretleyecek; sistem kapaktan
son sayfaya kadar adım adım götürüp yayına hazır çıktı verecek."

---

## DEVAM KURALI (bu dosyayı okuyan ajana/kişiye)

1. "Nereden devam ediliyor" satırına bak → oradaki gün/adımdan başla.
2. Her adımın durumu: `[BEKLİYOR]` / `[DEVAM]` / `[TAMAM]` / `[ENGELLI: sebep]`.
3. Bir adım bitince durumu güncelle + en alttaki Durum Günlüğü'ne tarihli satır ekle.
4. **Bu planda her ADIM ayrıca kullanıcı onayına tabidir:** adım başlamadan önce
   kapsam özeti gösterilir, onay gelen adım uygulanır. Onay gelmeyen adım atlanmaz,
   bekler.

**Nereden devam ediliyor → ADIM 5 [ONAY BEKLİYOR]:** ADIM 1, ADIM 2, ADIM 3 ve
ADIM 4 kapandı (aşağıdaki sonuç bloklarına bak). Sıradaki iş: Durak 2 PLAN —
öneri kartları + bölüm haritası (propose çıktısı 3 kart, tıkla-işaretle, onay →
mevcut kapılar).

---

## BÖLÜM A — MEVCUT DURUM TESPİTİ (ölçülmüş, 2026-09-20)

Canlı DOM ölçümü (yükleme anı, proje bağlı değilken):

| Metrik | Değer | Yorum |
|---|---|---|
| Tek `index.html` | 13.092 satır | Tüm UI tek dosyada; bakım riski |
| Toplam düğme | 162 | Görünür alanla orantısız |
| Toplam giriş alanı (input/select/textarea) | 118 | Tek ekranda 40+ alan görünebiliyor |
| Etiket (label) | 93 | |
| Dialog (pencere) | 8 | Kapak stüdyosu, kitap parçaları, bölüm vb. |
| Araç çubuğu kontrolleri | 33 | Tek satırda kes/yonlendir/stil/biçim/kontrol |
| "Kontrol" menüsü (support-tab) | 15 öğe | Yazım Kartları, Tür Kontrolü, Canlı Edit, API Testi... |
| Sihirbaz alanları | 18+ | Yan panelde tek sütunda çok uzun form |
| Tipografi bölümleri | 6 sekme × 20+ kontrol | Sayfa/Tipografi/Paragraf/Kenarlar/Üstbilgi/Numaralandırma |
| Sol panel bölüm sayısı | 9 | Kitap kartı, sihirbaz, bölüm listesi, varlıklar, yardımcılar... |
| Sağ panel (AI + yayın + sağlık) | ayrıca 4+ kart | |

**Sıkışıklığın kök nedenleri:**
1. **Her şey hep görünür.** Yan paneller kapatılabilir olsa da varsayılan hepsi açık;
   kullanıcı ilk açılışta 100+ kontrolle karşılaşıyor.
2. **Hiçbir aşama ayrımı yok.** Yeni kitap, yazım, revizyon, tasarım, yayın aynı
   ekranda yan yana. Kullanıcı "şimdi ne yapmalıyım" sorusunun cevabını araç
   yığınından kendisi çıkarmak zorunda.
3. **Bilgi mimarisi düz.** 15 destek sekmesi + 4 ana sekme + 6 tipografi sekmesi +
   8 dialog + 9 sol panel bölümü → zihinsel model kurulamıyor.
4. **Onboarding formu uzun.** 18 alanlık sihirbaz tek sütunda; kullanıcıyı ayıran
   tek şey kaydırma duvarı.
5. **Kod tek dosya.** 13k satır HTML + ayrı 2.4k satır JS; düzenleme maliyeti yüksek.

## BÖLÜM B — RAKİP ÇÖZÜMLEMESİ (incelenen: Novelcrafter, Sudowrite, NovelAI)

**Ortak desenler (bu uygulama sınıfının kanıtlanmış kabulleri):**

1. **Tek merkezli yazım yüzeyi.** Ekranın kalbi yazı alanı; her şey onun etrafında
   açılır/kapanır. Novelcrafter'da varsayılan görünüm ~%80 metin + ince yan şeritler.
2. **Aşama değil, mod.** "Plan / Yaz / Gözden geçir / Piyasa" ayrı sekmeler değil;
   sağ üstte geçilen görünüm modları. Yayına hazırlık ayrı bir "export" yüzeyinde.
3. **Giderek açılan karmaşıklık (progressive disclosure).** Yeni kullanıcı sade
   görür; gelişmiş araçlar (codex, kontroller) tıklayınca açılır. Sudowrite ilk
   ekranda 3 büyük eylem kartı gösterir.
4. **Sihirbaz = adım kartları.** Onboarding tek form değil, 4-6 adımlı kart akışı;
   her kartta 2-4 alan + ilerleme çubuğu.
5. **AI bir "yan panel" değil bir eylem.** Sudowrite'ta AI seçim üzerine küçük bir
   düğme + sonuç kartı; Novelcrafter'da satır içi sohbet. Panel duvarı yok.
6. **Bağlam otomatik.** AI seçili metni/bölümü kendisi anlar; kullanıcı "bağlamı
   seç" alt görünümlerinde gezinmez.

**KitHub'a özgü fark (kopyalanmayacak):** Rakipler "yazı arkadaşı". KitHub
"yayın hattı" — kapaktan EPUB/DOCX'e kadar üretim. Bu, planın C bölümündeki
**Yol Haritası Şeridi** fikrini gerekli kılar; rakip deseniyle çelişmez.

## BÖLÜM C — HEDEF TASARIM: "TEK YOLCULUK, BEŞ DURAK"

Yeni bilgi mimarisi: uygulama tek bir **yolculuk** olarak modellenecek. Beş durak:

```
[1] FİKİR   →   [2] PLAN   →   [3] YAZIM   →   [4] CILA   →   [5] YAYIN
 brief+önerey     plan onayı      bölüm bölüm      revizyon+TDK    kapak+ön/arka+DOCX/EPUB
```

**Ekran hedefi:** Her anda ekranda bir durağın yüzeyi + üstte ince Yol Haritası
Şeridi + altta tek satır durum. Yan paneller yalnızca ilgili durakta açılır.
Hedef ölçüm: **ilk açılışta görünür kontrol sayısı 100+ → ≤ 25.**

### Durak detayları

**Durak 1 — FİKİR (mevcut modeLauncher + sihirbazın yerini alır)**
- 3 kart: "Yeni Kitap", "Devam Et", "Örnek Proje".
- Yeni kitap kartı 5 adımlı sihirbaza bağlanır: (a) tür+kitle, (b) konu 2 cümle,
  (c) karakterler, (d) hacim+çıktı, (e) üslup. Her adımda 2-4 alan; ilerleme
  göstergesi; "AI önersin" anahtar her alanda (isteğe bağlı).
- Çıktı: `book-brief.json` + `book-request.md` (mevcut şema korunur).

**Durak 2 — PLAN (plan propose/design fazlarını sarmalar)**
- Üretilen 3 kitap önerisi kart olarak; kullanıcı işaretler (onaylı seçim).
- Bölüm haritası: hedef bölüm sayısı + bölüm başlıkları listesi; tıkla-düzenle.
- Onay düğmesi → runner'ın propose/design-big akışı (mevcut kapılar korunur).

**Durak 3 — YAZIM (editör; en kalabalık durak, bu yüzden sadeleştirilecek)**
- Ekranda: bölüm listesi (daraltılabilir sol şerit) + metin. Sağ sütun yalnızca
  ajan/süreç görünümü — serbest komut paneli YOK (2026-09-21 kararı, bkz. BÖLÜM G).
  Araç çubuğu iki katı: kalıcı satır (B/I/U, geri al, kaydet, bul) + "gelişmiş"
  açılır (tablo, dipnot, hizalama, kaynak modu).
- Bölüm listesi = bölüm panosu + ağacın birleşimi (ayrı 15 support sekmeye gerek kalmaz).
- Tipografi kontrolleri bu duraktan tamamen çıkar → Durak 5'e taşınır (orada
  "Sayfa Tasarımı" adımı olarak yeniden derlenir).

**Durak 4 — CILA (revizyon + TDK + kalite kapıları)**
- Kapı raporları kart olarak: verifier, TDK-polisher, süreklilik, tekrar analizi.
- Her kapı: durumu (PASS/BLOCKED) + "görevi çalıştır" + raporu aç.
- Mevcut revizyon sekmesi bu durağa taşınır.

**Durak 5 — YAYIN (kapaktan son sayfaya)**
- Adım sırası: Ön/Arka sayfalar → Kapak stüdyosu → Sayfa tasarımı (tipografi
  kontrolleri burada) → Yayın öncesi kontrol → DOCX/EPUB/PDF üret → Final çıktıyı
  kopyala → "Bitti, temizle".
- Her adım tek kart; tamamlanan adımlar yeşil işaretli; kullanıcı yukarıdan aşağı
  işaretledikçe ilerler.

### Kalıcı bileşenler (her durakta)
- **Yol Haritası Şeridi** (üst): 5 durak; aktif durak vurgulu; tıklanınca geçiş
  (yalnızca ön koşulu tamamlanan duraklara).
- **Durum çubuğu** (alt): köprü bağlantısı, aktif koşu, son kapı sonucu. Tek satır.
- **Yardım**: her durakta sağ üstte "?" → o durağın kısa açıklaması (3-5 cümle).

### Teknik strateji
- **Risk düşük, adım adım:** 13k satırı tek seferde yeniden yazmak yerine her adım
  mevcut DOM bloklarını yeni yerlere taşır; her adım sonunda e2e (studio_task_e2e)
  koşulur.
- **CSS önce:** mevcut `--teal/kağıt` paleti korunur; boşluk ölçekleri (spacing
  tokens) CSS değişkenlerine alınır; tek satırla "sıkışık ↔ ferah" dengeleyebilir.
- **index.html bölünmesi:** Yeni `src/` modülleri (studio-wizard zaten var);
  her adım yeni bölümü kendi dosyasına taşır; `index.html` küçülür.

---

## BÖLÜM D — UYGULAMA ADIMLARI (her adım onaylı)

> Her adım: kapsam → onay → uygulama → ölçüm (kontrol sayısı + ekran görüntüsü)
> → kullanıcıya sunum. Onay gelmeyen adım bekler.

### ADIM 1 — Ölçüm ve temas temizliği `[TAMAM]` (2026-09-20)
- Spacing/typography token'ları CSS'e eklendi (17 token: `--gap-1..6`, `--pad-1..4`,
  `--control-h`, `--fs-micro/small/body`, `--radius-sm/md/lg`).
- Sıkışık kümeler token'lara bağlandı: toolbar, tool-cluster, sekme çubuğu,
  sihirbaz paneli/ızgara/akış, kenar bölümleri, alt bilgi, ajan listesi, marka.
- **Ölçüm (canlı DOM, dar görünüm 776×672):**

| Kural | Önce | Sonra |
|---|---|---|
| toolbar gap | 8px | **10px** |
| toolbar padding (geniş yol) | 6px 16px | **8px 18px** |
| toolbar düğme min-yükseklik | yok (içerik) | **31px** |
| toolbar select/input yüksekliği | 29px | **31px** |
| sekme çubuğu gap | 22px | **28px** |
| sihirbaz paneli padding | 12px | **18px** |
| sihirbaz paneli gap | 12px | **14px** |
| sihirbaz ızgarası gap | 6px | **10px** |
| sihirbaz akışı gap | 8px | **10px** |
| kenar bölümü (nav-section) padding | 10px 0 | 10px 0 (token) |
| alt bilgi gap / padding | 8px / 12px | **10px** / 12px |
| ajan listesi padding | 14px | **18px** |

- **Değişmezlik kanıtı:** düğme 162 → **162**, giriş 118 → **118**, dialog 8 → **8**
  (hiçbir işlev kaldırılmadı); konsol hatası **0**; `npm run test:typography` **PASS**;
  canlı duman testi: başlatıcı → sihirbaz açılıyor, 18 alan + 3 adım göstergesi yerinde.
- **e2e politikası (karar):** yalnızca CSS/token dokunan adımlarda hafif kanıt
  (tipografi testi + canlı DOM duman testi) koşulur; markup/JS'e dokunan adımlarda
  (`ADIM 2, 3, 4, 5, 6, 7, 8`) tam `studio_task_e2e_test.ps1` koşulur.
- *Etkisi: görsel ferahlama + sürdürülebilir ölçek sistemi; mimari değişiklik yok.*

### ADIM 2 — Yol Haritası Şeridi + Durak iskeleti `[TAMAM]` (2026-09-20)

**Bulgu (uygulama öncesi):** Uygulamada zaten 6 adımlı bir `workflow-rail` vardı
(Yaz / Plan / AI Düzelt / Sayfa Tasarla / Yayına Hazırla / İşlem Durumu) ve
gerçek yüzey değiştirici "Kontrol" menüsündeki 15 destek sekmesiydi. Eski
`nav.tabs` (Metin / Sayfa Ön İzleme / Plan / Revizyon) **`display:none`** idi —
yani DOM'da duruyor, kullanıcıya hiç görünmüyordu. Bu yüzden "sekmeleri YAZIM
durağı altına yerleştir" işi, var olan gizli şeridi durak şeridine dönüştürmek
olarak uygulandı (yeni sekme sistemi yazılmadı, işlev kaybı yok).

**Yapılan değişiklikler (`index.html`):**
1. **Yol Haritası Şeridi:** 6 adımlı rail, 5 duraklı şeride dönüştü:
   `1 FİKİR · 2 PLAN · 3 YAZIM · 4 CİLA · 5 YAYIN` — her durakta sıra numarası,
   durak adı ve alt etiket (ör. "revizyon & TDK"). Durak kimliği `data-workflow-stop`
   (idea/plan/writing/polish/publish); eski `data-workflow-step` değerleri
   (start/plan/write/edit/publish) korundu, böylece mevcut JS ve tarayıcı
   sözleşmeleri kırılmadı.
2. **Durak yüzey şeridi:** gizli `nav.tabs` görünür hâle geldi ve `.stop-bar`
   içine alındı: solda durak bağlamı (`3 YAZIM · Bölüm metni, ön izleme, plan ve
   revizyon yüzeyleri`), sağda dört yüzey sekmesi (Metin / Sayfa Ön İzleme /
   Plan / Revizyon). Sekmeler `data-stop` ile duraklara etiketlendi.
3. **Çalışma alanı ızgarası yeniden hizalandı:** `stop-bar` (satır 1) → `toolbar`
   (satır 2) → `editor-grid` (satır 3) → `statusbar` (satır 4). `tools-collapsed`
   durumu buna göre güncellendi.
4. **JS senkronu:** `stopCatalog` + `syncStopContext()` eklendi; durak değişince
   hem şerit bağlamı hem `body[data-stop]` güncelleniyor. `renderSupportTab()`
   artık yüzey sekmesini ve aktif durağı da eşitliyor — "Kontrol" menüsünden Plan
   veya Revizyon seçilse bile şerit ve durak bağlamı doğru kalıyor.
5. **Erişilebilirlik düzeltmesi:** ilk denemede durak numarası ve durak ipucu
   rengi (`--quiet`) mobilde WCAG kontrast eşiğinin altında kaldı (3.97 / 4.5);
   üç durak metni `--muted`'a alındı, kontrast denetimi temizlendi.

**Ölçüm (canlı DOM):**

| Ölçüm | Önce | Sonra |
|---|---|---|
| Durak sayısı (workflow-step) | 6 | **5** (FİKİR/PLAN/YAZIM/CİLA/YAYIN) |
| Durak şeridi | yok | **5 durak + 4 yüzey sekmesi** |
| Görünür yüzey sekmeleri | 0 (gizli) | **4** |
| Düğme / giriş / dialog | 162 / 118 / 8 | **161 / 118 / 8** |
| "Kontrol" menüsü öğeleri | 15 | **15 (aynı)** |

- Düğme sayısındaki tek azalma, şeritten çıkan 6. adımdır ("İşlem Durumu");
  işlevi kaybolmadı — üstteki ◎ ve ▣ ikon düğmeleri aynı
  `selectWorkflowStep("status"/"design")` yolunu çağırıyor (canlı duman testiyle
  doğrulandı: ▣ → sayfa tasarımı paneli, ◎ → işlem durumu paneli açılıyor).
- Yüzey sekmesi ↔ durak senkronu canlı test edildi: Revizyon→CİLA,
  Ön İzleme→YAZIM, Plan→PLAN.

**e2e kanıtı (`scripts/ci/browser_e2e_test.ps1`, headless Edge):**
- **Yeni sözleşme denetimleri 7/7 PASS:** `workflowCount=5`, `workflowStops=5`,
  `workflowStopIds=idea/plan/writing/polish/publish`, `tabStripVisible=true`,
  `tabStripButtons=4`, `stopBarSlug=writing`, `publishStepActive=true`.
- DOM (1440 + 390) **PASS**, performans probu **PASS**, konsol hatası **0**,
  erişilebilirlik (masaüstü + mobil): kontrast 0, küçük hedef 0, isimsiz kontrol 0,
  yatay taşma yok.
- **Aynı prob HEAD üzerinde de koşuldu (karşılaştırma):** ADIM 2'ye atfedilebilecek
  **tek bir yeni başarısız denetim yok**; kalan başarısızlıklar HEAD'de de aynı.
  Kalan 5 başarısız terim: `zoom.changedByKeyboard`, `professionalUx.tabs`,
  `paginationFlow.runningHeaders`, `paginationFlow.minimumContinuationLines`,
  `mobileProfessionalLayout.horizontalOverflow` — hepsi ADIM 2'den bağımsız
  (HEAD'de birebir aynı), ayrı bir düzeltme konusu.
- **Bonus (prob iyileştirmesi):** klavye/odak bölümü, başlatıcı (launcher) açıkken
  çalıştığı için her taze oturumda başarısız oluyordu; prob artık odak denetimlerinden
  önce başlatıcıyı kapatıyor. Böylece 7 denetim (5 odak + bul/değiştir odak + seçim)
  ilk kez gerçekten ölçülüp PASS verdi. Detay: `focus.editorSurfacesReady`.
- `zoom.changedByKeyboard` için ek not: zoom yüzeyi proje bağlıyken görünür;
  prob projeyi daha sonra bağladığı için bu denetim bu ortamda ölçülemiyor.
  Erken bağlama denendi: zoom PASS verdi ama `sceneManagerUi.appliedTargets`
  denetimi kırıldı; bu yüzden en küçük değişiklik tercih edildi.

- *Etkisi: 5 duraklı yolculuk iskeleti görünür; mevcut 15 destek sekmesi ve tüm
  yüzeyler korunuyor; durak/yüzey senkronu çalışıyor.*

### ADIM 3 — Durak 1 FİKİR: sihirbazı adım kartlarına böl `[TAMAM]` (2026-09-21)

**Bulgu (uygulama öncesi):** 18 alan sidebar'daki tek uzun formdaydı; mevcut "3
adım" göstergesi (`wizard-flow`) yalnızca görseldi (tıklanamıyor, alan gruplarıyla
eşleşmiyordu). modeLauncher ile sihirbaz iki ayrı yüzeydi: "Yeni Kitap Başlat"
kartı launcher'ı kapatıp sidebar'daki formu açıyordu.

**Karar (kullanıcı onaylı, 2026-09-21):** 5 adımlı akış launcher yüzeyinde yaşar
(launcher = Durak 1 FİKİR yüzeyi); 3. giriş kartı "Örnek Proje" deterministik örnek
brief dolgusu olarak bu adımda eklenir (gerçek fixture projesi ADIM 7'ye kalır).

**Yapılan değişiklikler (`index.html`):**
1. **Sihirbaz launcher'a taşındı:** `<section class="wizard-panel">` sidebar'dan
   çıkarılıp `.mode-launcher-card` içine alındı; launcher artık
   `data-launcher-view="entry|wizard"` ile iki görünüm arasında geçiyor. Taşımanın
   birebirliği `diff -w` ile doğrulandı: kaldırılan/eklenen blok arasındaki tek
   fark kasıtlı başlık ve ilerleme satırları.
2. **5 adım kartı eşlemesi (18 alan, kayıp yok):** 1) Tür & Künye — tür, çalışma
   adı, yazar, çıktı hedefi · 2) Konu & Amaç — konu, kitap amacı, dönem/mekân ·
   3) Karakter & Anlatım — karakterler, anlatıcı, final tipi · 4) Hacim & Yapı —
   hedef okur, hedef sayfa, okur seviyesi, yapı · 5) Üslup & Kurallar — üslup,
   sınırlar, kaynak kuralı, başarı ölçütü (4+3+3+4+4).
3. **İlerleme + gezinme:** 5 tıklanabilir gösterge (dolu/toplam sayacı, tamamda
   "✓ Tamam"), adım başına Geri/İleri (ilk adımda Geri, son adımda İleri kapalı),
   her adımda odak ilk alana gidiyor; türe göre uyarlanan aile kartı 1. adımın
   içine yerleşti. Eski `wizard-flow` / `wizard-section` CSS'i kaldırıldı.
4. **Giriş kartları (3):** Yeni Kitap (5 adımı listeler) · Devam Et (mevcut
   `bindProject` akışı) · Örnek Proje (18 alanı dolduran örnek brief:
   "Rüzgârın Hatırası"). Izgara geniş ekranda 3, ≤1180px 2, ≤780px 1 sütun.
5. **Editörden erişim:** sidebar'a "Kitap Briefi" durum kartı eklendi
   (`briefStatusTitle/Hint` + "Briefi Düzenle (5 adım)") — brief artık editörde de
   görünür ve tek tıkla ilk eksik adımdan düzenlemeye açılır.
6. **Kayıt sonrası yolculuk:** zorunlu alanlar tamamsa kayıt sonrası Durak 2 · PLAN
   açılır; eksikse ilk eksik adım açılıp odaklanır. **`collectWizardValues()`,
   `buildWizardRequestText()`, `syncWizardFromRequestText()` ve
   `validateBookRequestText()` hiç değişmedi**; `validateWizard` yalnızca dönüş
   nesnesini paylaşacak şekilde genişletildi (çıktı şeması korunuyor).

**Ölçüm (canlı DOM):**

| Ölçüm | Önce (HEAD) | Sonra |
|---|---|---|
| Sihirbaz yapısı | 1 uzun form, 18 alan aynı anda görünür | **5 adım kartı**, adım başına 3-4 alan |
| Adım başına görünür alan | 18 | **4 / 3 / 3 / 4 / 4** |
| İlk açılışta görünür kontrol | 100+ (Bölüm A ölçümü) | **3** (üç FİKİR giriş kartı) |
| Sihirbaz adımında görünür kontrol | — | **14** (4 alan + 5 gösterge + 2 gezinme + 2 eylem + geri) |
| Giriş kartı | 2 | **3** (+ Örnek Proje) |
| İlerleme göstergesi | görsel 3 adım, tıklanamaz | **5 tıklanabilir gösterge** (dolu/tamam) |
| Statik düğme / alan (markup) | 175 / 102 | **178 / 102** (18 alan birebir korundu) |
| Adım kartı ızgarası (1414px) | — | 5 ilerleme sütunu, adım kartında **3 sütun**, yatay taşma yok |

**e2e kanıtı (`scripts/ci/browser_e2e_test.ps1`, headless Edge):**
- **Yeni DOM sözleşme denetimleri 3/3 PASS:** `idea-wizard-steps`,
  `idea-wizard-progress`, `idea-launcher-sample`; DOM (1440 + 390) **PASS**.
- **Yeni `ideaFlow` etkileşim bloğu (34 denetim) PASS:** entry görünümü (3 kart,
  sihirbaz kapalı) → wizard görünümü (5 kart, 1 aktif, 5 gösterge, Geri kapalı,
  18 bağlı alan, odak panel içinde, 5/3/3 sütun, taşma yok) → gösterge tıklaması
  (3. adım = `cast`, sayaç "Adım 3 / 5") → İleri (`scope`) → girişe dönüş →
  örnek brief (18 alan dolu, 5 adım tamam, "Hazır", sidebar "brief tamam") →
  son adımda İleri kapalı → temizlik (0 dolu alan, view=entry).
- **Konsol hatası 0**; erişilebilirlik (masaüstü + mobil): kontrast 0, küçük hedef
  0, isimsiz kontrol 0, çift id 0, yatay taşma yok; performans probu **PASS**;
  `controlContracts.unhandled = 0` (48 görünür düğme). Prob artık FİKİR wizard'ının
  ekran görüntüsünü de kaydediyor (`kithub-studio-interaction-idea.png`).
- **Kalan 5 başarısız denetim ADIM 2'nin HEAD ile karşılaştırmalı listesinin
  aynısı** (`zoom.changedByKeyboard`, `professionalUx.tabs`,
  `paginationFlow.runningHeaders`, `paginationFlow.minimumContinuationLines`,
  `mobileProfessionalLayout.horizontalOverflow`) → ADIM 3 kaynaklı yeni
  başarısız denetim yok.
- **Çıktı şeması regresyonu:** `scripts/ci/studio_bridge_book_request_test.ps1`
  **PASS** (book-request.md yazımı + `book-contract.json` + boş karakter reddi);
  `npm run test:typography` **PASS**.

- *Etkisi: tek giriş noktası (FİKİR = launcher) + adım adım brief; ilk açılış
  100+ kontrolden 3 karta inerken işlev envanteri (18 alan, şema) korunuyor.*
- *Sınırlar: "Örnek Proje" kartı şimdilik brief dolgusu — fixture projesini
  bağlayan kapaktan-yayına mini kitap akışı ADIM 7'nin işi.*
- *2026-09-21: "Klasik mod" anahtarı iptal edildi (kullanıcı kararı) — eski düzene
  dönüş yolu yapılmayacak, tek arayüz olacak.*

### ADIM 4 — Durak 3 YAZIM: editör sadeleşmesi `[TAMAM]` (2026-09-21)

**Uygulama (hepsi `index.html`):**
1. **Araç çubuğu iki kata ayrıldı.** Kalıcı satır `.toolbar-core` (7 kontrol):
   geri al/ileri al · B I U · **Kaydet** · **Bul**. Yeni `#toolbarSaveBtn` mevcut
   `saveCurrentEpisode`'a, `#toolbarFindBtn` `openFindPanel(false)`'a bağlandı ve
   kaydet düğmesi sidebar'daki kardeşiyle aynı kuralları izliyor (kayıt sırasında
   ve yazılabilir bölüm yokken `disabled`).
2. **Gelişmiş kat:** `<details id="toolbarAdvanced">` içinde 12 kontrol — pano
   (kes/kopyala/yapıştır), görünüm (Zengin/Kaynak), metin stili + yazı tipi +
   punto (eski araç çubuğunun `blockStyle`/`fontSelect`/`fontSizeSelect`
   yansımaları, silinmedi) ve ekleme/hizalama (tablo, dipnot, sola, iki yana).
   Katın içinde "sayfa tasarımı YAYIN durağında" notu var.
3. **"Kontrol" menüsü 15 → 3 grup** (4+4+4, `data-support-tab` kimlikleri
   korunarak): *Bölüm araçları* (Bölüm Panosu, Bölüm Ağacı, Bölümlere Ayır, Yazım
   Kartları) · *Denetimler* (Tür Kontrolü, Yazım Kuralları, Tekrar Analizi, Sayfa
   Notları) · *Gelişmiş* (Plan, Revizyon, Sürüm Geçmişi, Bağlam Defteri).
   **API Testi, Tanı Paketi, Canlı Edit Ayarlar'a taşındı** — yeni "Gelişmiş
   araçlar" bölümü (`data-settings-tool`, aynı `data-support-tab` bağlantısı);
   tıklanınca Ayarlar menüsü kapanıyor.
4. **Tipografi kartı YAZIM'dan çıktı:** `body[data-stop="writing"] #toggleType`
   gizleniyor; kart YAYIN durağında (▣) açılıyor. Yazma ekranındaki hızlı punto/
   yazı tipi ise silinmedi, gelişmiş kata indi (ADIM 7'de sayfa tasarımı adımında
   yeniden derlenecek).
5. **Yerleşim düzeltmesi:** `.control-menu-list.control-menu-groups` seçicisi
   temel `.control-menu-list` genişliğini (210px) ezmek için özelleştirildi;
   ≤780px'te iki panel de tam genişlik + tek sütun + iç kaydırma (`max-height`).

**Ölçüm (headless Edge, aynı kod iki sürümde; kapalı `<details>` içeriği görünmez
sayılır):**

| Ölçüm | Önce (HEAD) | Sonra (ADIM 4) |
|---|---|---|
| Araç çubuğunda görünür kontrol | **19** | **10** (−47%) |
| Çekirdek satır / gelişmiş kat | — | **7 / 12 (kapalı)** |
| Yazma yüzeyi (araç çubuğu + durak şeridi) | **19** | **14** |
| Kat açıldığında araç çubuğu | 34 | **34** (kayıp yok) |
| "Kontrol" menüsü öğesi | 15 (tek liste) | **12 → 3 grup** (4/4/4) + 3'ü Ayarlar'da |
| Tipografi kartı erişimi (YAZIM) | açık (▣ görünür) | **kapalı** (▣ YAYIN durağında) |
| Envanter: support-tab / taşıma-komut / sihirbaz alanı / id | 15 / 12 / 18 / 266 | **15 / 12 / 18 / 281** (eksik id yok) |

**e2e kanıtı (`scripts/ci/browser_e2e_test.ps1`, headless Edge):**
- **3 yeni statik DOM denetimi PASS:** `writing-toolbar-core`,
  `writing-toolbar-advanced`, `control-menu-groups`, `settings-advanced-tools`.
- **Yeni `writingTools` etkileşim bloğu (48 denetim) PASS:** araç çubuğu görünür
  kontrol 10, çekirdek 7 (Kaydet + Bul dahil), gelişmiş kat 12 gizli, kat
  açılınca 34 ve 12 listeleniyor, "Kontrol" 3 grup × 4 öğe, Ayarlar'da 3 araç,
  support-tab envanteri 15, taşıma komutu 12, YAZIM'da ▣ gizli + YAYIN'da görünür;
  **işlev kanıtı:** menüdeki 12 öğe ve Ayarlar'daki 3 araç tıklandığında kendi
  panellerini açıyor (`Kart Panosu`, `Bölüm Ağacı`, `API Testi`, `Tanı Paketi`,
  `Canlı Edit`…), menü/ayarlar tıklama sonrası kapanıyor, Bul paneli açılıp
  kapanıyor.
- **Yerleşim denetimleri PASS:** 1280 / 1180 / 390 px'te sayfa ve araç çubuğu
  yatay taşması yok; Kontrol paneli **720×179 (3 sütun)**, gelişmiş panel
  **680×209**, ikisi de görünüm alanı içinde; mobilde iki panel 368px tam genişlik
  ve iç kaydırmalı. (Bu ölçüm, 210px'lik temel kuralı ezen özellik düzeltmesini
  kalıcı olarak koruyor.)
- **Konsol hatası 0**; erişilebilirlik (masaüstü + mobil) PASS: isimsiz kontrol 0,
  küçük hedef 0, kontrast 0, çift id 0, yatay taşma yok; performans probu PASS;
  `controlContracts.unhandled = 0`.
- **Kalan 5 başarısız denetim ADIM 2'nin HEAD karşılaştırmalı listesinin aynısı**
  (`zoom.changedByKeyboard`, `professionalUx.tabs`, `paginationFlow.runningHeaders`,
  `paginationFlow.minimumContinuationLines`,
  `mobileProfessionalLayout.horizontalOverflow`) → ADIM 4 kaynaklı yeni
  başarısız denetim yok (toplam madde 281).
- **Çıktı şeması:** bu adım veri şemasına dokunmadı; yine de doğrulandı —
  `scripts/ci/studio_bridge_book_request_test.ps1` **PASS**,
  `npm run test:typography` **PASS**.

- *Etkisi: YAZIM artık metinle ilgili; çekirdek satır 7 kontrolden oluşuyor,
  seyrek kullanılan 12 araç bir tık altta, teknik yüzeyler Ayarlar'da. Hiçbir
  işlev silinmedi (envanter birebir), sadece doğru durağa/katmana taşındı.*
- *Sınırlar: (a) hızlı punto/yazı tipi seçimleri silinmedi, gelişmiş katta duruyor
  (ADIM 7'de YAYIN sayfa tasarımıyla birleşecek); (b) YAYIN durağının kendi adım
  akışı henüz yok — ADIM 4 yalnızca ▣ girişini o durağa taşıdı; (c) bul/araç
  çubuğu hâlâ tek satır + iki açılır kat; komut paleti (Ctrl+K) fikri ADIM 8
  temizliğinde değerlendirilebilir.*
- **Onaya sunum durumu:** ADIM 4 tamamlandı; sıradaki adım ADIM 5 (Durak 2 PLAN).

### ADIM 5 — Durak 2 PLAN: öneri kartları + bölüm haritası `[BEKLİYOR — onay]`
- Propose çıktısı 3 kart; tıkla-işaretle; onay → mevcut kapılar.
- Bölüm haritası bölüm panosu + ağacı birleştirir.
- **Çıktı/ölçüm:** plan onay akışı mevcut runner akışıyla çalışır; e2e PASS.

### ADIM 6 — Durak 4 CILA: kapı rapor kartları `[BEKLİYOR — onay]`
- Verifier/TDK/süreklilik/tekrar kartları; durum + çalıştır + rapor aç.
- Revizyon sekmesi buraya taşınır.
- **Çıktı/ölçüm:** kapı sonuçları kartlarda görünür; e2e PASS.

### ADIM 7 — Durak 5 YAYIN: kapaktan son sayfaya `[BEKLİYOR — onay]`
- Adım kartları: Ön/Arka sayfalar → Kapak → Sayfa tasarımı (tipografi burada
  birleşir) → Yayın öncesi kontrol → Üret → Final çıktı → Bitti/temizle.
- 8 dialog'un 6'sı bu akışa gömülür (dialog sayısı ≤ 2).
- **Çıktı/ölçüm:** tam yolculuk tek ekranda; e2e PASS + DOCX/EPUB üretim kanıtı.

### ADIM 8 — Kod bölmesi + temizlik `[BEKLİYOR — onay]`
- Adımlarda büyüyen yeni bölümler `src/` modüllerine taşınır; index.html hedefi
  ≤ 6k satır.
- Kullanılmayan eski bloklar silinir (sürüm geçmişiyle güvence).
- **Çıktı/ölçüm:** dosya boyutları; tüm testler + e2e PASS.

### ADIM 9 — Final ölçüm ve rapor `[BEKLİYOR — onay]`
- İlk açılışta görünür kontrol sayısı öncesi/sonrası raporu (hedef ≤ 25).
- 5 durağın ekran görüntüleri + kullanıcı akışı belgesi (docs/).
- **Çıktı/ölçüm:** `docs/2026-09-20_UI_REDESIGN_RAPORU.md`.

---

## BÖLÜM E — GARANTİLER (neler bozulmayacak)

1. **Arka uç sözleşmeleri:** brief/plan/state şemaları, runner kapıları, compliance
   manifestleri değişmez. UI yalnızca bunların önündeki yüzeyi yeniden düzenler.
2. **Mevcut özellik kaybı yok:** 15 support sekmesinin her biri bir durağa taşınır
   (silinmez). Adım öncesi/sonrası envanter karşılaştırılır.
3. **Kısayollar ve erişilebilirlik:** mevcut aria etiketleri korunur; her adım
   sonunda klavye gezinme kontrolü.
4. **Her adım geri alınabilir:** adımlar küçük ve bağımsız; sorun olursa tek adım
   geri döndürülür, yolculuk bozulmaz.

## BÖLÜM F — RİSKLER VE KARARLAR

- **Risk 1 — Gizli işlev kaybı:** 162 düğmenin her biri taşınırken unutulabilir.
  *Karşı önlem:* Adım 0'da tam envanter çıkarılır; her adımda "taşınanlar listesi"
  rapora işlenir.
- **Risk 2 — e2e kırılması:** studio_task_e2e UI akışına bağlı. *Karşı önlem:*
  her adım sonunda e2e; kırılırsa adım düzeltilmeden kapatılmaz.
- **Risk 3 — Kullanıcı alışkanlığı:** mevcut kullanıcı yerini bulamayabilir.
  *Karşı önlem:* yeni düzenin kendi tutarlılığı + yol haritası şeridi + "?"
  menüsündeki kısa kullanım notu. **Eski düzene dönüş yolu yapılmayacak**
  (2026-09-21 kararı) — arayüz zaten şikâyet konusuydu, çift bakım maliyeti
  kabul edilmedi.

## BÖLÜM G — KARARLAR

**Geçerli (2026-09-21):**

1. **Klasik mod → HAYIR:** Eski düzene dönüş anahtarı yapılmayacak. Tek arayüz;
   eski görünüm kodda tutulmayacak. (2026-09-20'daki "EVET" kararı geri alındı.)
2. **Editörde asistan paneli → HAYIR:** Serbest komut paneli ("AI Yazım Asistanı")
   editörden kaldırılacak. Süreci **ajanlar yönetir**; editör sadece yazma yüzeyi ve
   ajan/süreç görünümüdür. (2026-09-20'daki "seçim üzerine açılır panel" kararı
   geri alındı.) Ajanların kendi tetikleme yolu (pipeline / Ayarlar) korunur.
3. **Örnek proje → EVET:** Durak 1'de tek tıkla kapaktan yayına tüm akışı dolanan
   hazır mini kitap kartı olacak.
4. **Adım sırası → SIRALI 1→9:** Her adım uygulama öncesi kullanıcıya sunulacak,
   onay alınacak, uygulama sonrası ölçüm + e2e kanıtıyla raporlanacak.
5. **Hedef ilke:** "Bu editörde ne yazacağımı ben seçerim; ajanlar süreci yönetir."
   Yüzey = temiz, sade, metin odaklı. Yeni özellik ancak bu ilkeye hizmet ediyorsa
   girer; süs/çift yol/geri dönüş anahtarı girmez.

---

## Durum Günlüğü

- **2026-09-20:** Plan oluşturuldu. Mevcut arayüz canlı DOM ölçümüyle incelendi
  (162 düğme, 118 giriş, 8 dialog, 15 destek sekmesi, 13.092 satır index.html);
  rakip çözümlemesi yapıldı (Novelcrafter, Sudowrite, NovelAI).
- **2026-09-20 (devam):** Dört karar kullanıcı onayıyla alındı: Klasik mod EVET,
  AI asistan seçim-üzerine, Örnek proje EVET, sıralı 1→9 ilerleme.
- **2026-09-21 (kapsam düzeltmesi):** Kullanıcı hedefi netleştirdi: "Ne yazacağımı
  ben seçeceğim, ajanlar süreci yönetecek, editör sade olacak." Buna göre Klasik mod
  ve editörde asistan paneli kararları **geri alındı** (BÖLÜM G yeniden yazıldı).
  Etki: ADIM 6/7'de "Klasik mod" anahtarı ve seçim-üzerine asistan paneli
  yapılmayacak; bunun yerine editördeki mevcut serbest komut paneli kaldırılıp
  sağ sütun ajan/süreç görünümüne indirilecek. Eski tasarıma ait e2e denetimleri
  (örn. `professionalUx.tabs`) düzeltilmek yerine **silinecek**; yeni tasarımın
  gerçek davranışını ölçen denetimler tutulacak.
- **2026-09-20 (ADIM 1 TAMAM):** 17 boşluk/tipografi token'ı `index.html` `:root`'una
eklendi; 12 kural token'lara bağlanıp ferahlatıldı (ölçüm tablosu ADIM 1 bloğunda).
İşlev envanteri birebir korundu (162/118/8), konsol temiz, tipografi testi PASS,
duman testi geçti. Not: mevcut sihirbazda zaten görsel bir 3 adımlı akış göstergesi
var ("1. Temel / 2. Türe göre / 3. AI planı") ama 18 alan aynı anda görünüyor —
ADIM 3 bu göstergeyi gerçek adım kartlarına dönüştürecek. Nereden devam ediliyor:
**ADIM 2 — onay bekliyor.**
- **2026-09-20 (ADIM 2 TAMAM):** 6 adımlı eski `workflow-rail`, 5 duraklı Yol
Haritası Şeridine dönüştürüldü (FİKİR/PLAN/YAZIM/CİLA/YAYIN, `data-workflow-stop`,
eski `data-workflow-step` değerleri korundu). Gizli `nav.tabs` görünür hâle gelip
`.stop-bar` içinde YAZIM durağı altına yerleşti; durak bağlamı + 4 yüzey sekmesi
canlı senkron. Çalışma alanı ızgarası 4 satıra hizalandı. `stopCatalog` +
`syncStopContext()` + `renderSupportTab()` yüzey/durak senkronu eklendi.
Kontrast denetimi düzeltildi (`--quiet` → `--muted`). Envanter: 161 düğme
(162→161; şeritten çıkan tek düğme, işlevi ◎/▣ ikonlarında duruyor), 118 giriş,
8 dialog, 15 destek sekmesi korunuyor. e2e: yeni 7 duraklı sözleşme denetimi PASS,
DOM+performans+a11y PASS, ADIM 2 kaynaklı yeni başarısız denetim yok (HEAD ile
karşılaştırmalı). Bonus: prob artık odak denetimlerinden önce başlatıcıyı kapatıyor
(7 denetim ilk kez PASS). Nereden devam ediliyor: **ADIM 3 — onay bekliyor.**
- **2026-09-21 (ADIM 3 TAMAM):** Durak 1 FİKİR tek yüzeye birleşti. Sihirbaz
`index.html` içindeki `<section class="wizard-panel">` sidebar'dan çıkarılıp
`.mode-launcher-card` içine taşındı (taşıma `diff -w` ile birebir doğrulandı) ve
launcher `data-launcher-view="entry|wizard"` görünümleriyle çalışıyor: girişte 3 kart
(Yeni Kitap / Devam Et / Örnek Proje), "Yeni Kitap"ta 5 adım kartı + 5 tıklanabilir
ilerleme göstergesi + adım başına Geri/İleri. 18 alan 4+3+3+4+4 olarak bölündü,
türe göre uyarlanan aile kartı 1. adıma yerleşti. Kayıt tamamsa Durak 2 · PLAN
açılıyor, eksikse ilk eksik adım açılıp odaklanıyor. Sidebar'a "Kitap Briefi" durum
kartı + "Briefi Düzenle (5 adım)" düğmesi eklendi. Çıktı şeması korundu:
`collectWizardValues`/`buildWizardRequestText`/`syncWizardFromRequestText`/
`validateBookRequestText` **hiç değişmedi** (diff ile kanıtlı). Ölçüm: ilk açılışta
görünür kontrol 100+ → **3**; adım başına görünür alan 18 → **3-4**; statik düğme
175 → 178, alan 102 → 102 (18 alan birebir). e2e: 3 yeni DOM denetimi PASS, yeni
34 maddelik `ideaFlow` etkileşim bloğu PASS, DOM+a11y+performans PASS, konsol hatası
0, `controlContracts.unhandled=0`; kalan 5 başarısız denetim ADIM 2'nin HEAD
karşılaştırmasıyla aynı. Şema regresyonu: `studio_bridge_book_request_test.ps1` PASS,
`npm run test:typography` PASS. Nereden devam ediliyor: **ADIM 4 — onay bekliyor.**

- **2026-09-21 (ADIM 4 TAMAM):** Durak 3 YAZIM sadeleşti. Araç çubuğu `.toolbar-core`
(7 kontrol: geri al/ileri al, B I U, Kaydet, Bul) + `<details id="toolbarAdvanced">`
(12 kontrol: pano, Zengin/Kaynak, metin stili/yazı tipi/punto, ekleme-hizalama)
olarak ikiye ayrıldı. "Kontrol" menüsündeki 15 öğe 4+4+4 üç gruba indi (Bölüm
yüzeyleri / Denetimler / Gelişmiş) ve API Testi + Tanı Paketi + Canlı Edit Ayarlar'daki
yeni "Gelişmiş araçlar" bölümüne taşındı (`data-support-tab` kimlikleri korundu,
tıklayınca Ayarlar kapanıyor). Tipografi kartı YAZIM'dan çıktı: `body[data-stop="writing"]
#toggleType` gizli, kart YAYIN durağında açılıyor. Ölçüm (aynı kod, iki sürüm):
araç çubuğunda görünür kontrol 19 → **10**, yazma yüzeyi 19 → **14**, kat açılınca
34 → **34** (kayıp yok), menü 15 → **12 + 3 grup**, envanter 15 support-tab / 12
taşıma komutu / 18 sihirbaz alanı birebir. e2e: 4 yeni statik DOM denetimi PASS,
yeni 48 maddelik `writingTools` bloğu PASS (12 menü öğesi + 3 Ayarlar aracı
tıklanınca kendi panelini açıyor; 1280/1180/390px yerleşim ve panel içi taşma
denetimleri dahil), konsol 0, a11y + performans PASS, `controlContracts.unhandled=0`;
kalan 5 başarısız denetim ADIM 2'nin HEAD listesiyle aynı (281 madde). Şema:
`studio_bridge_book_request_test.ps1` PASS, `npm run test:typography` PASS. Nereden
devam ediliyor: **ADIM 5 — onay bekliyor.**
