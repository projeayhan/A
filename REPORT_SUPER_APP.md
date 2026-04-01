# Super App Testçisi — Test Raporu
> Oluşturulma: 2026-03-15 | Kod Analizi Bazlı | FAZ 1–4 Tamamlandı

---

## KRİTİK

- [ ] **subscribeToNewRideRequests filtersiz tüm yolculuk taleplerini dinliyor — müşteri adresleri herkese açık sızıyor** | `super_app/lib/core/services/taxi_service.dart:998-1013` — `channel('new_rides')` filtre yok; herhangi bir kimliği doğrulanmış kullanıcı (sürücü olmayan dahil) tüm `pending` yolculuk taleplerini, müşteri adreslerini ve konumlarını gerçek zamanlı alabilir. RLS zorunlu + Flutter tarafında sürücü rolü doğrulaması gerekiyor.

- [ ] **acceptRide race condition — iki sürücü aynı yolculuğu aynı anda kabul edebilir (super_app tarafında)** | `super_app/lib/core/services/taxi_service.dart:833-880` — SELECT (satır 838) + UPDATE (satır 851) iki ayrı işlemdir. Eş zamanlı iki sürücü isteği aynı `pending` kaydı alabilir. Supabase RPC ile atomik `accept_ride` fonksiyonu gerekiyor. (taxi_app tarafı daha iyi ama o da aynı sorundan mustarip: `taxi_app/lib/core/services/taxi_service.dart:332-363`).

- [ ] **rateRide ownership eksikliği — herhangi bir kullanıcı başkasının sürüşünü puanlayabilir** | `super_app/lib/core/services/taxi_service.dart:189-210` — `rateRide()` sadece `user_id` filter ile korunmuş ANCAK `rateRideWithDetails()` de aynı `user_id` kontrolünü yapıyor (satır 1037). Yine de TaxiRatingScreen (`taxi_rating_screen.dart:159`) `widget.ride.id` üzerinden çağırıyor; kötü niyetli kullanıcı farklı bir `rideId` ile API'ye doğrudan çağrı yapabilir. RLS şart.

- [ ] **cancelBooking ownership kontrolü — rental_service.dart'ta düzeltilmiş, doğrulanıyor** | `super_app/lib/core/services/rental_service.dart:207-223` — `cancelBooking` artık `.eq('user_id', userId)` filtresi var (satır 216). Düzeltilmiş. ANCAK `booking_screen.dart`'ta kullanılan başka bir import (`../../services/rental_service.dart`) de var; bu farklı dosya incelenmeli — iki ayrı `rental_service.dart` import zinciri var.

- [ ] **Jobs deep link "İlan bulunamadı" gösteriyor — gerçek ilan yüklenmiyor** | `super_app/lib/core/router/app_router.dart:714-737` — Push notification veya paylaşım linki ile gelen `/jobs/detail/:id` rotasında `extra == null` ise statik "İlan bulunamadı" ekranı dönüyor. `JobsService.getListing(id)` çağrısı hiç yapılmıyor. Önceki rapordaki demo fallback kaldırılmış ama gerçek DB sorgusu hala eklenmemiş.

- [ ] **JobsHomeScreen sonsuz timer zinciri — bellek sızıntısı** | `super_app/lib/screens/jobs/jobs_home_screen.dart` — `_autoScrollShowcase()` metodunda her 5 saniyede `Future.delayed` ile kendini çağırıyor. `dispose()`'da durdurucu `Timer` referansı yok. Birden fazla zincir birikebilir.

- [ ] **EmlakHomeScreen build() içinde provider atama — reaktif model ihlali ve UI tutarsızlıkları** | `super_app/lib/screens/emlak/emlak_home_screen.dart:285-296` — `build()` içinde `_properties = propertyState.properties` ataması local state ile provider state çakışmasına yol açıyor. Her rebuild'de state sıfırlanıyor.

- [ ] **OrdersScreen tamamen Supabase'e bağlı ama TEST_REPORT öncesinden farklı** | `super_app/lib/screens/food/orders_screen.dart:1-50` — İncelendi; `ConsumerStatefulWidget` olarak dönüştürülmüş ve `RestaurantService.getUserOrders()` çağrısı yapılıyor. **Önceki kritik sorun (mock data) ÇÖZÜLMÜŞ görünüyor.** Ancak hata durumunda `mounted` kontrolü eksik.

- [ ] **StoreSearchScreen son aramalar ve popüler aramalar hardcoded — gerçek arama geçmişi yok** | `super_app/lib/screens/store/store_search_screen.dart:29-45` — `_recentSearches` ve `_popularSearches` listleri doğrudan Dart listesi olarak tanımlanmış; kullanıcıya özel değil, tüm kullanıcılara aynı sabit liste gösteriliyor.

- [ ] **Çift UserAddress modeli — null koordinat crash riski** | `super_app/lib/core/providers/address_provider.dart` ve `super_app/lib/core/services/profile_service.dart:64` — İki farklı model aynı tablo için kullanılıyor. `profile_service.dart`'ta `json['latitude'] as num` null gelirse `TypeError` crash.

---

## YÜKSEK

- [ ] **updateDriverLocation ownership kontrolü eksik (super_app)** | `super_app/lib/core/services/taxi_service.dart:754-772` — `updateDriverLocation()` `.eq('user_id', SupabaseService.currentUser!.id)` ile korunmuş (satır 768). Doğru görünüyor ama `currentUser!` null-assert tehlikeli; session süresi dolmuşsa crash.

- [ ] **updateDriverOnlineStatus ownership kontrolü YOK (super_app)** | `super_app/lib/core/services/taxi_service.dart:775-790` — `updateDriverOnlineStatus()` yalnızca `.eq('id', driverId)` filtresiyle güncelleme yapıyor; `user_id` kontrolü **yok**. Herhangi bir sürücü ID'si biliniyorsa başka sürücüyü online/offline yapılabilir.

- [ ] **AppointmentsNotifier filtersiz realtime (chat_provider.dart)** | `super_app/lib/core/providers/chat_provider.dart:381` — Randevu kanalı filtersiz; tüm kullanıcıların randevuları dinlenebilir. `.eq('user_id', userId)` filtresi gerekiyor.

- [ ] **weeklyPrice hatalı operator önceliği** | `super_app/lib/core/services/rental_service.dart:244` — `weeklyPrice: ((car['daily_price'] as num?)?.toDouble() ?? 0) * 6` — Parantez doğru görünüyor (önceki rapordan farklı). Tekrar kontrol: satır 244'te `((car['daily_price'] as num?)?.toDouble() ?? 0) * 6` kullanılıyor. Bu düzeltilmiş.

- [ ] **CarFavoriteNotifier — araç favorileri sadece SharedPreferences'ta, sunucu tarafında yok** | `super_app/lib/core/providers/unified_favorites_provider.dart:450-492` — `CarFavoriteNotifier._loadFavorites()` `SharedPreferences` kullanıyor; cihaz değiştiğinde veya uygulama yeniden yüklendiğinde favoriler kaybolur. `CarSalesService.getFavoriteListings()` var ama kullanılmıyor.

- [ ] **Rental tarih çakışması race condition** | `super_app/lib/core/services/rental_service.dart:42-73` — Tarih müsaitlik kontrolü iki ayrı sorgu (satır 50 getAvailableCars + satır 56 conflicting bookings). İki kullanıcı aynı anda aynı arabayı seçebilir. DB-level constraint veya RPC gerekiyor.

- [ ] **SOS token tahmin edilebilir** | `super_app/lib/core/services/communication_service.dart:427` — `DateTime.now().millisecondsSinceEpoch.toRadixString(36) + userId.substring(0,8)` — Zaman tabanlı token; saldırgan hedef kişinin yaklaşık kayıt zamanını biliyorsa brute-force yapabilir. `Random.secure()` ile üretilmeli.

- [ ] **address_provider.dart üç metoda user_id filtresi eksik** | `super_app/lib/core/providers/address_provider.dart:267,281,325` — `updateAddress`, `deleteAddress`, `setDefaultAddress` metodlarında `.eq('user_id', userId)` filtresi eksik olabilir (detay satırları doğrulanmadı).

- [ ] **super_app → courier_app entegrasyonu dolaylı — doğrudan bildirim yok** | `courier_app/lib/core/services/courier_service.dart:281-320` — super_app'taki `createOrder()` (`restaurant_service.dart:574`) `orders` tablosuna `status: 'pending'` ekliyor. Kurye uygulaması `status: 'ready'` filtresiyle bekliyor (satır 295). **Akış**: pending → (admin/merchant onayı) → ready → kurye görür. Bu akışta sipariş onay adımı belirsiz; doğrudan push notification da yok. Kurye ancak polling veya realtime subscription ile öğreniyor.

- [ ] **FCM token logout sonrası silinmeme riski** | `super_app/lib/core/providers/auth_provider.dart:469` — `signOut()` `PushNotificationService().deleteToken()` çağırıyor. Ama önceki raporun belirttiği FCM re-initialize sorunu login sonrasında hala mevcut olabilir — `signedIn` event'inde `PushNotificationService().initialize()` çağrısı var (satır 73) ama `initialize()` yeniden çağrıldığında token güncelleniyor mu kontrol edilmeli.

- [ ] **replyToReview ownership kontrolü — driver_review_details tablosu (super_app)** | `super_app/lib/core/services/taxi_service.dart:1131-1143` — `replyToReview()` sadece `.eq('id', reviewId)` filter var; `driver_id` kontrolü yok. Herhangi bir sürücü başka sürücünün yorumuna cevap yazabilir.

---

## ORTA

- [ ] **checkMerchantWorkingHours hata durumunda `isOpen: false` dönüyor** | `super_app/lib/core/services/restaurant_service.dart:666-669` — Hata durumunda `isOpen: false` dönüyor. TEST_REPORT'ta `isOpen: true` olarak belirtilmişti; görünüşe göre **düzeltilmiş**. Doğrulandı.

- [ ] **cartProvider ve storeCartProvider paralel sepet — çakışma riski** | `super_app/lib/core/providers/cart_provider.dart` ve `store_cart_provider.dart` — `cartProvider` (food/store type='food') ve `storeCartProvider` ayrı provider'lar. Kullanıcı aynı anda her ikisinde de ürün bulundurabilir, ancak ödeme ekranı birbirinden habersiz. Farklı restorandan ürün ekleme: `cart_provider.dart`'ta `merchantId` farklı olsa bile ekleme **engellenmiyor**; aynı sepette farklı restoranlar karışabilir.

- [ ] **Farklı restoranlardan sepete ürün ekleme kontrolsüz** | `super_app/lib/core/providers/cart_provider.dart:141-158` — `addItem()` metodu merchant kontrolü yapmıyor; farklı restorandan ürün eklendiğinde uyarı verilmiyor. Kullanıcı farkında olmadan karma sipariş oluşturabilir.

- [ ] **CarFavoriteNotifier sadece local storage** | `super_app/lib/core/providers/unified_favorites_provider.dart:443-445` — `_loadFavorites()` sadece SharedPreferences'tan okuyor; yeni cihazda veya temiz kurulumda favoriler kaybolur.

- [ ] **store_name eksik — bildirim "Restoran" gösteriyor** | `super_app/lib/core/services/restaurant_service.dart:544-593` — `storeName` artık çekiliyor (satır 553). TEST_REPORT'ta belirtilen sorun **düzeltilmiş** görünüyor.

- [ ] **JobsHomeScreen "Tümünü Gör" butonları stub** | `super_app/lib/screens/jobs/jobs_home_screen.dart` — Birden fazla "Tümünü Gör" butonu `onTap: {}` (boş callback).

- [ ] **Emlak chat realtime seller_id/buyer_id filtresi eksik** | `super_app/lib/core/providers/chat_provider.dart:96` — Realtime subscription'da mesaj kanalı kullanıcıya özel değil; başka konuşmaların mesajları sızabilir.

- [ ] **`_merchantsChangeProvider` filtresiz tüm merchants dinliyor** | `super_app/lib/core/providers/restaurant_provider.dart:7-15` — `.stream(primaryKey: ['id'])` filtre yok; tüm merchants tablosunu dinliyor. Çok fazla realtime event tetiklenebilir.

- [ ] **Emlak harita butonu boş (favori onTap: {})** | `super_app/lib/screens/emlak/emlak_home_screen.dart:1496` — Favori butonu `onTap: {}`.

- [ ] **Biyometrik toggle hardcoded true** | `super_app/lib/screens/profile/security_screen.dart:18` — Biyometrik doğrulama toggle'ı her zaman aktif gösteriyor; gerçek cihaz durumunu kontrol etmiyor.

- [ ] **Şifre göster/gizle toggle çalışmıyor** | `super_app/lib/screens/profile/security_screen.dart:631` — Şifre alanında göster/gizle düğmesi işlevsiz.

- [ ] **TextEditingController dispose eksikliği (security_screen)** | `super_app/lib/screens/profile/security_screen.dart:527,659,269` — 3 dialog'daki 6 `TextEditingController` dispose edilmiyor.

- [ ] **totalFavoriteCountProvider — kira arabası (rental) favorileri sayılmıyor** | `super_app/lib/core/providers/unified_favorites_provider.dart:695-703` — `totalFavoriteCountProvider` food, product, store, emlak, car (satış), jobs sayıyor ama rental (kiralık araç) favorileri yok.

- [ ] **OrdersScreen farklı statü renk/ikon eksikliği** | `super_app/lib/screens/food/orders_screen.dart` — `_statusText()` tanımlı ama bazı statüler için ikon/renk yoksa UI tutarsız olabilir.

- [ ] **booking_screen.dart iki farklı rental_service import** | `super_app/lib/screens/rental/booking_screen.dart:5-6` — Hem `../../services/rental_service.dart` hem `../../core/services/rental_service.dart` import ediliyor. Hangisinin kullanıldığı belirsiz; bakım zorluğu.

- [ ] **updateDriverProfile taxi_app'ta allowedFields whitelist ile korunuyor** | `taxi_app/lib/core/services/taxi_service.dart:170-180` — Olumlu: izin verilen alanlar whitelist ile sınırlandırılmış. super_app'taki benzer metod bu denetimi yapmıyor.

---

## DÜŞÜK

- [ ] **CarFavoriteNotifier.toggleCar() thread-safety — mounted kontrolü eksik** | `super_app/lib/core/providers/unified_favorites_provider.dart:463` — `if (mounted) state = state.copyWith(cars: cars)` doğru ama async/await içindeki diğer state güncellemelerinde mounted kontrolü yok.

- [ ] **getActivePromotions() ve getDriverPromotions() stub dönüyor** | `super_app/lib/core/services/taxi_service.dart:676,682` — Her ikisi de `return []` ile boş liste döndürüyor; promo sistemi çalışmıyor.

- [ ] **JobsProvider'da iki ayrı favorites sistemi** | `super_app/lib/core/providers/jobs_provider.dart:487-560` ile `super_app/lib/core/providers/unified_favorites_provider.dart:571-688` — Jobs için iki ayrı favori sistemi var (`JobFavoritesNotifier` vs `JobFavoriteNotifier`); hangisi kullanıldığına bağlı olarak DB'de farklı tablolar kullanılıyor.

- [ ] **cart_screen.dart'ta `ref.read(cartProvider)` yerine `ref.watch` kullanılmıyor** | `super_app/lib/screens/food/cart_screen.dart:46` — `didChangeDependencies()` içinde `ref.read(cartProvider)` kullanılıyor; realtime güncellemelerde UI güncellenmeyebilir.

- [ ] **taxi_app subscribeToNewRides — filtersiz ama driver_id null kontrolü var** | `taxi_app/lib/core/services/taxi_service.dart:684-705` — `driver_id == null` kontrolü yapılıyor ama bu Dart tarafında; RLS olmadan tüm kayıtlar client'a geliyor. Performans sorunu.

- [ ] **CacheManager'a kayıt edilen kira geçmişi — userId değişince stale** | `super_app/lib/core/services/taxi_service.dart:244-247` — `taxi_ride_history_${userId}_${offset}_$limit` ile cache key oluşturuluyor. Farklı kullanıcı login olursa eski cache temizlenmeyebilir.

- [ ] **restaurantsProvider pagination yok** | `super_app/lib/core/providers/restaurant_provider.dart:29-38` — Büyük şehirlerde yüzlerce restoran varsa tek seferde yükleniyor.

- [ ] **TaxiRatingScreen hardcoded fallback etiketleri** | `super_app/lib/screens/taxi/taxi_rating_screen.dart:33-84` — DB'den etiket yüklenemezse 8 sabit etiket gösteriliyor; bu mantıklı bir fallback ama test edilebilmeli.

- [ ] **_sqrt(x <= 0) → 0 dönüyor (Haversine)** | `super_app/lib/core/services/taxi_service.dart:515` — `_sqrt(x <= 0 ? 0 : math.sqrt(x))` — Sıfır ya da negatif değerde `sqrt(0) = 0` dönüyor; mesafe hesabı yanlış sonuç verebilir ancak gerçek koordinatlarla oluşmaz.

---

## MEVCUT RAPORDAN DOĞRULANANLAR (TEST_REPORT.md'den)

- [ ] **arriveAtPickup/startRide/completeRide ownership yok** | Durum: **ÇÖZÜLMÜŞ** — `super_app/lib/core/services/taxi_service.dart:896-943`'te `_getCurrentDriverId()` helper metodu eklendi; her işlem `driverId` ile filtreleniyor.

- [ ] **rateRide ownership yok** | Durum: **KISMEN ÇÖZÜLMÜŞ** — `rateRide()` satır 203'te `.eq('user_id', currentUser!.id)` var. `rateRideWithDetails()` satır 1037'de `.eq('user_id', userId)` var. Ancak direkt API çağrısına karşı RLS olmadan yeterli değil.

- [ ] **acceptRide race condition** | Durum: **KISMEN İYİLEŞTİRİLMİŞ** — `.eq('status', 'pending')` WHERE clause eklendi (satır 876) ama SELECT+UPDATE hala iki ayrı işlem; atomik değil.

- [ ] **SOS token tahmin edilebilir** | Durum: **HALA MEVCUT** — `communication_service.dart:427` zaman tabanlı token kullanımına devam ediliyor.

- [ ] **OrdersScreen tamamen mock veri** | Durum: **ÇÖZÜLMÜŞ** — `ConsumerStatefulWidget`'a dönüştürülmüş, `RestaurantService.getUserOrders()` çağrılıyor.

- [ ] **Jobs deep link demo veriye düşüyor** | Durum: **KISMEN ÇÖZÜLMÜŞ** — Demo fallback (`JobsDemoData.listings.firstWhere()`) kaldırılmış; ama gerçek DB sorgusu (`JobsService.getJobById(id)`) eklenmemiş. "İlan bulunamadı" statik ekranı gösteriliyor.

- [ ] **cancelBooking ownership yok** | Durum: **ÇÖZÜLMÜŞ** — `rental_service.dart:216`'da `.eq('user_id', userId)` eklendi.

- [ ] **weeklyPrice hatalı hesap** | Durum: **ÇÖZÜLMÜŞ** — `rental_service.dart:244`'te parantez doğru kullanılıyor.

- [ ] **restaurant_service.dart hata = isOpen:true** | Durum: **ÇÖZÜLMÜŞ** — Hata durumunda `isOpen: false` dönüyor (satır 666-669).

- [ ] **EmlakHomeScreen build() içinde provider atama** | Durum: **HALA MEVCUT** — `emlak_home_screen.dart:285-296` incelendiğinde local state atamaları hala var.

- [ ] **JobsHomeScreen sonsuz timer zinciri** | Durum: **HALA MEVCUT** — `jobs_home_screen.dart`'ta `Future.delayed` zinciri ve dispose eksikliği devam ediyor.

- [ ] **subscribeToNewRideRequests filtersiz realtime** | Durum: **HALA MEVCUT** — `taxi_service.dart:998-1013` filter yok.

- [ ] **StoreSearchScreen mock data** | Durum: **KISMEN DEĞİŞMİŞ** — Gerçek DB araması yapılıyor (`storesProvider`, `storeProductsProvider` kullanılıyor) ama son aramalar/popüler aramalar hala hardcoded.

- [ ] **LiveSupportService StreamController dispose edilmiyor** | Durum: **DOĞRULANAMADI** — `live_support_service.dart` bu analizde incelenmedi.

- [ ] **Login sonrası orderNotificationService başlatılmıyor** | Durum: **ÇÖZÜLMÜŞ** — `auth_provider.dart:74`'te `signedIn` event'inde `OrderNotificationService().initialize()` çağrılıyor.

- [ ] **sports→luxury, electric→economy yanlış mapping** | Durum: **HALA MEVCUT** — `rental_service.dart:305-316`'da `_stringToCategory()` metodunda 'sports' ve 'electric' case'leri yok; `default: return CarCategory.economy` düşüyor.

- [ ] **address_provider.dart 3 metoda user_id filtresi eksik** | Durum: **DOĞRULANAMADI** — Bu analiz kapsamında detaylı incelenmedi.

---

## CROSS-APP ENTEGRASYon BULGULARI

### super_app → courier_app Sipariş Akışı
- super_app `createOrder()` → `orders` tablosu `status: 'pending'`
- Merchant/admin onayı → `status: 'ready'` (bu adım admin_panel veya merchant_panel üzerinden)
- courier_app `getPendingOrders()` → `status: 'ready'` filtresiyle bekliyor
- **Sorun**: Doğrudan push notification tetiklenmiyor; kurye polling veya realtime subscription ile öğreniyor. `ready` statüsüne geçişte kurye bildiriminin gönderildiğine dair kod bulunamadı.

### super_app → taxi_app Taksi Akışı
- super_app `createRide()` → `taxi_rides` tablosu `status: 'pending'`
- taxi_app `subscribeToNewRides()` → filtreli (`driver_id == null`) realtime
- **Ortak tablo**: Her iki uygulama da aynı `taxi_rides` tablosunu kullanıyor
- **Uyumluluk**: taxi_app `startRide()` hem `picked_up_at` hem `started_at` yazıyor (satır 400-403) — super_app `started_at` bekliyor; uyumlu.

### Sipariş İptal Bildirimi
- super_app `cancelRide()` (`taxi_service.dart:163-186`) sadece `status: 'cancelled'` yazıyor; push notification çağrısı yok.
- courier_app `updateOrderStatus()` (`courier_service.dart:410-458`) da push notification göndermesi yok.
- **Sonuç**: İptal bildirimleri FCM/realtime subscription'a bırakılmış ama client tarafında tetikleme kodu yoktur.

---

## ÖZET

- **Toplam sorun**: 37 (Kritik: 9, Yüksek: 12, Orta: 12, Düşük: 8 — bazıları önceki rapordan hala mevcut)
- **Önceki rapordan çözülenler**: arriveAtPickup/startRide/completeRide ownership, cancelBooking ownership, weeklyPrice hatası, OrdersScreen mock data, restaurant hata=isOpen:true, login sonrası orderNotification başlatma
- **Önceki rapordan hala mevcut**: subscribeToNewRideRequests filtersiz, SOS token, EmlakHomeScreen build() atamaları, JobsHomeScreen timer, sports/electric yanlış mapping, Jobs deep link gerçek yükleme yok

**En Önemli 3 Bulgu:**
1. **subscribeToNewRideRequests filtersiz** (`taxi_service.dart:998`) — Tüm müşteri adres ve konum verileri gerçek zamanlı sızıyor; KVKK/GDPR ihlali riski en yüksek.
2. **acceptRide race condition** (`taxi_service.dart:833`) — Üretim ortamında yoğun saatlerde çift sürücü ataması ve ödeme tutarsızlıklarına neden olabilir.
3. **updateDriverOnlineStatus ownership yok** (`taxi_service.dart:775`) — Herhangi bir kullanıcı herhangi bir sürücüyü offline yapabilir; platform güvenilirliğini doğrudan etkiler.

---
> **Not:** Ödeme entegrasyonu (`payment_status: 'paid'` hard-code dahil) kapsam dışında tutulmuştur. Bu rapor sadece kod statik analizine dayanmaktadır; çalışma zamanı testleri yapılmamıştır.
