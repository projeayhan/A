# SuperCyp Test Takımı — 5 Sohbet Prompt'ları

5 yeni Claude Code sohbeti aç, her birine ilgili prompt'u yapıştır, hepsini aynı anda başlat.

---

## SOHBET 1 — Panel Auditörü

```
Sen SuperCyp platformunun Panel Auditörü test ajansısın.
Çalışma dizinin: c:\A

Görevin şu panelleri baştan sona test etmek:
- c:\A\admin_panel
- c:\A\support_panel
- c:\A\merchant_panel

## FAZ 1 — Kod Analizi (sadece oku, hiçbir şeyi değiştirme)

admin_panel için:
- lib/features/ altındaki her modülün screen dosyalarını oku (31 modül var)
- lib/core/router/ router tanımını oku — auth guard/redirect var mı?
- Her ekranda hardcoded data, TODO, FIXME ara
- Loading ve error state eksik olan ekranları işaretle
- Provider'ların dispose edilip edilmediğini kontrol et

support_panel için:
- Tüm screen dosyalarını oku
- Ticket akışını izle (oluşturma → atama → kapatma)
- Agent izolasyonu: başka ajanın ticket'ı görünür mü?

merchant_panel için:
- Tüm screen dosyalarını oku
- Sipariş kabul/ret akışını izle
- Merchant izolasyonu: başka merchant'ın verisi erişilebilir mi?
- Form validasyonlarını kontrol et

## FAZ 2 — İş Akışı & Mantık Testi

- admin_panel → user ban işlemi kodu var mı, doğru mu?
- merchant_panel → sipariş kabul/ret akışı eksiksiz mi?
- support_panel → ticket durumu geçişleri mantıklı mı?
- admin finance ekranı: gerçek veri mi, mock mu?
- Merchant kayıt onay süreci admin'de görünüyor mu?
- admin notification gönderme kodu doğru mu?

## FAZ 3 — Güvenlik Denetimi

- admin_panel route guard yoksa yetkisiz erişim mümkün mü?
- Merchant başka merchant'ın verisini görmesini engelleyen kod var mı?
- support_panel destek ajanı başka ajanın ticket'ını görebiliyor mu?
- XSS: kullanıcı girdisi doğrudan render ediliyor mu?
- PDF/Excel export hassas veri sızdırıyor mu?

## FAZ 4 — Cross-App Entegrasyon

- admin'den user ban → super_app'a yansıma kodu var mı?
- admin'den merchant deaktive → merchant_panel erişimi kesiliyor mu?
- admin notification → FCM/Supabase üzerinden doğru hedefe gidiyor mu?
- sistem sağlığı ekranı gerçek veri mi gösteriyor?

## RAPOR

Tüm fazları tamamlayınca c:\A\REPORT_PANEL_AUDITOR.md dosyasına şu formatta yaz:

# Panel Auditörü — Test Raporu

## KRİTİK
- [ ] [Sorun] | [Dosya:satır]

## YÜKSEK
- [ ] [Sorun] | [Dosya:satır]

## ORTA
- [ ] [Sorun] | [Dosya:satır]

## DÜŞÜK
- [ ] [Sorun] | [Dosya:satır]

## ÖZET
- Toplam sorun: X (Kritik: X, Yüksek: X, Orta: X, Düşük: X)
- En önemli 3 bulgu: ...
```

---

## SOHBET 2 — Super App Testçisi

```
Sen SuperCyp platformunun Super App Testçisi test ajansısın.
Çalışma dizinin: c:\A

Görevin super_app'ı baştan sona test etmek:
- c:\A\super_app

## FAZ 1 — Kod Analizi (sadece oku, hiçbir şeyi değiştirme)

Önce mevcut raporu oku: c:\A\super_app\TEST_REPORT.md (91 sorun var)

Şu modüllerin tüm screen + provider dosyalarını oku:
- lib/screens/food/ — restoran, sepet, sipariş
- lib/screens/taxi/ — taxi akışı
- lib/screens/rental/ — araç kiralama
- lib/screens/car_sales/ — araç satış
- lib/screens/emlak/ — emlak
- lib/screens/store/ — mağaza
- lib/screens/jobs/ — iş ilanları
- lib/screens/grocery/ — market
- lib/core/providers/ — tüm provider'lar
- lib/core/router/app_router.dart — route guard'ları

Kontrol et:
- Her modülde auth guard var mı?
- Birden fazla modülde aynı anda sepet tutulabiliyor mu?
- unified_favorites_provider.dart tüm modülleri kapsıyor mu?
- Mock/hardcoded veri içeren ekranları bul

## FAZ 2 — İş Akışı & Mantık Testi

- Food: restoran seç → ürün ekle → sepet → sipariş akışı doğru mu?
- Taxi: ride state machine (pending→accepted→arrived→started→completed) doğru mu?
- Rental: tarih çakışma kontrolü var mı?
- Car Sales: ilan sahibi olmayan biri güncelleme yapabilir mi?
- Emlak: randevu alma akışı eksiksiz mi?
- Auth: token yenileme kodu var mı?
- Farklı restoranlardan sepete ürün ekleme davranışı

## FAZ 3 — Güvenlik Denetimi

- IDOR: başka kullanıcının siparişini ID ile çekme kontrolü var mı?
- Taxi ownership: arriveAtPickup/startRide/completeRide — driver doğrulama var mı?
- Rating manipulation: herkes değerlendirme yapabiliyor mu?
- Realtime: başka müşterinin adresi leak oluyor mu?
- Deep link: yanlış kullanıcıya ait içerik yüklenebiliyor mu?

## FAZ 4 — Cross-App Entegrasyon

- super_app'ta verilen sipariş courier_app'a gidiyor mu? (courier_service.dart ile karşılaştır)
- super_app'ta çağrılan taxi taxi_app'a düşüyor mu?
- Sipariş iptal kodu bildirim gönderiyor mu?
- merchant_panel ile veri senkronizasyonu nasıl?

## RAPOR

Tüm fazları tamamlayınca c:\A\REPORT_SUPER_APP.md dosyasına şu formatta yaz:

# Super App Testçisi — Test Raporu

## KRİTİK
- [ ] [Sorun] | [Dosya:satır]

## YÜKSEK
- [ ] [Sorun] | [Dosya:satır]

## ORTA
- [ ] [Sorun] | [Dosya:satır]

## DÜŞÜK
- [ ] [Sorun] | [Dosya:satır]

## MEVCUT RAPORDAN DOĞRULANANLAR (TEST_REPORT.md'den)
- [ ] [Sorun] | Durum: Hala mevcut / Çözülmüş

## ÖZET
- Toplam sorun: X (Kritik: X, Yüksek: X, Orta: X, Düşük: X)
- En önemli 3 bulgu: ...
```

---

## SOHBET 3 — Sürücü Uygulamaları Testçisi

```
Sen SuperCyp platformunun Sürücü Uygulamaları Testçisi test ajansısın.
Çalışma dizinin: c:\A

Görevin şu uygulamaları baştan sona test etmek:
- c:\A\taxi_app
- c:\A\courier_app

## FAZ 1 — Kod Analizi (sadece oku, hiçbir şeyi değiştirme)

Önce mevcut raporu oku: c:\A\taxi_app\TAXI_TEST_REPORT.md (38 sorun var)

taxi_app için tüm dosyaları oku:
- lib/screens/ (auth, home, rides, earnings, profile)
- lib/core/services/ (taxi_service, communication_service, directions_service, push_notification_service, security_service, supabase_service)
- lib/core/providers/
- lib/core/router/app_router.dart
- lib/main.dart
- .env veya .gitignore dosyaları

courier_app için tüm dosyaları oku:
- lib/screens/ (auth, home, orders, earnings, profile)
- lib/core/services/
- lib/core/providers/
- lib/main.dart
- .env veya .gitignore dosyaları

Kontrol et:
- Ride state machine: pending→accepted→arrived→started→completed akışı
- Order state machine: courier için
- .env dosyaları .gitignore'da mı?
- Hard-coded API key/URL var mı?
- FCM token kaydı ve yenileme kodu var mı?

## FAZ 2 — İş Akışı & Mantık Testi

- Taxi: ride kabul → completeRide ownership kontrolü var mı?
- Courier: sipariş teslim → kazanç kaydı doğru mu?
- Sürücü çevrimdışı olursa açık ride ne oluyor?
- Aynı ride iki sürücü tarafından aynı anda kabul edilirse? (race condition)
- Earnings hesaplama mantığı doğru mu?
- Sürücü profil güncelleme — hangi alanlar güncellenebilir?

## FAZ 3 — Güvenlik Denetimi

- .env dosyaları .gitignore'a eklenmiş mi? (taxi_app/.gitignore, courier_app/.gitignore)
- Supabase service key kod içinde hard-coded var mı?
- SOS token üretimi tahmin edilebilir mi? (communication_service.dart bak)
- Driver profile: rating/earnings/verified alanları update'e açık mı?
- communication_service.dart: hard-coded URL var mı?

## FAZ 4 — Cross-App Entegrasyon

- taxi_app'ta kabul edilen ride super_app'ta güncelleniyor mu? (aynı tablo/realtime kanal mı?)
- courier_app'ta teslim edilen sipariş super_app'ta güncelleniyor mu?
- Admin'den sürücü askıya alınınca uygulamada ne oluyor?
- Sürücü kazancı admin panelde görünüyor mu?

## RAPOR

Tüm fazları tamamlayınca c:\A\REPORT_DRIVER_APPS.md dosyasına şu formatta yaz:

# Sürücü Uygulamaları Testçisi — Test Raporu

## KRİTİK
- [ ] [Sorun] | [Dosya:satır]

## YÜKSEK
- [ ] [Sorun] | [Dosya:satır]

## ORTA
- [ ] [Sorun] | [Dosya:satır]

## DÜŞÜK
- [ ] [Sorun] | [Dosya:satır]

## MEVCUT RAPORDAN DOĞRULANANLAR (TAXI_TEST_REPORT.md'den)
- [ ] [Sorun] | Durum: Hala mevcut / Çözülmüş

## ÖZET
- Toplam sorun: X (Kritik: X, Yüksek: X, Orta: X, Düşük: X)
- En önemli 3 bulgu: ...
```

---

## SOHBET 4 — Uzman Paneller Testçisi

```
Sen SuperCyp platformunun Uzman Paneller Testçisi test ajansısın.
Çalışma dizinin: c:\A

Görevin şu panelleri baştan sona test etmek:
- c:\A\arac_satis_panel
- c:\A\emlakci_panel
- c:\A\rent_a_car_panel

## FAZ 1 — Kod Analizi (sadece oku, hiçbir şeyi değiştirme)

arac_satis_panel için:
- lib/screens/ altındaki tüm dosyaları oku (auth, dashboard, listings, chat, messages, reviews, performance, profile, settings)
- Router tanımını oku
- İlan oluşturma akışını izle
- Chat sistemi nasıl çalışıyor?

emlakci_panel için:
- lib/screens/ veya lib/features/ altındaki tüm dosyaları oku
- Randevu takvimi ekranını oku (table_calendar kullanıyor)
- CRM ekranlarını oku
- Harita entegrasyonunu kontrol et

rent_a_car_panel için:
- lib/screens/ veya lib/features/ altındaki tüm dosyaları oku (cars, bookings, calendar, finance, locations, packages, reviews, services, settings)
- Rezervasyon akışını izle
- Takvim ekranını oku

Her panel için kontrol et:
- Form validasyonu var mı? Zorunlu alan kontrolleri?
- Fotoğraf yükleme boyut/tip validasyonu var mı?
- Rol bazlı erişim var mı? Başkasının ilanına erişim engellenmiş mi?

## FAZ 2 — İş Akışı & Mantık Testi

- rent_a_car: aynı araç aynı tarihte çift rezervasyon yapılabilir mi? (takvim çakışma kodu var mı?)
- emlakci: randevu çakışma kontrolü var mı?
- arac_satis: satılan araç ilanı otomatik pasife alınıyor mu?
- Fiyat negatif girilebilir mi?
- Fotoğraf olmadan ilan yayına alınabiliyor mu?
- Chat: kendi ilanım olmayan birine ait chat'i okuyabilir miyim?

## FAZ 3 — Güvenlik Denetimi

- arac_satis: başka satıcının ilanını güncelleyebilir miyim? (user_id kontrolü var mı?)
- emlakci: başka ajanın randevusunu silebilir miyim?
- rent_a_car: başka şirketin araçlarını görebilir/değiştirebilir miyim?
- Form injection: input validation'da SQL/script injection engelleniyor mu?
- Dosya yükleme: sadece resim mi yükleniyor, başka uzantı kabul ediliyor mu?

## FAZ 4 — Cross-App Entegrasyon

- arac_satis_panel'e eklenen araç super_app car_sales'te aynı Supabase tablosundan mı geliyor?
- emlakci_panel'de yayına alınan ilan super_app emlak'ta çıkıyor mu? (aynı tablo?)
- rent_a_car_panel'de eklenen araç super_app rental'da görünüyor mu?
- Onaylanmayan ilanlar super_app'ta gözükmemeli — status filtresi var mı?

## RAPOR

Tüm fazları tamamlayınca c:\A\REPORT_SPECIALIST_PANELS.md dosyasına şu formatta yaz:

# Uzman Paneller Testçisi — Test Raporu

## KRİTİK
- [ ] [Sorun] | [Dosya:satır]

## YÜKSEK
- [ ] [Sorun] | [Dosya:satır]

## ORTA
- [ ] [Sorun] | [Dosya:satır]

## DÜŞÜK
- [ ] [Sorun] | [Dosya:satır]

## ÖZET
- Toplam sorun: X (Kritik: X, Yüksek: X, Orta: X, Düşük: X)
- En önemli 3 bulgu: ...
```

---

## SOHBET 5 — Backend & Entegrasyon Testçisi

```
Sen SuperCyp platformunun Backend & Entegrasyon Testçisi test ajansısın.
Çalışma dizinin: c:\A

Görevin backend ve tüm uygulamalar arası bağlantıları test etmek:
- c:\A\supabase/
- Tüm uygulamalardaki *_service.dart dosyaları

## FAZ 1 — Kod Analizi (sadece oku, hiçbir şeyi değiştirme)

Supabase backend:
- c:\A\supabase\migrations\ — tüm migration dosyalarını oku, tablo şemalarını çıkar
- c:\A\supabase\functions\ — edge function var mı? Varsa oku
- c:\A\supabase\config.toml — konfigürasyonu oku

Servis dosyaları (hepsini oku):
- c:\A\super_app\lib\core\services\ (19 servis)
- c:\A\taxi_app\lib\core\services\ (7 servis)
- c:\A\courier_app\lib\core\services\ (6 servis)
- c:\A\admin_panel\lib\core\services\ veya lib\features\*\*_service.dart

Kontrol et:
- RLS (Row Level Security) policy'leri migration'larda tanımlanmış mı?
- RLS eksik olan tablolar var mı?
- Realtime subscription'lar doğru tablo/filtre kombinasyonu kullanıyor mu?
- Cross-app data paylaşımı: aynı tablo farklı uygulamalardan erişiliyor mu?

## FAZ 2 — İş Akışı & Mantık Testi

- Order flow: super_app sipariş oluşturma → hangi tabloya yazıyor → merchant_panel aynı tabloyu mu okuyor?
- Taxi ride: super_app'ta oluşturulan ride → hangi tabloya → taxi_app aynı tabloyu mu okuyor?
- Courier: super_app siparişi → courier_app nasıl alıyor?
- Realtime kanallar: doğru filtreyle mi dinleniyor? (örn. driver_id filter)
- Edge function varsa ne zaman tetikleniyor?

## FAZ 3 — Güvenlik Denetimi

- RLS eksik tablolar listesi: hangi tablolarda RLS yok?
- Service role key client tarafında kullanılmış mı? (anon key yerine service_role key kullanımı)
- Auth bypass: anon role ile korumalı verilere erişilebilir mi? (kod analizi)
- Migration'larda güvenlik açığı var mı? (default değerler, PUBLIC grant'lar)
- Storage bucket politikaları — herkes dosya okuyabilir mi?
- Hard-coded Supabase URL/key var mı? (communication_service.dart özellikle bak)

## FAZ 4 — Cross-App Entegrasyon Haritası

Şu akışları kod üzerinden izle ve çalışıp çalışmadığını doğrula:

1. super_app → sipariş ver → merchant_panel'de görün
   - Hangi tablo? Hangi realtime kanal?

2. super_app → taxi çağır → taxi_app'ta görün
   - Hangi tablo? Hangi realtime kanal?

3. taxi_app → ride tamamla → super_app'ta güncellen
   - Hangi tablo güncellemesi? Realtime tetikleniyor mu?

4. admin_panel → user ban → super_app'ta engel
   - Hangi tablo/alan? RLS bunu yakalar mı?

5. arac_satis_panel → ilan ekle → super_app'ta görün
   - Aynı tablo mu? Status filtresi var mı?

## RAPOR

Tüm fazları tamamlayınca c:\A\REPORT_BACKEND.md dosyasına şu formatta yaz:

# Backend & Entegrasyon Testçisi — Test Raporu

## TABLO ŞEMASI ÖZETİ
| Tablo Adı | RLS Var mı? | Notlar |
|-----------|-------------|--------|

## CROSS-APP VERİ AKIŞ HARİTASI
| Akış | Tablo | Realtime Kanal | Çalışıyor mu? |
|------|-------|----------------|---------------|

## KRİTİK
- [ ] [Sorun] | [Dosya:satır]

## YÜKSEK
- [ ] [Sorun] | [Dosya:satır]

## ORTA
- [ ] [Sorun] | [Dosya:satır]

## DÜŞÜK
- [ ] [Sorun] | [Dosya:satır]

## ÖZET
- Toplam sorun: X (Kritik: X, Yüksek: X, Orta: X, Düşük: X)
- RLS eksik tablo sayısı: X
- En önemli 3 bulgu: ...
```
