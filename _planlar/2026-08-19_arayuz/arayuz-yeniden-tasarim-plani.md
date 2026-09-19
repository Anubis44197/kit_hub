# Arayüz Yeniden Tasarım Planı

Tarih: 2026-08-19
Durum: ONAY BEKLİYOR (kod yazılmadı)

## Amaç
KitHub Studio karmasik; ayni islev 3 farkli yerde. Hedef: basit, sade, sirayla yonlendiren bir arayuz. Tum islevler kalacak ama gorunurluk moda gore sinirlanacak.

## Bulgular (inceleme)
- Izgara: 3 sutun + alt serit. sol 292px / orta / sag 420px / alt 218px (index.html:141-166)
- Sihirbaz cubugu 218px'lik alt dizgi paneline sikisti -> "yarim acilan alt menu" goruntusu
- Cakisma 1 (akis): workflow-rail + faz secicileri + rehberli 3 asama ayni motoru calistiriyor
- Cakisma 2 (istek): 11 soruluk sihirbaz + ham istek metni + "Kunye" adimi ayni veriyi besliyor
- Cakisma 3 (onay): Onaylar listesi + adim onaylari + Toplu Onay ayni kavram
- Cakisma 4 (buton): Romani Planla / Planı Onayla ve Yazdır / Export Fazını Calistir / Tek Akista Yaz & Cikar = ayni motor
- Cakisma 5 (panel): 5 ayri panel ac/kapat dugmesi (?????)
- Sag panel 420px yer kapliyor, "AI Yazim Asistani" rehberli modda anlamsiz

## Hedef Mimari

### Mod A - Rehberli Mod (varsayilan)
- Ust serit: KitHub Studio | kitap adi | IDE/API | Ayarlar | Gelismis Mod
- Orta alan (tek odak):
  - Asama 1 Proje: giris karti (Yeni Kitap Baslat / Mevcut Projeyi Bagla)
  - Asama 2 Tasarim: her adim icin sol=form+galeri, sag=canli onizleme
  - Asama 3 Yaz & Cikar: Toplu Onay ozeti + Tek Akista Yaz & Cikar + sonuc + Paketi Ac
- Sol panel (240px): kitap karti + bolum listesi
- Sag panel: KAPALI
- Alt dizgi seridi: KAPALI (tasarim adimlari orta alana tasinir)

### Mod B - Gelismis Mod
- Sol: kitap karti + bolumler + Varliklar + Onaylar + Disa Aktarim
- Orta: Metin / Onizleme / Plan / Revizyon + arac cubugu
- Sag: AI asistani + Yayin Paketi (tek dugme)
- Alt: Dizgi - yukseklik 218->420px, sekme bazli
- Motor alt menusu: workflow-rail + faz secicileri
- Paneller menusu: 5 ayri panel dugmesi tek yerde
- Araclar dialogu: 16 destek araci tek menuden

## Uygulama Asamalari
1. CSS/izgara: --type-h artir, rehberli modda sag/alt paneli kapat
2. Rehberli mod: adim formlarini orta alana tasi (galeri+onizleme bolunmus), alt paneli kapat
3. Gelismis mod: Motor/Paneller/Araclar menulerini kur, butonlari tekillestir
4. Testler: readiness + verify_real_run + fixture + parse + HTTP

## Kararlar
- Rehberli modda faz secicileri, workflow-rail, Varliklar, Disa Aktarim, Onaylar, AI asistani gorunmez
- Gelismis modda rehberli mod devre disi (tum paneller geri gelir)
- "Tek Akista Yaz & Cikar" tek motor butonu olur; digerleri Gelismis Mod'a tasinir