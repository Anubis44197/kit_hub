# Çalışma Notu — 2026-08-25

> Bu not, bugün yapılan tüm işleri özetler. Devam ederken buradan devam edelim.

## 1) Buzz × KitHub Derin Analizi (tamamlandı)

- **Amaç:** block/buzz reposunun ajan sistemini derinlemesine analiz etmek; KitHub için uyarlanabilir kavramları belirlemek.
- **Kaynak:** block/buzz (commit 822c5ab, 2026-08-25) → `_workspace/_buzz_src/`
- **Rapor:** `docs/BUZZ_KARSILASTIRMA_RAPORU.md` (547 satır)
- **Tasarım dokümanı:** `docs/HUMAN_AGENT_COLLABORATION.md`
- **Karar:** Buzz'ı kurmuyoruz; buzz'un ajan çalışma mantığını (kuyruk, mention, onay→tetikleyici, denetim akışı) kendi sistemimize gömüyoruz. MCP/relay/ACP bağımlılığı YOK.

## 2) İnsan-Ajan İşbirliği Katmanı (5 aşama — tamamlandı ve test edildi)

### Aşama 1: Veri modeli
| Dosya | Açıklama |
|-------|----------|
| `runtime/agent-identities.schema.json` | Ajan kimlik kartı şeması |
| `runtime/task-feed.schema.json` | Olay akışı şeması (append-only denetim) |
| `runtime/task-queue.schema.json` | Görev kuyruğu şeması |
| `runtime/task-triggers.schema.json` | Tetikleyici kural şeması |
| `revision/_state/agent-identities.json` | 15 ajan kimlik kartı (renk, grup, kısaltma) |
| `revision/_state/task-feed.json` | Olay akışı durumu |
| `revision/_state/task-queue.json` | Görev kuyruğu durumu |
| `revision/_state/task-triggers.json` | 2 örnek kural (varsayılan pasif) |

### Aşama 2: Backend
- `scripts/task_engine.ps1` — YENİ modül (14 fonksiyon): New-TaskItem, Set-TaskStatus, Approve-TaskItem, Cancel-TaskItem, Resolve-TaskMentions, Evaluate-TaskTriggers, Get-TaskSummary, Get-TaskAgentIdentities vb.
- `scripts/studio_bridge.ps1` — dot-source + 8 yeni endpoint:
  `/api/task-summary`, `/api/task-agents`, `/api/task-create`, `/api/task-run`, `/api/task-complete`, `/api/task-approve`, `/api/task-cancel`, `/api/task-triggers/read|save`
- `/api/save-episode` → `episode.saved` tetikleyicisi değerlendirilir

### Aşama 3: UI
- `src/studio-professional.js` — yeni **"Ajanlar"** sekmesi: durum sayaçları, görev kuyruğu, Başlat/Tamamlandı İşaretle/Onayla/Reddet/İptal butonları, yeni görev formu, olay akışı, ajan listesi
- `assets/studio-professional.js` — esbuild ile derlendi

### Aşama 4: Görev bilinçli üretim
- `scripts/provider_phase.ps1` — `-TaskId` parametresi; görev modunda prompt'a görev bilgisi gömülür; görev completed/failed otomatik güncellenir

### Aşama 5: Tetikleyiciler
- `episode.saved` → görev oluşturma, `approval.granted` → faz önerisi (onay→tetikleyici bağı)

### Yerel model desteği (API anahtarı olmayanlar için)
- `provider_phase.ps1` + `studio_bridge.ps1`: Ollama/LM Studio gibi yerel sunucular için boş API anahtarı + http://localhost kabulü
- Kullanıcı API anahtarı olmadığını söyledi → **IDE modu** kullanılacak (ajan rolünü oturumdaki IDE ajanı oynuyor)

## 3) Test Sonuçları (bugün)

- ✅ `task_engine.ps1`, `provider_phase.ps1`, `studio_bridge.ps1` parse OK
- ✅ `src/studio-professional.js` node --check OK + esbuild build OK
- ✅ Uçtan uca: task-summary (36 ajan), task-create, task-run, task-complete, task-approve, task-cancel, task-agents — hepsi çalışıyor
- ✅ @mention algılama, onay→tetikleyici bağı, feed (Türkçe doğru)
- ✅ Provider görev modu: görev bilgisi prompt'a gömülüyor; fail-closed davranış doğrulandı
- ⚠️ Sandbox kısıtı: AppData yazma (provider-settings) + canlı Ollama çağrısı test edilemedi — kullanıcının makinesinde ilk canlı test yapılacak
- ⚠️ bridge yeniden başlatıldı (eski kod 404 veriyordu); arka plan job ile canlı tutuluyor

## 4) Bekleyen Görev (canlı demo)

- **task-001** — "Bölüm 1 TDK kontrolü (canlı demo)" — tdk-polisher — **completed — ONAY BEKLİYOR**
- Rapor: `revision/_workspace/_demo_tdk-polisher_EP001.json` (4 bulgu: çırağına→çırağa, zarı→zarfı, cümle düşüklüğü, iğne vuruşu)
- Kullanıcı Studio'da Ajanlar sekmesinden Onayla/Reddet yapacak

## 5) Yapılacaklar (sıradaki)

1. Kullanıcının task-001'i Studio'da onaylaması (canlı UI testi)
2. Yeni görevler: ep005 TDK kontrolü, 2. bölüm yazımı vb. (IDE modu — oturumdaki ajan yapar)
3. (İsteğe bağlı) Ollama kurulumu → gerçek otomatik üretim
4. @mention'ın yorum kaydetme kancasına bağlanması (şu an elle)
5. Tetikleyicilerin UI'dan aç/kapa yönetimi (şu an JSON)
6. docs/HUMAN_AGENT_COLLABORATION.md güncellemesi (yerel model desteği notu)

## 6) Önemli Dosyalar (hatırlatma)

- Görev motoru: `scripts/task_engine.ps1`
- Bridge: `scripts/studio_bridge.ps1` (8765 portu, arka plan job pwsh-2)
- UI: `src/studio-professional.js` → `assets/studio-professional.js`
- Durum: `revision/_state/task-*.json`, `revision/_state/agent-identities.json`
- Şemalar: `runtime/task-*.schema.json`, `runtime/agent-identities.schema.json`

*Not tutuldu: 2026-08-25 — devam ederken bu dosyadan devam et.*
