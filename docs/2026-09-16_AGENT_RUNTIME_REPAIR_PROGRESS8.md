# KitHub Agent Runtime Repair — İlerleme 8

Tarih: 2026-09-16

## Fixture doğrulama durumu

- [x] `C:\tmp\cbm-secure2` klasöründe miras ACL kaldırıldı ve yalnızca mevcut kullanıcıya tam erişim verildi.
- [x] `USERPROFILE/HOMEPATH` izole profile yönlendirildi.
- [ ] `codebase-memory-mcp cli list_projects` çalışmadı: ikili, koordinasyon endpoint’inin üst dizini için `C:\Users\90535` / `C:\tmp` DACL’sinde güvenilmeyen SID mutasyon hakkı tespit ediyor.
- [x] Bu nedenle gerçek KitHub kodu indekslenmedi ve adapter etkinleştirilmedi.

## Sonraki güvenli adım

Kök profil ACL’si yönetici düzeyinde düzeltilmeden veya codebase-memory-mcp’nin koordinasyon katmanı devre dışı bırakılmadan adapter açılmayacak. Salt-okunur filesystem Context Pack fallback’i aktif kalıyor.
