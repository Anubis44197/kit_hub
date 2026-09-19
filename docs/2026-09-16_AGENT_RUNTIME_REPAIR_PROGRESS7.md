# KitHub Agent Runtime Repair — İlerleme 7

Tarih: 2026-09-16

## codebase-memory-mcp kurulum sonucu

- [x] Resmi `v0.11.0` Windows amd64 arşivi indirildi.
- [x] `checksums.txt` içindeki SHA-256 ile eşleşme doğrulandı.
- [x] İkili geçici klasörde `--version` ile çalıştırıldı.
- [x] Global ajan yapılandırması değiştirilmeden kullanıcı LocalAppData hedefine kopyalandı.
- [ ] KitHub adapter etkinleştirilmedi; salt-okunur fixture testi beklemede.

## Kanıt

- Kurulum yolu: `%LOCALAPPDATA%\\Programs\\codebase-memory-mcp\\codebase-memory-mcp.exe`
- Sürüm: `codebase-memory-mcp 0.11.0`
- Yayın özeti: `6eb6beaf261b19e419766e78baf93cbc3cf1c6338cff8fb7c0234859f96d1685`
- `cli list_projects` denemesi, kullanıcı profilindeki miras DACL nedeniyle güvenli koordinasyon endpoint oluşturamadı. Bu nedenle gerçek depo indekslemesi yapılmadı.

## Karar

Kurulum tamamlandı; adapter `enabled:false` olarak bırakıldı. ACL güvenliği ve geçici fixture doğrulaması tamamlanmadan gerçek KitHub kodu indekslenmeyecek.
