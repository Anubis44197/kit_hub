# Bileşen Durum Raporu — 2026-09-18

Kapsam: OmniRoute, codebase-memory-mcp, Headroom, Observer, claude-mem/hafıza, Claude setup (.claude/.claude-plugin), 36 ajanlık kayıt sistemi. Tüm sonuçlar canlı testlerden alınmıştır.

## Genel tablo

| Bileşen | Kurulu | Çalışıyor mu | Aktiflik | Gerçek kanıt |
|---|---|---|---|---|
| 36 ajan sistemi | ✅ | ✅ | **Aktif (tam)** | 8 fazda görev akışı e2e ile koştu; 65/65 skill referansı mevcut |
| OmniRoute (gateway) | ✅ | ✅ | **Yarı aktif** | Canary PASS: health 200 + model kataloğu; üretim çağrısı kapalı (auth yok) |
| codebase-memory-mcp | ✅ (0.11.0) | ⚠️ engelli | **Fallback aktif** | Checksum doğrulandı; stdio başlatma Windows DACL hatasında duruyor |
| Observer | ✅ (1.33.0) | ✅ çalışıyor | **Pasif (veri yok)** | `status --json` yanıt verdi; DB boş (0 oturum, 0 eylem) |
| Headroom | ⚙️ (policy) | ⚠️ motor yok | **Pasif pilot** | Kapı betiği çalışıyor; `enabled=false` → fallback raw_content |
| claude-mem (hafıza) | ⚙️ (şema) | ⚠️ motor yok | **Şema seviyesi** | schema.json hazır; SQLite/FTS5 motoru ve kayıt yok |
| Claude setup | ✅ | — | Tanım dosyası | `.claude-plugin/novel-engine` v1.2.0; `.claude/settings.json` (enabledPlugins boş) |

## 1. Ajan sistemi — uygulamanın kalbi, GERÇEKTEN AKTİF

`runtime/agent-registry.json`:
- **36 ajan**, 8 faz: `intake → propose → design-big/design-small → create → polish → rewrite → export`
- Yönetişim modeli: `contract-bound-agent-orchestration`, ilham: **bytedance/deer-flow** (Mercury/Hermes diye bir sistem repoda YOK; "Hermes" yalnızca docs'ta ileride eklenecek bir sağlayıcı uyumluluk fixturü olarak geçiyor)
- Her ajanın sözleşmesi: izinli fazlar, yazma kökleri, zaman aşımı, zorunlu skill referansları
- **Bütünlük testi: 65 zorunlu `SKILL.md` referansının 65'i de diskte mevcut (0 eksik)**
- Görev motoru ve Studio bu registry'den besleniyor (`Get-TaskAgentIdentities`); dünkü e2e testinde bir görev bu zincirle uçtan uca tamamlandı
- Yazma koruması (guardrail) ajanların sözleşme dışı dosyalara yazmasını gerçekten engelliyor (e2e'de 3 kez ispatlandı)

## 2. OmniRoute — gateway sağlığı gerçek, üretim çağrısı kapalı

- Canary `scripts/ci/omniroute_gateway_canary.ps1`: **PASS** — `http://127.0.0.1:8787/v1/models` → 200, model kataloğu dönüyor (`auto/best-coding`, 1M bağlam, tool-calling capability)
- Adapter `enabled=false`, izinli işlemler: `health_check`, `propose_fixture` — bilinçli güvenli mod
- Propose çağrısı gerçekten gateway'e ulaştı (401 auth hatası): endpoint doğru, kalan tek adım dashboard'dan sağlayıcı anahtarı bağlamak
- Aktifleşme: OmniRoute panelinden sağlayıcı ekle → `runtime/adapters/omniroute.json` enabled=true

## 3. codebase-memory-mcp — binary sağlam, Windows DACL engeli

- Binary 0.11.0 mevcut, SHA256 doğrulandı (`binary_present: true`)
- **Engel**: `C:\Users\90535` profil kökünde, ikinci bir yerel hesaba (`S-1-5-21-…-3908196827`) Modify veren kalıtımsız ACE var; binary bunu "untrusted identity" sayıp başlatmayı reddediyor
- Ortam değişkeni override'ları (`CBM_CACHE_DIR` vb.) denendi, etki etmedi
- **Fallback devrede**: bağlam paketleri `filesystem_context_pack` ile üretiliyor — e2e görevi bu fallback ile başarıyla koştu
- Kalıcı çözüm (kullanıcı kararı): `icacls C:\Users\90535 /remove:g *S-1-5-21-3623384205-1531654273-3415129787-3908196827` — profil ACL'sine dokunur

## 4. Observer — kurulup çalışıyor, hiçbir şey gözlemlemiyor

- Binary 1.33.0; `status --json` sağlıklı yanıt verdi
- DB (`~\.observer\observer.db`): **0 proje, 0 oturum, 0 eylem** — read_only/one-shot modda ve hiçbir araç ona veri akıtmıyor
- Aktifleşme: adapter'da one-shot usage snapshot'ı görev koşularına bağlanabilir (şu an `enabled=false`)

## 5. Headroom — politika düzeyi pilot, motor yok

- Gerçek SDK/motor yok; `runtime/adapters/headroom.json` + `scripts/headroom_policy_check.ps1`
- Kapı testi: `tool_output/2MB` → `eligible:false, fallback:raw_content` (enabled=false olduğu için) — güvenli davranış doğru
- Kitap metni, sözleşme ve bağlam paketleri zaten sıkıştırma dışında tutuluyor (`excluded` listesi)

## 6. Hafıza (claude-mem adaptasyonu) — şema hazır, motor yok

- `runtime/memory/schema.json`: SQLite/FTS5 hedefli; kayıt tipleri `decision/error/artifact/verification/user_preference`; gizli alanlar yasak (`api_key`, `raw_prompt`…)
- `select_memory_records.ps1` / `validate_memory_record.ps1` şema doğrulayıcı olarak mevcut
- `runtime/memory/` içinde sadece şema var — hiç kayıt birikmemiş (motor yok)

## 7. Claude setup — eklenti tanımı

- `.claude-plugin/plugin.json`: **novel-engine v1.2.0** — Türkçe roman/kitap üretimi için çok ajanlı hattı paketleyen Claude Code eklenti manifesti (`skills/` 76 dosyaya işaret ediyor)
- `.claude/settings.json`: `enabledPlugins` boş → Claude Code tarafında eklenti bağlanmamış; KitHub'ın kendi runner'ı bu skill'leri zaten doğrudan kullanıyor
- marketplace.json: `local-writing-studio` yerel katalog girişi

## Sonuç

Uygulamanın **gerçekten çalışan omurgası**: 36 ajanlık sözleşmeli orkestrasyon + guardrail + görev motoru + beceri paketi. Bunu doğrudan güçlendirecek tek kapı **model sağlayıcısı** (şu an yerel fallback/boş). Adapterler ise ya yarı aktif (OmniRoute health), ya fallback'te (codebase-memory), ya da pasif (observer, headroom, memory) — hiçbiri görev akışını şu an engellemiyor.
