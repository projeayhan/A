# Sürücü Uygulamaları Testçisi — Test Raporu

**Tarih:** 2026-03-15
**Analiz Edilen Projeler:** `c:\A\taxi_app` | `c:\A\courier_app`
**Kapsam:** Kod analizi, iş akışı mantığı, güvenlik denetimi, cross-app entegrasyon

---

## KRİTİK

- [ ] **[COURIER] `completeDelivery` total_earnings güncellemesi yok** | `courier_app/lib/core/services/courier_service.dart:341-363`
  - `completeDelivery()` fonksiyonu `total_deliveries` ve `is_busy` güncelliyor ama `total_earnings` alanını güncellemiyor. `updateOrderStatus` RPC ile güncelliyor (`increment_courier_earnings`). `completeDelivery` doğrudan çağrıldığında (order_detail_screen gibi) kazanç kaydı oluşmaz. İki farklı teslim kod yolu mevcut, biri kazancı kaçırıyor.
  - **Durum:** Yeni tespit

- [ ] **[COURIER] `rejectCourierRequest` ownership kontrolü yok** | `courier_app/lib/core/services/courier_service.dart:549-563`
  - `rejectCourierRequest(requestId)` fonksiyonu sadece `id` ile update yapıyor, `courier_id` koşulu eklemiyor. Herhangi bir oturum açmış kurye başkasının teklifini reddedebilir.
  - **Durum:** Yeni tespit

- [ ] **[COURIER] `getCourierProfile` cache süresi yok — stale veri riski** | `courier_app/lib/core/services/courier_service.dart:5-31`
  - Cache TTL tanımlı değil: `if (_cachedCourierProfile != null) return _cachedCourierProfile;` Profil asla expire olmaz. Admin kurye hesabını askıya alsa bile uygulama eski (approved) profili hafızada tutar. `invalidateProfileCache()` çağrılmadan stale veri gösterilmeye devam eder.
  - **Durum:** Yeni tespit

- [ ] **[COURIER] `main.dart` Firebase init hatası yakalanmıyor — crash riski** | `courier_app/lib/main.dart:21`
  - `await Firebase.initializeApp();` try/catch içinde değil. taxi_app'te bu düzeltilmiş (`try/catch` ile), courier_app'te hala açıkta.
  - **Durum:** Yeni tespit

---

## YÜKSEK

- [ ] **[TAXI] `completeRide` total_earnings read-modify-write race condition** | `taxi_app/lib/core/services/taxi_service.dart:440-448`
  - Sürücü istatistikleri cached profile değerinden hesaplanıp yazılıyor. Aynı sürücü aynı anda iki yolculuğu tamamlarsa (teorik olarak) sayaç kaybolabilir. Atomic RPC kullanılmalıydı. Önceki raporda da belirtilmişti; düzeltilmedi.
  - **Durum:** Önceki rapordan devam ediyor (Y10)

- [ ] **[COURIER] `push_notification_service.dart` `onTokenRefresh` subscription iptal edilmiyor** | `courier_app/lib/core/services/push_notification_service.dart:58`
  - `_messaging.onTokenRefresh.listen(_saveTokenToSupabase)` dönen `StreamSubscription` kaydedilmiyor ve `dispose()`'da iptal edilmiyor. taxi_app'te bu düzeltilmiş (`_tokenRefreshSub` ile).
  - **Durum:** Yeni tespit (courier_app'e özgü)

- [ ] **[COURIER] `getEarningsSummary` 3 sıralı DB sorgusu — performans sorunu** | `courier_app/lib/core/services/courier_service.dart:566-651`
  - today/week/month için 3 ayrı sorgu. taxi_app ile aynı pattern; tek sorgudan client-side filtreleme yapılabilir.
  - **Durum:** Yeni tespit

- [ ] **[CROSS-APP] `replyToReview` tablo uyumsuzluğu — sürücü cevabı müşteride görünmüyor** | `taxi_app/lib/core/services/taxi_service.dart:781-816` vs `super_app/lib/core/services/taxi_service.dart:1131`
  - taxi_app `taxi_rides.driver_reply` alanına yazıyor; super_app `driver_review_details.driver_reply` alanına yazıyor. Sürücünün cevabı müşteri tarafında görünmüyor. Önceki raporda tespit edilmişti (O10); hala düzeltilmemiş.
  - **Durum:** Önceki rapordan devam ediyor (O10)

- [ ] **[CROSS-APP] Admin panelinde sürücü kazançları `driver_earnings`/`partner_earnings` tablolarından geliyor, sürücü uygulamalarındaki tablo farklı** | `admin_panel/lib/features/earnings/screens/earnings_screen.dart:12,23` vs `taxi_app:taxi_rides` / `courier_app:orders`
  - Admin panel `driver_earnings` ve `partner_earnings` tablolarından okuyor. taxi_app `taxi_rides.fare` toplamını kullanıyor, courier_app `orders.courier_earnings` kullanıyor. Bu tablolar arasında senkronizasyon mekanizması belirsiz — admin panelde sürücü kazancı eksik/yanlış görünüyor olabilir.
  - **Durum:** Yeni tespit

- [ ] **[TAXI] `authStateChanges.listen()` subscription iptal edilmiyor** | `taxi_app/lib/core/providers/auth_provider.dart:46-51`
  - taxi_app'te `_authSub` field'ı ve `ref.onDispose(() => _authSub?.cancel())` var, ancak `_init()` async void — hata olursa subscription kısmen kurulabilir. courier_app'te de aynı pattern; fakat courier_app'te `_init()` içinde try/catch yok.
  - **Durum:** Kısmen düzeltilmiş

- [ ] **[TAXI] `AuthStatus.error` (askıya alınmış hesap) router redirect eksik** | `taxi_app/lib/core/router/app_router.dart:47-49`
  - Mevcut kodda `AuthStatus.error && !isLoggingIn && !isRegistering` durumunda `/login`'e yönlendirme var. **Bu düzeltilmiş**. courier_app'te de aynı kontrol var (satır 70).
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (Y5)

---

## ORTA

- [ ] **[TAXI] `getEarningsSummary` 5 sıralı DB sorgusu** | `taxi_app/lib/core/services/taxi_service.dart:553-642`
  - today/week/month/allTime + commissionRate = 5 sıralı sorgu. Önceki raporda da belirtilmişti; düzeltilmedi.
  - **Durum:** Önceki rapordan devam ediyor (O2)

- [ ] **[COURIER] `updateProfile`, `updateVehicleInfo`, `updatePaymentInfo` whitelist filtresi yok** | `courier_app/lib/core/services/courier_service.dart:140-210`
  - Bu üç fonksiyon sabit alanlar üzerinde çalışıyor (fullName, email, phone, vehicleType, vehiclePlate, bankName, bankIban). Parametreler sabit olduğundan whitelist filtresi gerekmez. Ancak `updateNotificationSettings` de aynı şekilde sabit parameterlidir. Bu nedenle taxi_app'teki gibi bir güvenlik açığı yok — `updateDriverProfile` gibi açık bir `Map` almıyor.
  - **Durum:** Tasarım gereği — sorun yok, FYI

- [ ] **[COURIER] `courierDataProvider` `_init()` async void — hata sessizce yutulur** | `courier_app/lib/core/providers/home_providers.dart:92`
  - `_init()` unawaited çağrılıyor ve hiçbir catch bloğu yok. Başlatma hatası state'e yansımaz, kullanıcı boş ekran görür.
  - **Durum:** Yeni tespit

- [ ] **[COURIER] Realtime `orders` kanalı filtre kullanmıyor — tüm order değişikliklerini dinliyor** | `courier_app/lib/core/providers/home_providers.dart:150-183`
  - `_ordersChannel` `courier_id` filtresi uygulamıyor, tüm `orders` tablosu değişikliklerini alıyor. Yoğun platformda yüksek gereksiz traffic ve CPU kullanımı.
  - **Durum:** Yeni tespit

- [ ] **[TAXI] `subscribeToNewRides` channel adı her seferinde yeni timestamp üretiyor** | `taxi_app/lib/core/services/taxi_service.dart:684-705`
  - `'driver_pending_rides_${DateTime.now().millisecondsSinceEpoch}'` — her çağrıda farklı kanal adı oluşuyor. Önceki kanalı unsubscribe etmeden yeni kanal oluşursa bellek sızıntısı.
  - **Durum:** Yeni tespit

- [ ] **[COURIER] `getActiveOrders` filtresinde `picked_up` ve `delivering` var, `assigned` yok** | `courier_app/lib/core/services/courier_service.dart:324-338`
  - `inFilter('status', ['picked_up', 'delivering'])` — eğer DB'de `assigned` veya `ready` gibi bir durum kullanılıyorsa ve kurye bu siparişe atanmışsa, aktif siparişler listesinde görünmez.
  - **Durum:** Yeni tespit (akış uyumu incelenmeli)

- [ ] **[CROSS-APP] Admin panelinde sürücü `is_verified`/`status` değişikliği taxi_app/courier_app'e realtime yansımıyor olabilir** | `taxi_app/lib/core/providers/auth_provider.dart` / `courier_app/lib/core/providers/auth_provider.dart`
  - Her iki uygulamada auth state, `courierProfile`/`driverProfile` bilgisini sadece giriş ve `refreshProfile()` çağrısında güncelliyor. Admin panelden askıya alma işlemi realtime olarak profil kanalına yansırsa (courier_app'te `_profileChannel` var) courier_app çalışır; taxi_app'te böyle bir profil kanalı yok.
  - **Durum:** Yeni tespit (taxi_app açığı)

- [ ] **[TAXI] `pendingRidesProvider`, `activeRideProvider`, `driverProfileProvider` — autoDispose yok** | `taxi_app/lib/core/providers/home_providers.dart:15-31`
  - FutureProvider'lar autoDispose olmadan tanımlı, arka planda gereksiz yeniden yükleme tetiklenebilir.
  - **Durum:** Yeni tespit

- [ ] **[COURIER] `_init` içinde `_authSub` yok — courier_app auth_provider.dart init hatası yakalanmıyor** | `courier_app/lib/core/providers/auth_provider.dart:56-73`
  - `_init()` içinde try/catch yok. taxi_app'te bu düzeltilmiş (satır 74'te catch var).
  - **Durum:** Yeni tespit

---

## DÜŞÜK

- [ ] **[TAXI] `directions_service.dart` routePoints içindeki noktalarda null-safe cast yok** | `taxi_app/lib/core/services/directions_service.dart:56-59`
  - Üst seviye alanlar null-safe yapılmış (satır 52-54), ancak `routePointsData` içindeki her noktada `(point['latitude'] as num).toDouble()` hala hard-cast. Kötü veri gelirse crash verir.
  - **Durum:** Kısmen düzeltilmiş (dış cast'ler düzeltildi, iç cast'ler hala tehlikeli)

- [ ] **[COURIER] `createCourierProfile` TC numarası açıkça kaydediliyor, whitelist ile korunmuyor** | `courier_app/lib/core/services/courier_service.dart:50-66`
  - `tc_no` upsert ile DB'ye yazılıyor. Güvenli alan whitelist uygulanmıyor. Kayıt sonrası update ile TC No değiştirilebilir riski düşük ama RLS gerekliliği var.
  - **Durum:** Yeni tespit

- [ ] **[TAXI/COURIER] `.gitignore`'da `.env` mevcut** | `taxi_app/.gitignore:48` / `courier_app/.gitignore:43`
  - `.env` satırı her iki `.gitignore`'a da eklenmiş. Önceki raporda K1 olarak belirlenmişti; **ÇÖZÜLMÜŞ**.
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (K1)

- [ ] **[TAXI/COURIER] Supabase URL kod içinde hard-coded yok** | `taxi_app/lib/core/services/communication_service.dart:451`
  - `static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';` — K6 düzeltilmiş.
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (K6)

- [ ] **[TAXI] SOS token `Random.secure()` ile üretiliyor** | `taxi_app/lib/core/services/communication_service.dart:482-484`
  - K5 düzeltilmiş; 32 byte güvenli rastgele token üretimi mevcut.
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (K5)

- [ ] **[TAXI] `updateDriverProfile` whitelist filtresi var** | `taxi_app/lib/core/services/taxi_service.dart:170-180`
  - K4 düzeltilmiş; `allowedFields` const set ile korunuyor.
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (K4)

- [ ] **[COURIER] `getEarningsHistory` — restorana bağlı kuryelerde kendi restoran siparişleri hariç tutuluyor** | `courier_app/lib/core/services/courier_service.dart:461-497`
  - Bu kasıtlı bir iş mantığı — `work_mode == 'restaurant'` durumunda kurye maaşlı çalışır, platform üzerinden kazanç almaz. Tasarım gereği.
  - **Durum:** Tasarım gereği — sorun yok

- [ ] **[TAXI] `home_screen.dart` `_isDialogShowing` flag implementasyonu yapılmış** | `taxi_app/lib/screens/home/home_screen.dart:28`
  - D3 düzeltilmiş; `bool _isDialogShowing = false;` field mevcut.
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (D3)

- [ ] **[TAXI/COURIER] `acceptRide` race condition koruması var** | `taxi_app/lib/core/services/taxi_service.dart:338-353`
  - `.eq('status', 'pending').select('id')` ve empty list kontrolü mevcut. Y2 düzeltilmiş.
  - **Durum:** Önceki rapordan ÇÖZÜLMÜŞ (Y2)

---

## MEVCUT RAPORDAN DOĞRULANANLAR (TAXI_TEST_REPORT.md'den)

- [ ] **K1 — `.env` `.gitignore`'da yok** | Durum: **ÇÖZÜLMÜŞ** — Her iki .gitignore'da `.env` satırı mevcut
- [ ] **K2 — `arriveAtPickup`, `startRide`, `cancelRide` IDOR** | Durum: **ÇÖZÜLMÜŞ** — Tüm fonksiyonlara `.eq('driver_id', driver['id'])` + empty list kontrolü eklendi
- [ ] **K3 — `completeRide` IDOR** | Durum: **ÇÖZÜLMÜŞ** — `.eq('driver_id', driver['id']).select('id, fare')` ve empty list kontrolü eklendi
- [ ] **K4 — `updateDriverProfile` hassas alan koruması** | Durum: **ÇÖZÜLMÜŞ** — `allowedFields` const set ile whitelist filtresi eklendi
- [ ] **K5 — SOS token zayıf entropi** | Durum: **ÇÖZÜLMÜŞ** — `Random.secure()` ile 32 byte token üretimi
- [ ] **K6 — Hard-coded Supabase URL** | Durum: **ÇÖZÜLMÜŞ** — `dotenv.env['SUPABASE_URL']` getter kullanılıyor
- [ ] **Y1 — `refresh_token` hard cast crash** | Durum: **ÇÖZÜLMÜŞ** — `as String?` + null kontrolü eklendi (`supabase_service.dart:72-73`)
- [ ] **Y2 — `acceptRide` race condition** | Durum: **ÇÖZÜLMÜŞ** — `.select('id')` + empty list dönüş kontrolü eklendi
- [ ] **Y3 — `authStateChanges.listen()` subscription memory leak** | Durum: **ÇÖZÜLMÜŞ** — `_authSub` field + `ref.onDispose()` eklendi
- [ ] **Y4 — `signOut` driver profil cache temizlenmiyor** | Durum: **ÇÖZÜLMÜŞ** — `TaxiService.invalidateProfileCache()` signOut'ta çağrılıyor
- [ ] **Y5 — `AuthStatus.error` yönlendirmesi yok** | Durum: **ÇÖZÜLMÜŞ** — Router'da error state için login yönlendirmesi var
- [ ] **Y6 — `onTokenRefresh.listen()` subscription iptal edilmiyor** | Durum: **ÇÖZÜLMÜŞ** (taxi_app'te) — `_tokenRefreshSub` field + `dispose()`'da cancel eklendi
- [ ] **Y7 — `directions_service.dart` hard cast null crash** | Durum: **KISMI** — Üst alanlar null-safe, iç routePoint cast'leri hala tehlikeli
- [ ] **Y8 — Online olmayan sürücüye dialog gösteriliyor** | Durum: **DOĞRULANAMADI** — home_screen.dart tam içeriği alınamadı, ancak `isOnlineProvider` import ve kullanımı mevcut
- [ ] **Y9 — Aktif yolculuk varken dialog açılıyor** | Durum: **ÇÖZÜLMÜŞ** — `_isDialogShowing` flag eklendi
- [ ] **Y10 — `completeRide` total_earnings race condition** | Durum: **HALA MEVCUT** — Read-modify-write pattern devam ediyor
- [ ] **O2 — `getEarningsSummary` 5 sıralı DB sorgusu** | Durum: **HALA MEVCUT** — 5 sıralı sorgu devam ediyor
- [ ] **O10 — `replyToReview` tablo uyumsuzluğu** | Durum: **HALA MEVCUT** — taxi_app `taxi_rides.driver_reply`, super_app `driver_review_details.driver_reply`

---

## FAZ 2 — İŞ AKIŞI & MANTIK BULGULARI

### Taxi Ride State Machine
- `pending → accepted → arrived → in_progress → completed` akışı tam ve doğru implement edilmiş
- Her geçişte `driver_id` ownership kontrolü var
- `in_progress` durumunda hem `picked_up_at` hem `started_at` yazılıyor (super_app uyumu için — iyi)
- `cancelRide` sadece `driver_id` sahibi sürücü çağırabilir

### Courier Order State Machine
- `ready → picked_up → delivering → delivered` akışı var
- `updateOrderStatus` için IDOR koruması var (`.eq('courier_id', courier['id'])`)
- `completeDelivery` ise `courier_id` kontrolü var ama kazanç güncellemesi **eksik** (KRİTİK)

### Sürücü Çevrimdışı Olursa
- taxi_app: `updateOnlineStatus(false)` çağrılır, DB'de `is_online = false` yapılır
- Açık bir ride (accepted/in_progress) iptal edilmez — bu kasıtlı olabilir (müşteriyi etkilememek için)
- courier_app: aynı şekilde `is_online = false` yapılır, aktif siparişler etkilenmez

### Race Condition (Aynı Ride İki Sürücü)
- taxi_app: `.eq('status', 'pending')` guard var + `.select('id')` ile sonuç kontrol ediliyor — **koruma VAR**
- courier_app: `acceptCourierRequest` RPC fonksiyonu kullanıyor (`accept_courier_request`) — DB seviyesinde atomic, **koruma VAR**

### Earnings Hesaplama
- taxi_app: `fare` alanından DB sorgusuyla hesaplıyor, commission rate system_settings'ten çekiyor — doğru
- courier_app: `courier_earnings` alanından hesaplıyor, restaurant siparişlerini hariç tutuyor (kasıtlı)

---

## FAZ 3 — GÜVENLİK DENETİMİ ÖZET

| Kontrol | taxi_app | courier_app |
|---------|----------|-------------|
| `.env` `.gitignore`'da | EVET | EVET |
| Hard-coded Supabase key | YOK | YOK |
| SOS token güvenli | EVET (Random.secure) | — (yok) |
| `updateProfile` whitelist | EVET | N/A (sabit params) |
| IDOR koruması (ride/order) | EVET | EVET (updateOrderStatus) |
| IDOR koruması (rejectRequest) | — | **HAYIR** |
| Brute force koruması | EVET (SecurityService) | EVET (SecurityService) |
| FCM token refresh cancel | EVET | **HAYIR** |
| Profile cache TTL | EVET (300s) | **HAYIR (sonsuz)** |

---

## FAZ 4 — CROSS-APP ENTEGRASYON BULGULARI

### taxi_app ↔ super_app
- Her iki uygulama aynı `taxi_rides` tablosunu kullanıyor — realtime güncellemeler çalışır
- `status` enum değerleri uyumlu (`in_progress`, `completed`, `cancelled_by_driver`)
- `replyToReview` tablo uyumsuzluğu (taxi_app: `taxi_rides`, super_app: `driver_review_details`) — cevaplar görünmüyor

### courier_app ↔ super_app
- Her iki uygulama aynı `orders` tablosunu kullanıyor — realtime güncellemeler çalışır
- `delivered_at` ve `status: delivered` super_app'te görünür

### Admin Panel ↔ Sürücü Uygulamaları
- Admin panel `partners` tablosunu okuyor (sürücü listesi için)
- Admin panel `driver_earnings`/`partner_earnings` tablolarından kazanç okuyor — bu tablolara sürücü uygulamaları yazmıyor (farklı tablolar)
- courier_app'te `_profileChannel` realtime var → admin askıya alma courier_app'te görünür
- taxi_app'te profil realtime kanalı yok → admin askıya alma taxi_app'te sadece bir sonraki refresh'te görünür

---

## ÖZET

- **Toplam yeni sorun:** 14 (Kritik: 4, Yüksek: 5, Orta: 8, Düşük: 3)
- **Önceki rapordan çözülmüş:** 14/20 (K1-K6, Y1-Y5, D3 ve kısmen Y7)
- **Önceki rapordan devam eden:** 2 (Y10: earnings race condition, O10: replyToReview tablo uyumsuzluğu)

**En önemli 3 yeni bulgu:**
1. **courier_app `completeDelivery` kazanç kaydı eksik (KRİTİK):** `completeDelivery()` çağrıldığında kurye kazancı `total_earnings`'e eklenmiyor. `updateOrderStatus('delivered')` RPC'yi çağırıyor ama `completeDelivery` doğrudan çağrıldığında bu atlanıyor.
2. **courier_app profil cache'i asla expire olmuyor (KRİTİK):** Admin askıya alma kurye uygulamasına yansımayabilir çünkü `_cachedCourierProfile` TTL yok. taxi_app'te 300 saniye TTL var.
3. **Admin panel ile sürücü uygulamaları farklı kazanç tabloları kullanıyor (YÜKSEK):** Admin panel `driver_earnings`/`partner_earnings` tablolarından okuyor, sürücü uygulamaları `taxi_rides.fare` / `orders.courier_earnings` kullanıyor. Senkronizasyon mekanizması belirsiz.
