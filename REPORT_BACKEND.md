# Backend & Entegrasyon Testçisi — Test Raporu

**Tarih:** 2026-03-15
**Platform:** SuperCyp
**Kapsam:** Supabase backend + tüm uygulama servis katmanları
**Analiz Edilen Migration Sayısı:** 5
**Analiz Edilen Edge Function Sayısı:** 5
**Analiz Edilen Servis Dosyası Sayısı:** ~35 (super_app, taxi_app, courier_app, admin_panel)

---

## TABLO ŞEMASI ÖZETİ

| Tablo Adı | RLS Var mı? | Notlar |
|-----------|-------------|--------|
| car_brands | HAYIR | Sadece index tanımlı; migration'da RLS aktivasyonu yok |
| car_features | HAYIR | Sadece index tanımlı; migration'da RLS aktivasyonu yok |
| car_body_types | EVET | Public SELECT (is_active=true filtreli) |
| car_fuel_types | EVET | Public SELECT (is_active=true filtreli) |
| car_transmissions | EVET | Public SELECT (is_active=true filtreli) |
| car_dealers | EVET | Public SELECT (active olanlar) + owner ALL |
| car_dealer_applications | EVET | Kullanıcı kendi başvurularını görebilir/oluşturabilir |
| car_listings | EVET | Public SELECT (active) + owner tam kontrol |
| car_promotion_prices | HAYIR | Migration'da RLS aktivasyonu yok |
| car_listing_promotions | EVET | Kullanıcı kendi promosyonları |
| car_listing_views | HAYIR | RLS veya INSERT politikası yok — herkes ekleyebilir |
| car_favorites | EVET | Kullanıcı kendi favorileri |
| car_contact_requests | EVET | Dealer/owner görüntüleyebilir + herkese INSERT |
| car_settings | HAYIR | RLS yok — admin paneli service_role bekliyor ama tanımlı değil |
| car_dealer_reviews | EVET | Public SELECT (visible) + owner INSERT/UPDATE |
| support_chat_sessions | EVET | User kendi + service_role |
| support_chat_messages | EVET | User kendi session mesajları + service_role |
| ride_communications | EVET | Ride katılımcıları + service_role |
| ride_calls | EVET | Ride katılımcıları + service_role |
| emergency_alerts | EVET | Kullanıcı kendi + service_role |
| ride_share_links | EVET | Kullanıcı kendi + service_role |
| masked_contacts | EVET | Ride katılımcıları + service_role |
| communication_preferences | EVET | Kullanıcı kendi + service_role |
| communication_logs | EVET | Actor ve ride katılımcıları |
| quick_messages | EVET | Public SELECT (is_active=true) |
| taxi_rides | BILINMIYOR | Migration'da tanımlı değil (uygulama kodundan kullanılıyor) |
| taxi_drivers | BILINMIYOR | Migration'da tanımlı değil |
| orders | BILINMIYOR | Migration'da tanımlı değil |
| merchants | BILINMIYOR | Migration'da tanımlı değil |
| users | BILINMIYOR | Migration'da tanımlı değil |
| couriers | BILINMIYOR | Migration'da tanımlı değil |
| sanctions | BILINMIYOR | Migration'da tanımlı değil |
| sos_live_locations | BILINMIYOR | Migration'da tanımlı değil |
| courier_fcm_tokens | BILINMIYOR | Migration'da tanımlı değil |

> NOT: "BILINMIYOR" statüsündeki tablolar kod tarafından kullanılıyor ancak sunulan migration dosyalarında yer almıyor. Bu tablolar büyük olasılıkla başka migration'larda tanımlanmıştır (bu analize dahil edilmemiş) ya da Supabase dashboard üzerinden manuel oluşturulmuştur. RLS durumları doğrudan doğrulanamadı.

---

## CROSS-APP VERİ AKIŞ HARİTASI

| Akış | Tablo | Realtime Kanal | Çalışıyor mu? | Notlar |
|------|-------|----------------|---------------|--------|
| super_app → Sipariş oluştur | `orders` | `user_order_notifications_{userId}` (UPDATE filter: user_id) | EVET | OrderNotificationService doğru filtreli; merchant_panel aynı tabloyu okuyor |
| merchant_panel → Sipariş onayla | `orders` | — | EVET | Merchant panel status günceller |
| super_app → Sipariş durumu izle | `orders` | `user_order_notifications_{userId}` | EVET | Realtime UPDATE dinleme doğru |
| courier_app → Hazır siparişleri getir | `orders` (status=ready, courier_id=null) | Polling/Realtime | KISMEN | courier_app push notification ile bildirim alıyor; ancak 'ready' durumu merchant güncellemesi gerektirir |
| courier_app → Sipariş teslim et | `orders` | — | EVET | `update_order_status` + `increment_courier_earnings` RPC atomic |
| super_app → Taksi çağır | `taxi_rides` | `ride_{rideId}` (UPDATE filter: id) | EVET | subscribeToRide doğru filtreli |
| taxi_app → Yeni talep dinle | `taxi_rides` | `driver_pending_rides_{timestamp}` (INSERT, no filter) | DIKKAT | Filter yok — tüm INSERT'ları alır, client-side status kontrolü yapıyor |
| taxi_app → Yolculuğu kabul et | `taxi_rides` | — | EVET | `.eq('status', 'pending')` double-check yapılıyor |
| taxi_app → Tamamla → super_app güncellenir | `taxi_rides` | `ride_{rideId}` | EVET | Realtime UPDATE ile müşteri uygulaması güncellenir |
| super_app → Sürücü konum takibi | `taxi_drivers` | `driver_location_{driverId}` (UPDATE filter: id) | EVET | Doğru filtrelenmiş |
| admin_panel → User ban | `users` (is_banned=true) + `sanctions` | — | KISMI | Ban users tablosuna yazılıyor ama super_app bu alanı auth middleware'de kontrol ediyor mu belirsiz |
| car_sales/arac_satis_panel → İlan ekle | `car_listings` | — | EVET | Status='pending' → admin_panel onay → 'active' |
| super_app → Araç ilanları görüntüle | `car_listings` (status='active') | — | EVET | RLS doğru: "Public can view active listings" |
| super_app/taxi_app → SOS mesajı | `sos_live_locations` + `emergency_alerts` | — | EVET | Her iki uygulama aynı tabloları kullanıyor |
| super_app → Taxi mesajlaşma | `ride_communications` | `ride_messages_{rideId}` (INSERT filter: ride_id) | EVET | Doğru filtrelenmiş |

---

## KRİTİK

- [ ] **Hard-coded Google Maps API anahtarı kaynak kodunda** | `c:/A/supabase/functions/track-ride/index.ts:4` — `AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ` doğrudan kod içinde. Bu anahtar git geçmişinde kalıcı olarak bulunur; kötü niyetli kişiler API kotasını veya ücretlendirmeyi kötüye kullanabilir.

- [ ] **Hard-coded Supabase URL kaynak kodunda (birden fazla dosya)** | `c:/A/admin_panel/lib/core/services/supabase_service.dart:28`, `c:/A/support_panel/lib/core/services/supabase_service.dart:22`, `c:/A/merchant_panel/lib/core/services/supabase_service.dart:42`, `c:/A/rent_a_car_panel/lib/core/supabase_config.dart:5` — Supabase project URL'si (`https://mzgtvdgwxrlhgjboolys.supabase.co`) ve anon key kaynak koduna gömülmüş. Bu değerler git geçmişinde kalıcı olarak bulunur.

- [ ] **Hard-coded Supabase Anon Key kaynak kodunda (birden fazla dosya)** | `c:/A/admin_panel/lib/core/services/supabase_service.dart:30`, `c:/A/support_panel/lib/core/services/supabase_service.dart:24`, `c:/A/merchant_panel/lib/core/services/supabase_service.dart:44`, `c:/A/rent_a_car_panel/lib/core/supabase_config.dart:6` — Aynı JWT anon key tüm bu dosyalarda sabitlenmiş. Anon key'i olan herkes RLS'in izin verdiği her veriye erişebilir; tehdit modeli anon key'in gizli olduğunu varsaymaz ama git geçmişinde kalması rotasyon güçlüğü yaratır.

- [ ] **`car_brands`, `car_features`, `car_promotion_prices`, `car_settings`, `car_listing_views` tablolarında RLS YOK** | `c:/A/supabase/migrations/20260122_car_sales_tables.sql` — Bu tablolar için `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` çağrısı bulunmuyor. Anon kullanıcılar tüm marka, özellik, fiyat ve sistem ayarlarını okuyabilir/yazabilir. Özellikle `car_settings` kritik sistem yapılandırması içeriyor.

---

## YÜKSEK

- [ ] **Realtime "yeni sürüş talebi" aboneliği filtresiz** | `c:/A/taxi_app/lib/core/services/taxi_service.dart:684-705` — `subscribeToNewRides` metodu `taxi_rides` tablosunun tüm INSERT olaylarını filtre olmadan dinliyor. Her yeni yolculuk tüm online sürücülere iletiliyor; client-side `status == 'pending'` kontrolü yapılıyor ama bu, Supabase Realtime üzerinde gereksiz yük oluşturur ve potansiyel veri sızıntısına (başka müşterilerin istek bilgileri) yol açar.

- [ ] **`users` tablosuna doğrudan ban işlemi — super_app'ta kontrol mekanizması belirsiz** | `c:/A/admin_panel/lib/features/sanctions/services/sanction_service.dart:50-55` — Admin `users.is_banned=true` ayarlıyor. Ancak super_app auth katmanının bu alanı gerçek zamanlı kontrol edip etmediği kod analizinde doğrulanamadı. Kullanıcı mevcut oturumu ile `is_banned=true` olduktan sonra da uygulama kullanmaya devam edebilir.

- [ ] **Kur hesabı yarış koşulu — taxi_drivers statistics client-side güncelleniyor** | `c:/A/taxi_app/lib/core/services/taxi_service.dart:439-448` — `completeRide` fonksiyonu önce ride'ı tamamlıyor, sonra driver istatistiklerini ayrı bir UPDATE ile güncelliyor. İki işlem arasında başka bir sürüş tamamlanırsa `total_earnings` hatalı hesaplanır. Courier tarafında `increment_courier_earnings` RPC kullanılırken taxi'de bu sağlamlık yok.

- [ ] **`car_contact_requests` tablosunda kimlik doğrulamasız INSERT izni** | `c:/A/supabase/migrations/20260122_car_sales_tables.sql:536-538` — `"Anyone can create contact requests" FOR INSERT WITH CHECK (true)` politikası anonim kullanıcıların bile iletişim talebi oluşturmasına izin veriyor. Bu spam ve abuse vektörü oluşturur.

- [ ] **`secure-communication` edge function CORS: `Access-Control-Allow-Origin: '*'`** | `c:/A/supabase/functions/secure-communication/index.ts:5` — Tüm originlere açık CORS başlığı. Bu edge function kimlik doğrulama gerektiriyor ama herhangi bir alan adından çağrılabilir. En azından production domain'lere kısıtlanmalı.

---

## ORTA

- [ ] **`car_dealer_applications` tablosu admin UPDATE/DELETE politikası yok** | `c:/A/supabase/migrations/20260122_car_sales_tables.sql:246-253` — Yalnızca kullanıcı SELECT ve INSERT politikaları var. Admin paneli başvuruları approve/reject ettiğinde, `CarSalesAdminService.approveApplication()` bu güncellemeleri yapar ama RLS'de admin için güncelleme politikası tanımlı değil. Büyük olasılıkla service_role (admin panel) ile bypass ediliyor ancak açık değil.

- [ ] **`communication_service.dart`'ta `sos_live_locations` tablosu için migration/RLS kontrolü yapılamadı** | `c:/A/super_app/lib/core/services/communication_service.dart:432`, `c:/A/taxi_app/lib/core/services/communication_service.dart:486` — Her iki uygulama da bu tabloya yazıyor ama tablo migration dosyalarında tanımlı değil. RLS durumu bilinmiyor.

- [ ] **`track-ride` edge function'da hard-coded Supabase URL** | `c:/A/supabase/functions/track-ride/index.ts:3` — `const SUPABASE_URL = 'https://mzgtvdgwxrlhgjboolys.supabase.co'` environment variable yerine sabitlenmiş. Proje taşınırsa veya domain değişirse manuel güncelleme gerekir.

- [ ] **`create_ride_share_link` fonksiyonunda örnek URL hard-coded** | `c:/A/supabase/migrations/20260130_secure_communication_system.sql:477` — `'https://app.example.com/track/' || v_token` placeholder URL production'da gerçek domain olarak güncellenmemiş.

- [ ] **Driver online status güncelleme yetki kontrolü eksik** | `c:/A/super_app/lib/core/services/taxi_service.dart:775-790` — `updateDriverOnlineStatus` sadece `driverId` ile güncelleme yapıyor, `user_id` koşulu eklenmiyor (sadece `eq('id', driverId)`). Bir kullanıcı başka bir sürücünün online durumunu değiştirebilir.

- [ ] **Sipariş akışında `merchant_panel` subscription kanalı koda bakılarak doğrulanamadı** | merchant_panel servisleri bu analize dahil edilmedi. Merchant panel'in `orders` tablosunu realtime olarak dinleyip dinlemediği ve doğru filtre (`merchant_id`) kullandığı doğrulanamadı.

- [ ] **`car_listing_views` tablosu için INSERT politikası yok, tekil kullanıcı/session sınırlaması da yok** | `c:/A/supabase/migrations/20260122_car_sales_tables.sql:462-476` — Herhangi biri sonsuz görüntülenme sayısı ekleyebilir; `increment_car_listing_view` fonksiyonu `SECURITY DEFINER` ile çalışıyor ama doğrudan tablo INSERT'ü de açık.

---

## DÜŞÜK

- [ ] **JWT token süresi config'de 1 saat (3600 saniye)** | `c:/A/supabase/config.toml:152` — `jwt_expiry = 3600` makul ama `secure_password_change = false` güvenlik açığı oluşturabilir.

- [ ] **`minimum_password_length = 6` çok kısa** | `c:/A/supabase/config.toml:168` — Minimum 8 karakter önerilir, tercihen 12+.

- [ ] **`password_requirements = ""` boş** | `c:/A/supabase/config.toml:172` — Harf+rakam+sembol kombinasyonu zorunlu değil.

- [ ] **Storage bucket politikaları doğrulanamadı** | Bucket konfigürasyonu config.toml'da comment'te kalmış (`# [storage.buckets.images]`). Images bucket'ının public mi yoksa private mi olduğu bu analizde doğrulanamadı. Servis dosyalarında `getPublicUrl` kullanımı görülüyor (courier ve admin panel), bu public bucket anlamına geliyor.

- [ ] **`db.network_restrictions.allowed_cidrs = ["0.0.0.0/0"]`** | `c:/A/supabase/config.toml:71` — Production'da tüm IP'lere açık. Servis IP whitelist'i uygulanmalı.

- [ ] **Vergi numarası (`tax_number`) araç satış satıcı profilinde şifresiz saklanıyor** | `c:/A/supabase/migrations/20260122_car_sales_tables.sql:224` — `car_dealer_applications.tax_number VARCHAR(20)` plain text. Kişisel veri (TC benzeri) şifrelenmeli veya maskelenmeli.

---

## DETAYLI BULGULAR

### RLS Politika Analizi

**Migration'larda RLS Eksik Tablolar:**

1. **`car_brands`** — `ALTER TABLE car_brands ENABLE ROW LEVEL SECURITY` yok. Bu tablo tüm araç markalarını içeriyor. Admin paneli service_role ile bu tabloya yazıyor ama anon rol de yazabilir.

2. **`car_features`** — Araç donanım özellikleri listesi. RLS yok.

3. **`car_promotion_prices`** — İlan promosyon fiyatları. RLS yok. Anon kullanıcı bu tabloyu teorik olarak manipüle edebilir.

4. **`car_listing_views`** — Görüntülenme sayacı. RLS yok. INSERT politikası da yok. `increment_car_listing_view` SECURITY DEFINER fonksiyon üzerinden güvenli erişim yapılıyor ama doğrudan tablo erişimi açık.

5. **`car_settings`** — Sistem ayarları (komisyon oranı, otomatik onay vb.). RLS yok. Bu kritik bir tablo; anonim kullanıcılar `auto_approve_listings` veya `commission_rate` değerlerini okuyabilir, potansiyel olarak yazabilir.

**Service Role RLS Pattern:**

`support_chat_sessions`, `ride_communications` ve diğer tablolarda `auth.jwt() ->> 'role' = 'service_role'` pattern'i kullanılıyor. Bu doğru bir yaklaşım ancak dikkat edilmesi gereken nokta şu: Bu politikalar hem service_role JWT'si hem de normal authenticated kullanıcı JWT'si için ayrı ayrı tanımlanmış. Bu, edge function'ların service_role ile tüm verilere erişebildiği anlamına geliyor ki bu amaçlanan davranış.

### Realtime Subscription Analizi

**Doğru Filtrelenmiş Subscriptions:**

- `subscribeToRide(rideId)` — `filter: ride_id = rideId` — Doğru
- `subscribeToDriverLocation(driverId)` — `filter: id = driverId` — Doğru
- `subscribeToMessages(rideId)` — `filter: ride_id = rideId` — Doğru
- `subscribeToNewRideRequests()` (super_app) — Filtre yok ama INSERT'ta status kontrolü — Kısmen doğru
- `orderNotificationService` — `filter: user_id = userId` — Doğru
- `subscribeToDriverRatings(driverId)` — `filter: driver_id = driverId` — Doğru

**Sorunlu Subscriptions:**

- **`subscribeToNewRides()` (taxi_app)** — `taxi_rides` tablosunun tüm INSERT olaylarını filtre olmadan alıyor. Her yeni ride talebi tüm online sürücülerin aboneliğine düşüyor. Bu yüksek trafik durumunda ölçeklenme sorunu ve gereksiz veri transferi yaratır. Önerilen: driver'ın vehicle_type veya konum bazlı bir filtre eklenmeli.

### Güvenlik Bulguları

**1. Hard-coded Credentials (Kritik):**

```
admin_panel/lib/core/services/supabase_service.dart — URL + Anon Key
support_panel/lib/core/services/supabase_service.dart — URL + Anon Key
merchant_panel/lib/core/services/supabase_service.dart — URL + Anon Key
rent_a_car_panel/lib/core/supabase_config.dart — URL + Anon Key
supabase/functions/track-ride/index.ts — Supabase URL + Google Maps API Key
```

super_app, taxi_app, courier_app, taxi_app doğru şekilde `.env` dosyasından yüklüyor. Admin ve merchant paneller ile support panel ise kodu içine gömmüş.

**2. Service Role Key Kullanımı:**

Edge function'larda (`secure-communication/index.ts`) `SUPABASE_SERVICE_ROLE_KEY` ortam değişkeninden alınıyor ve client-side'da açıkta bırakılmıyor. Bu doğru yaklaşım.

Dart kod tarafında service_role key kullanımı tespit edilmedi — tüm uygulamalar anon key kullanıyor. Bu beklenen davranış.

**3. Auth Bypass Riski:**

`car_contact_requests` tablosunda `WITH CHECK (true)` politikası anonim kullanıcılara açık. Bu kasıtlı bir tasarım tercihi olabilir (satıcıya ulaşmak için kayıt gerekmez) ama bu tablo üzerinden spam ve sahte iletişim talepleri oluşturulabilir.

### Servis Katmanı Tutarlılığı

**Taksi Akışı (super_app ↔ taxi_app):**

Her iki uygulama da aynı `taxi_rides` ve `taxi_drivers` tablolarını kullanıyor. `super_app/taxi_service.dart` ile `taxi_app/taxi_service.dart` arasında tutarlı bir tablo şeması beklentisi var ve genel olarak uyumlu. Kritik nokta: `startRide` fonksiyonu taxi_app'ta hem `picked_up_at` hem `started_at` alanlarını doldururken super_app sadece `started_at` kullanıyor — bu uyumsuzluk rapor sorgularını etkileyebilir.

**Kurye Akışı (super_app → courier_app):**

Sipariş akışı: `orders` tablosunda `status='ready'` → `courier_id=null` filtresiyle courier_app görüntülüyor. Teslim: `status='delivered'`. Bu akış tutarlı. Kurye kazanç güncellemesi `increment_courier_earnings` RPC ile atomik yapılıyor — iyi tasarım.

**Araç Satış Akışı (arac_satis_panel → super_app):**

`car_listings` tablosu paylaşılıyor. İlan `status='pending'` ile oluşturulup admin onayıyla `status='active'` oluyor. super_app sadece `status='active'` olanları gösteriyor — RLS bunu doğru kısıtlıyor.

**Admin Ban Akışı:**

`sanction_service.dart` → `users.is_banned=true` güncellemesi. super_app'ın bunu kontrol ettiği kod `super_app/lib/core/providers/auth_provider.dart`'ta `users` tablosundan okunuyor. Ancak zaten oturum açmış bir kullanıcı için gerçek zamanlı oturum invalidasyonu yapılmıyor. Kullanıcı ban'lanınca mevcut JWT geçerliliğini korur (1 saat).

---

## ÖZET

- **Toplam sorun:** 18 (Kritik: 4, Yüksek: 5, Orta: 7, Düşük: 6 — bazıları birbiriyle ilişkili)
- **Migration'larda RLS eksik tablo sayısı:** 5 (`car_brands`, `car_features`, `car_promotion_prices`, `car_listing_views`, `car_settings`)
- **Migration kapsam dışı tablolar (RLS bilinmiyor):** ~10+ (`taxi_rides`, `taxi_drivers`, `orders`, `merchants`, `users`, `couriers`, `sanctions`, `sos_live_locations`, vb.)

**En önemli 3 bulgu:**

1. **Hard-coded kimlik bilgileri (URL + Anon Key + Google Maps API key) 4+ kaynak dosyasında** — Bu bilgiler git geçmişinde kalıcı olarak bulunur. Özellikle Google Maps API key'i (`AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ`) kötüye kullanılırsa maddi zarar oluşturur.

2. **`car_brands`, `car_features`, `car_promotion_prices`, `car_settings` tablolarında RLS yok** — Sistem ayarları (`auto_approve_listings`, `commission_rate`) ve iş verileri anonim erişime açık. Özellikle `car_settings` tablosunun yazılabilir olması iş mantığını değiştirme riski taşır.

3. **Admin ban → super_app gerçek zamanlı oturum invalidasyonu eksik** — Kullanıcı yasaklandığında mevcut JWT oturumu (1 saat boyunca) geçerliliğini korur. Ban anlık etkili değil.

---

## ÖNERİLER

1. **Tüm hard-coded credential'ları kaldır:** `admin_panel`, `support_panel`, `merchant_panel`, `rent_a_car_panel` uygulamalarını super_app, taxi_app ve courier_app gibi `.env` dosyası ile konfigüre edecek şekilde refactor et.

2. **Google Maps API key'i çıkar:** `track-ride/index.ts` içindeki `MAPS_API_KEY` sabitini `Deno.env.get('MAPS_API_KEY')` ile değiştir ve Supabase edge function secrets'a ekle.

3. **RLS eksik tablolara politika ekle:**
   ```sql
   ALTER TABLE car_brands ENABLE ROW LEVEL SECURITY;
   CREATE POLICY "Public read car_brands" ON car_brands FOR SELECT USING (is_active = true);
   -- Benzer şekilde car_features, car_promotion_prices için

   ALTER TABLE car_settings ENABLE ROW LEVEL SECURITY;
   -- Sadece service_role erişsin (okuma+yazma)
   CREATE POLICY "Service role only" ON car_settings FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

   ALTER TABLE car_listing_views ENABLE ROW LEVEL SECURITY;
   -- Doğrudan INSERT engelle, sadece fonksiyon üzerinden erişim
   ```

4. **Taxi_app realtime subscription'a filtre ekle:** `subscribeToNewRides` için Supabase Realtime'ın filter özelliğini kullan veya driver'ın vehicle_type bilgisini channel adına ekleyerek fan-out'u azalt.

5. **Admin ban için JWT invalidasyon mekanizması ekle:** Kullanıcı ban'landığında `auth.users`'da `is_active` veya benzeri bir flag set ederek Supabase Auth oturum sonlandırmasını tetikle. Alternatif olarak `custom_access_token` hook ile ban kontrolü JWT'ye gömülebilir.

6. **`car_contact_requests` INSERT politikasına rate limiting ekle:** Aynı `listing_id` + `phone` kombinasyonu için belirli sürede sadece 1 istek oluşturulabilir şekilde kısıtlama yap (veya en azından auth gerektir).

7. **`taxi_app.completeRide` istatistik güncellemesini atomik yap:** Client-side `total_earnings` hesaplaması yerine `increment_taxi_driver_earnings(p_driver_id, p_amount)` gibi bir RPC fonksiyonu yaz.

8. **`driver online status` güncellemesine user_id koşulu ekle:** `updateDriverOnlineStatus` fonksiyonuna `.eq('user_id', SupabaseService.currentUser!.id)` filtresi eklenerek sadece kendi profilini güncelleyebilir.

9. **Storage bucket politikalarını belgele ve private olarak değerlendir:** `images` bucket için upload politikaları tanımlanmalı; hassas belgeler (sürücü lisansı, TC kimlik vb.) public bucket'a yüklenmemeli.

10. **Eksik migration'ları oluştur:** `taxi_rides`, `taxi_drivers`, `orders`, `merchants`, `users`, `couriers`, `sanctions`, `sos_live_locations` tabloları için RLS politikalarını içeren migration dosyaları hazırlanarak sürüm kontrolüne alınmalı.
