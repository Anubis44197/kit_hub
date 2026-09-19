# KitHub Agent Runtime Repair — İlerleme 9

Tarih: 2026-09-16

## Koordinasyon bypass araştırması

- [x] İkilide `CBM_RUNTIME_DIR`, `CBM_CACHE_DIR`, `CBM_ALLOWED_ROOT` ve ilgili runtime değişkenleri bulundu.
- [x] Bu değişkenler güvenli klasörlere yönlendirildi.
- [ ] CLI koordinasyon endpoint DACL kontrolünü atlamadı; üst dizin (`C:\tmp` veya `C:\ProgramData`) üzerindeki güvenilmeyen ACE nedeniyle işlem duruyor.
- [x] Yönetici ACL değişikliği yapılmadı; gerçek depo verisi okunmadı.

Sonuç: codebase-memory-mcp kurulumu doğrulanmış durumda, fakat Windows host ACL politikası çözülene kadar KitHub adapter’ı kapalı ve filesystem Context Pack fallback’i kullanılacak.
