# Uzman Paneller Testçisi — Test Raporu

**Tarih:** 2026-03-15
**Paneller:** arac_satis_panel · emlakci_panel · rent_a_car_panel
**Metodoloji:** Statik kod analizi (FAZ 1–4)

---

## KRİTİK

- [ ] **[rent_a_car] Çift rezervasyon koruması yok** — Aynı araç aynı tarihler için çakışma kontrolü olmadan insert yapılıyor. | [rent_a_car_panel/lib/features/calendar/calendar_screen.dart:1225-1231](rent_a_car_panel/lib/features/calendar/calendar_screen.dart#L1225)
- [ ] **[rent_a_car] Araç detay ekranında şirket sahiplik kontrolü yok** — `car_detail_screen` araç sorgusunda `company_id` filtresi yok; herhangi bir kullanıcı başka şirketin araç detaylarına erişebilir. | [rent_a_car_panel/lib/features/cars/car_detail_screen.dart:13-17](rent_a_car_panel/lib/features/cars/car_detail_screen.dart#L13)
- [ ] **[rent_a_car] Rezervasyon detayında şirket sahiplik kontrolü yok** — `booking_detail_screen` rezervasyon sorgusunda `company_id` filtresi eksik; müşteri bilgileri (isim, telefon, lisans) diğer şirketlere sızıyor. | [rent_a_car_panel/lib/features/bookings/booking_detail_screen.dart:15-25](rent_a_car_panel/lib/features/bookings/booking_detail_screen.dart#L15)
- [ ] **[arac_satis] Chat erişim kontrolü eksik** — `getConversation()` sadece ID ile filtreliyor, mevcut kullanıcının konuşma katılımcısı olup olmadığını kontrol etmiyor; herhangi bir kullanıcı ID tahmin ederek başkasının mesajlarını okuyabiliyor. | [arac_satis_panel/lib/services/chat_service.dart:119-139](arac_satis_panel/lib/services/chat_service.dart#L119)
- [ ] **[emlakci] Randevu çakışma kontrolü yok** — `createAppointment()` aynı tarih/saatte mevcut randevu olup olmadığını sorgulamadan doğrudan insert yapıyor; aynı mülke aynı saatte birden fazla randevu açılabiliyor. | [emlakci_panel/lib/services/appointment_service.dart:118-147](emlakci_panel/lib/services/appointment_service.dart#L118)
- [ ] **[emlakci] Router'da rol bazlı erişim kontrolü yok** — Giriş yapmış herhangi bir kullanıcı (emlakçı rolü olmasa da) tüm panel rotalarına erişebiliyor; sadece `auth.currentUser != null` kontrol ediliyor. | [emlakci_panel/lib/core/router/app_router.dart:53-69](emlakci_panel/lib/core/router/app_router.dart#L53)

---

## YÜKSEK

- [ ] **[arac_satis] İlan düzenleme route'unda sahiplik doğrulaması yok** — `/listings/edit/:id` rotası sahiplik kontrolü olmadan render ediyor; başkasının ilanı UI'da yükleniyor (Supabase RLS olmasa güncelleme de mümkün). | [arac_satis_panel/lib/core/router/app_router.dart:120-125](arac_satis_panel/lib/core/router/app_router.dart#L120)
- [ ] **[arac_satis] Mesaj gönderme konuşma katılımcısı doğrulaması yapmıyor** — `sendMessage()` kullanıcının o konuşmada yer alıp almadığını kontrol etmiyor. | [arac_satis_panel/lib/services/chat_service.dart:224-251](arac_satis_panel/lib/services/chat_service.dart#L224)
- [ ] **[arac_satis] Fiyat validasyonu yok** — `_priceController` için negatif/sıfır fiyat engelleme kodu mevcut değil; -1 TL'lik ilan yayına alınabiliyor. | [arac_satis_panel/lib/screens/listings/add_listing_screen.dart:56](arac_satis_panel/lib/screens/listings/add_listing_screen.dart#L56)
- [ ] **[arac_satis] Fotoğraf yükleme tip/boyut validasyonu yok** — ImagePicker kullanılıyor ancak dosya tipi (jpg/png zorunluluğu) ve boyut limiti kontrolü uygulanmamış. | [arac_satis_panel/lib/screens/listings/add_listing_screen.dart:60](arac_satis_panel/lib/screens/listings/add_listing_screen.dart#L60)
- [ ] **[arac_satis] Promosyon oluştururken ilan sahipliği kontrol edilmiyor** — `createPromotion()` listing_id ile sorgu yaparken `user_id` filtresi yok; başkasının ilanını promote edebilir. | [arac_satis_panel/lib/services/dealer_service.dart:287-292](arac_satis_panel/lib/services/dealer_service.dart#L287)
- [ ] **[rent_a_car] Araç fiyat validasyonu yok** — Günlük fiyat alanı sadece boş kontrolü yapıyor; negatif/sıfır değerler kaydedilebiliyor. | [rent_a_car_panel/lib/features/cars/cars_screen.dart:999-1005](rent_a_car_panel/lib/features/cars/cars_screen.dart#L999)
- [ ] **[rent_a_car] Görsel dosya tipi validasyonu yetersiz** — File upload'da sadece boyut (5MB) kontrol ediliyor, MIME tipi/uzantı kontrolü yok; URL yöntemi ise herhangi bir URL'i kabul ediyor. | [rent_a_car_panel/lib/features/cars/cars_screen.dart:1156](rent_a_car_panel/lib/features/cars/cars_screen.dart#L1156) ve [:1358](rent_a_car_panel/lib/features/cars/cars_screen.dart#L1358)
- [ ] **[rent_a_car] Araç bookings sorgusunda şirket filtresi eksik** — `car_detail_screen`'de araç rezervasyonları listelenirken `company_id` filtresi yok. | [rent_a_car_panel/lib/features/cars/car_detail_screen.dart:26-31](rent_a_car_panel/lib/features/cars/car_detail_screen.dart#L26)
- [ ] **[emlakci] Negatif fiyat girilip gönderilebiliyor** — `_priceController`, `_squareMetersController`, `_roomsController` için minimum değer doğrulaması yok. | [emlakci_panel/lib/screens/realtor/add_property_screen.dart:30-36](emlakci_panel/lib/screens/realtor/add_property_screen.dart#L30)
- [ ] **[emlakci] Fotoğraf yükleme tip/boyut validasyonu yok** — FilePicker import edilmiş ancak dosya tipi ve boyut kontrolü uygulanmamış. | [emlakci_panel/lib/screens/realtor/add_property_screen.dart:7](emlakci_panel/lib/screens/realtor/add_property_screen.dart#L7)

---

## ORTA

- [ ] **[arac_satis] Satılan araç ilanı otomatik pasife alınmıyor** — `markAsSold()` status'ü 'sold' yapıyor ancak ilanın aktif listelerde görünmemesi için ek filtre gerekiyor; mevcut koddaki status değişikliği yeterli olabilir ama zincir mantık eksik. | [arac_satis_panel/lib/services/listing_service.dart:196-213](arac_satis_panel/lib/services/listing_service.dart#L196)
- [ ] **[arac_satis] Chat sahiplik kontrolü sadece client-side** — Kendi ilanına mesaj göndermeyi engelleyen kontrol (`_userId == sellerId`) kolayca bypass edilebilir; database RLS'e taşınmalı. | [arac_satis_panel/lib/services/chat_service.dart:148-151](arac_satis_panel/lib/services/chat_service.dart#L148)
- [ ] **[emlakci] Randevu silme yetki mantığı hatalı** — `deleteAppointment()` sadece `requester_id == _userId` kontrol ediyor; mülk sahibi (ajan) kendi ilanına gelen randevuyu silemez durumda. | [emlakci_panel/lib/services/appointment_service.dart:278-291](emlakci_panel/lib/services/appointment_service.dart#L278)
- [ ] **[emlakci] Okunmamış mesaj sayısı race condition'a açık** — Client tarafında loop ile toplanan unread count, eş zamanlı güncelleme sırasında hatalı değer dönebilir; aggregation DB'ye taşınmalı. | [emlakci_panel/lib/services/chat_service.dart:230-244](emlakci_panel/lib/services/chat_service.dart#L230)
- [ ] **[rent_a_car] Rezervasyon durum geçişi validasyonu yok** — `completed → active` veya `cancelled → completed` gibi anlamsız durum geçişlerini engelleyen mantık mevcut değil. | [rent_a_car_panel/lib/features/bookings/booking_detail_screen.dart](rent_a_car_panel/lib/features/bookings/booking_detail_screen.dart)
- [ ] **[rent_a_car] Şifre güncelleme güvenlik gereksinimleri yok** — Yeni şifre sadece tekrar kontrolü yapılıyor; minimum uzunluk, karmaşıklık kuralı uygulanmıyor. | [rent_a_car_panel/lib/features/settings/settings_screen.dart:488](rent_a_car_panel/lib/features/settings/settings_screen.dart#L488)
- [ ] **[rent_a_car] Paket fiyat validasyonu yok** — `packages_screen` fiyat parse ederken negatif/sıfır değer kontrolü yapmıyor. | [rent_a_car_panel/lib/features/packages/packages_screen.dart:113](rent_a_car_panel/lib/features/packages/packages_screen.dart#L113)
- [ ] **[arac_satis] Dealer başvuruda RPC hata sessizce yutulup mükerrer başvuru yapılabiliyor** — `check_dealer_application_exists` RPC başarısız olursa exception catch bloğu devam etmeye izin veriyor. | [arac_satis_panel/lib/services/dealer_service.dart:32-42](arac_satis_panel/lib/services/dealer_service.dart#L32)

---

## DÜŞÜK

- [ ] **[arac_satis] Realtime channel ismi user ID içeriyor** — `car_conversations_$_userId` formatındaki channel adı log/trafik analizinde kullanıcı kimliğini açık ediyor. | [arac_satis_panel/lib/services/chat_service.dart:320](arac_satis_panel/lib/services/chat_service.dart#L320)
- [ ] **[arac_satis] N+1 sorgu — chat servisinde performans problemi** — Her konuşma için ayrı `car_dealers` + `user_profiles` sorgusu; 10 konuşmada 20+ DB çağrısı yapılıyor. | [arac_satis_panel/lib/services/chat_service.dart:39-109](arac_satis_panel/lib/services/chat_service.dart#L39)
- [ ] **[rent_a_car] Supabase credentials kaynak koduna gömülmüş** — URL ve anon key sabit tanımlanmış; production için environment variable'a taşınmalı. | [rent_a_car_panel/lib/core/supabase_config.dart:5-6](rent_a_car_panel/lib/core/supabase_config.dart#L5)
- [ ] **[emlakci] Koordinat ondalık ayırıcı varsayımı** — Kullanıcı girişinde `.replaceAll(',', '.')` ile virgül noktaya çevriliyor ancak farklı locale'lerde parse hatası riski var. | [emlakci_panel/lib/screens/realtor/add_property_screen.dart:259](emlakci_panel/lib/screens/realtor/add_property_screen.dart#L259)

---

## FAZ 4 — Cross-App Entegrasyon Sonuçları

| Panel | Tablo | super_app Tablosu | Aynı mı? | Status Filtresi |
|-------|-------|-------------------|----------|-----------------|
| arac_satis_panel | `car_listings` | `car_listings` | ✅ Evet | super_app sadece `active` gösteriyor |
| arac_satis_panel | `car_brands`, `car_features` | aynı | ✅ Evet | `is_active=true` filtresi var |
| emlakci_panel | `properties` | `properties` | ✅ Evet | super_app sadece `active` gösteriyor |
| emlakci_panel | `emlak_cities`, `emlak_districts`, vb. | aynı | ✅ Evet | `is_active=true` filtresi var |
| rent_a_car_panel | `rental_cars`, `rental_bookings` | aynı | ✅ Evet | super_app `is_active=true` + `status=available` |

**Onaylanmamış ilanlar super_app'ta görünüyor mu?** — **HAYIR** (güvenli). super_app tüm üç modülde `.eq('status', 'active')` ile filtreliyor; `pending`/`rejected` ilanlar kullanıcılara görünmüyor. Tablolar ortak, visibility control doğru çalışıyor.

---

## ÖZET

- **Toplam sorun:** 27 (Kritik: 6, Yüksek: 10, Orta: 8, Düşük: 4)
- **SQL/Script Injection:** Supabase SDK parametreli sorgular kullandığı için genel olarak korumalı.
- **Cross-app entegrasyon:** Tablolar paylaşımlı, status filtreleri doğru uygulanıyor.

### En Önemli 3 Bulgu

1. **rent_a_car — Çift Rezervasyon Açığı (KRİTİK):** Aynı araç aynı tarihler için sınırsız rezervasyon oluşturulabiliyor. Çakışma kontrolü için `rental_bookings` tablosunda tarih aralığı sorgusu eklenmeli; tercihen DB trigger veya Edge Function ile garanti altına alınmalı.

2. **rent_a_car — Multi-Tenant Güvenlik İhlali (KRİTİK):** `car_detail_screen` ve `booking_detail_screen` sorgularında `company_id` filtresi eksik; Şirket A'nın çalışanı Şirket B'nin araç detaylarına ve müşteri verilerine (isim, telefon, lisans numarası) ID bilmesi halinde erişebiliyor. Tüm sorguların `company_id` ile kısıtlanması ve Supabase RLS politikalarının zorunlu kılınması gerekiyor.

3. **arac_satis / emlakci — Chat ve Randevu Erişim Kontrolü (KRİTİK):** Hem araç satış panelinde chat konuşmaları hem de emlakçı panelinde randevular, kimlik doğrulamasına rağmen yetersiz sahiplik kontrolü nedeniyle başka kullanıcılar tarafından okunabilir/manipüle edilebilir. Tüm bu işlemlere Supabase Row Level Security politikaları eklenmeli ve client-side kontrole güvenilmemeli.
