# İnsan-Ajan İşbirliği Katmanı — Tasarım Dokümanı

> Buzz'ın ajan çalışma mantığından esinlenilmiştir (kanal/mesaj, görev kuyruğu, @mention tetikleme, onay→tetikleyici bağı, imzalı denetim). KitHub Studio'ya bağımsız olarak gömülür; relay/MCP/ACP bağımlılığı yoktur.

## Veri Modeli

| Dosya | Şema | Amaç |
|-------|------|------|
| `revision/_state/agent-identities.json` | `runtime/agent-identities.schema.json` | Ajanların Studio'da görünen kimlik kartları |
| `revision/_state/task-feed.json` | `runtime/task-feed.schema.json` | Append-only olay akışı (insan + ajan) |
| `revision/_state/task-queue.json` | `runtime/task-queue.schema.json` | Görev kuyruğu (beş durum, deadline, retry) |
| `revision/_state/task-triggers.json` | `runtime/task-triggers.schema.json` | Olay-güdümlü tetikleyici kuralları |

## Temel Kavramlar

### Agent Identity
Her ajanın Studio'da bir kartı vardır: id, label, group, enabled, color, short. Kaynak yetki runtime/agent-registry.json'dur; bu dosya sadece görünüm özelleştirmelerini tutar. Backend, registry'de olup bu dosyada olmayan ajanları otomatik türetir.

### Task Feed
Her olay (insan mesajı, ajan sonucu, sistem adımı) feed'e eklenir. Event türleri: task.created, task.started, task.completed, task.failed, task.approved, task.rejected, task.cancelled, mention.created, comment.replied, approval.requested, approval.granted, approval.denied, phase.completed, episode.saved, agent.message.

### Task Queue
Görev altı durumda: pending → in_flight → completed/failed/cancelled/blocked. Her görevin: agent, scope (faz/bölüm/kitap), source (mention/trigger/manual/pipeline), deadline, attempts, requires_approval, result. Buzz buzz-acp queue.rs'den esinlenmiştir.

### Task Triggers
Dört olay türü: episode.saved, approval.granted, phase.completed, mention, schedule. Her kuralın bir action'ı vardır: create_task (görev kuyruğuna ekle) veya run_phase (pipeline fazı başlat).

## Örnek İnsan-Ajan İşbirliği Döngüsü

1. Yazar Studio'da bölüm 5'i tamamlar, yorum alanına `@tdk-polisher bölüm 5'i kontrol et` yazar
2. Studio: `mention.created` event'i → task-feed → `@tdk` eşleşmesi → task-queue'a "tdk-polisher için task-002" eklenir
3. Kullanıcı "Ajanlar" panelinde görevi görür, "Başlat"a tıklar
4. Backend: task-queue'da task-002 status=in_flight → provider_phase.ps1 (görev bilinçli) → ajan çalışır → sonuç feed'e + task-002'ye yazılır
5. Yazar üç sorunu görür, düzeltir, "Onayla"ya tıklar
6. Onay → task-002.approved → task-triggers kontrolü → eğer "episode.saved after approval" kuralı varsa → quality-verifier görevi otomatik oluşur
7. Her adım run-journal.jsonl + task-feed ile denetlenebilir

## Aşamalar

1. **Veri modeli** (bu aşama) — şemalar + başlangıç durum dosyaları
2. **Backend** — studio_bridge.ps1: /api/task-feed, /api/task-queue, /api/task-trigger, /api/task-approve, /api/task-cancel, /api/task-agent-list, @mention algılama, tetikleyici değerlendirme
3. **Arayüz** — studio-professional.js: "Ajanlar" sekmesi, feed widget, kuyruk widget, onay/iptal butonları, @mention giriş alanı
4. **Ajan üretimi** — provider_phase.ps1: görev bilinçli (dev prompt yerine scope bazlı)
5. **Tetikleyiciler** — episode.saved → control, approval.granted → next phase

_Hazırlayan: KitHub + Buzz karşılaştırma analizi sonucu, 2026-08-25_
