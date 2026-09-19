# KitHub Agent Runtime Repair — İlerleme 25

Tarih: 2026-09-17

- [x] Studio Bridge browser QA yapıldı: `http://127.0.0.1:8765/` açılıyor, title `KitHub Studio`, konsol uygulama hatası yok.
- [x] Studio ana ekranda yatay taşma görülmedi; gizli workflow kontrolleri görünür UI hatası üretmiyor.
- [x] OmniRoute için izole production build denemesinde `BUILD_ID` üretildi: `C:\tmp\omniroute\.build\kithub-canary-next\BUILD_ID`.
- [!] OmniRoute gateway start hâlâ kapalı: start sırasında `.source/source.config.mjs` yazma izni reddediliyor ve `prerender-manifest.json` eksik olduğu için server port açmıyor.
- [x] OmniRoute provider çağrısı yapılmadı; gateway açık bırakılmadı.
- [!] codebase-memory-mcp workspace binary klasörü hâlâ okunamıyor; adapter inventory `binary_present=false` ve filesystem Context Pack fallback aktif.
- [x] Adapter inventory artık Headroom satırını da raporluyor.
- [x] Memory isolation selector ve CI testi eklendi; farklı kitap/proje kayıtları seçici context’e sızmıyor.

Sonuç: KitHub Studio ve güvenli adapter fallback katmanı çalışıyor. OmniRoute gerçek gateway, codebase-memory gerçek indexing ve Headroom gerçek motor hâlâ güvenli şekilde kapalı.
