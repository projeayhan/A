# SuperCyp Super App — Kapsamlı Test Raporu
> Oluşturulma: 2026-03-15 | 5 Agent Paralel Analizi | Ödeme entegrasyonu kapsam dışı

---

## YÖNETİCİ ÖZETİ

| Kategori | KRİTİK | ORTA | DÜŞÜK | Toplam |
|----------|--------|------|-------|--------|
| Güvenlik | 5 | 7 | 4 | 16 |
| Backend Servisler | 4 | 13 | 5 | 22 |
| Frontend/UI | 3 | 20 | 4 | 27 |
| Workflow/Navigasyon | 3 | 4 | 2 | 9 |
| Mimari/Kalite | 3 | 10 | 4 | 17 |
| **TOPLAM** | **18** | **54** | **19** | **91** |

---

## EN KRİTİK 10 SORUN (Öncelik Sırası)

### 🔴 #1 — Taksi Sürüş Durumu Manipülasyonu (Risk: 25/25)
- **Dosya:** `taxi_service.dart:882-920`
- **Sorun:** `arriveAtPickup()`, `startRide()`, `completeRide()` metodlarında sürücü ownership kontrolü yok. Herhangi bir kimliği doğrulanmış kullanıcı başkasının yolculuğunu "tamamlandı" olarak işaretleyebilir.
- **Etki:** Ödeme tetikleme, aktif yolculuk sabotajı.
- **Düzeltme:** Her metodda `.eq('driver_id', currentDriverId)` filtresi ekle.

### 🔴 #2 — Yeni Taksi Talebi Realtime Veri Sızıntısı (Risk: 25/25)
- **Dosya:** `taxi_service.dart:975-990`
- **Sorun:** `subscribeToNewRideRequests()` tüm taksi taleplerini filtresiz dinliyor. Müşteriler dahil tüm kullanıcılar diğer müşterilerin adreslerini ve kişisel bilgilerini realtime olarak alabilir.
- **Etki:** GDPR/KVKK ihlali, müşteri adres sızıntısı.
- **Düzeltme:** Supabase RLS zorunlu; Flutter tarafında sürücü profil doğrulaması ekle.

### 🔴 #3 — Sürücü Puanlaması Ownership Kontrolsüz (Risk: 25/25)
- **Dosya:** `taxi_service.dart:197-208`, `taxi_service.dart:1006-1013`
- **Sorun:** `rateRide()` ve `rateRideWithDetails()` metodlarında `user_id` kontrolü yok. Herhangi bir kullanıcı geçerli `rideId` ile sürücünün puanını değiştirebilir.
- **Etki:** Sürücü itibarı manipülasyonu, platform güvenilirliği zedelenir.
- **Düzeltme:** `.eq('user_id', userId)` filtresi ekle.

### 🔴 #4 — SOS Token Fiziksel Güvenlik Riski (Risk: 20/25)
- **Dosya:** `communication_service.dart:427-428`
- **Sorun:** `DateTime.now().millisecondsSinceEpoch.toRadixString(36) + userId.substring(0,8)` — tahmin edilebilir token. ~41 bit entropy.
- **Etki:** Saldırgan kurbanın canlı konumunu takip edebilir (stalking riski).
- **Düzeltme:**
  ```dart
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final token = bytes.map((b) => b.toRadixString(16).padLeft(2,'0')).join();
  ```

### 🔴 #5 — OrdersScreen Tamamen Mock Veri
- **Dosya:** `screens/food/orders_screen.dart:7-107`
- **Sorun:** `StatefulWidget` (ConsumerWidget değil), tüm sipariş verileri hardcoded (Burger King, Pizza Hut, McDonald's). Supabase entegrasyonu hiç yok.
- **Etki:** Kullanıcılar gerçek siparişlerini göremez.
- **Düzeltme:** `ConsumerStatefulWidget`'a dönüştür, `FutureProvider` ile Supabase'den çek.

### 🔴 #6 — Jobs Deep Link Her Zaman Demo Veriye Düşüyor
- **Dosya:** `app_router.dart:686-692`, `models/jobs/job_models.dart`
- **Sorun:** `/jobs/detail/:id` route'unda `extra` eksikse `JobsDemoData.listings.firstWhere()` ile sabit demo veri gösteriliyor. Push notification'dan gelen her iş ilanı linki yanlış veri açar.
- **Etki:** Production'da iş ilanları düzgün açılmıyor.
- **Düzeltme:** `JobsService.getJobById(id)` ile gerçek sorgu yap; fallback olarak 404 ekranı göster.

### 🔴 #7 — acceptRide Race Condition
- **Dosya:** `taxi_service.dart:826-875`
- **Sorun:** SELECT + UPDATE arasında iki farklı sürücü aynı yolculuğu kabul edebilir.
- **Etki:** Çift sürücü ataması, ödeme tutarsızlığı.
- **Düzeltme:** `accept_ride(p_ride_id, p_driver_id)` Supabase RPC ile atomik işlem.

### 🔴 #8 — EmlakHomeScreen Riverpod Reaktif Model İhlali
- **Dosya:** `screens/emlak/emlak_home_screen.dart:285-296`
- **Sorun:** `build()` içinde `_properties = propertyState.properties;` atamaları yapılıyor. Local state ile provider state çatışması.
- **Düzeltme:** Local field'ları kaldır, `propertyState.properties`'i doğrudan kullan.

### 🔴 #9 — Çift `UserAddress` Modeli — Null Koordinat Crash Riski
- **Dosyalar:** `address_provider.dart:8` (nullable lat/lon) ve `profile_service.dart:64` (non-nullable `as num` cast)
- **Sorun:** Aynı tablo iki farklı modelle parse ediliyor. `profile_service.dart`'ta `json['latitude'] as num` — null gelirse `TypeError` crash.
- **Düzeltme:** `profile_service.dart`'taki `UserAddress`'i kaldır, tek model kullan.

### 🔴 #10 — JobsHomeScreen Sonsuz Timer Zinciri
- **Dosya:** `screens/jobs/jobs_home_screen.dart:52-66`
- **Sorun:** `_autoScrollShowcase()` her 5 saniyede `Future.delayed` ile kendini tekrar çağırıyor. `dispose()`'da durduracak Timer referansı yok. Birden fazla zincir birikebilir.
- **Düzeltme:** `Timer.periodic` kullan, `dispose()`'da `cancel()` çağır.

---

## HIZLI DÜZELTİLEBİLECEK SORUNLAR (~30 dk - 2 saat)

| # | Dosya | Satır | Sorun | Süre |
|---|-------|-------|-------|------|
| 1 | `rental_service.dart` | 241 | `weeklyPrice: dailyPrice ?? 0 * 6` → parantez ekle | 5 dk |
| 2 | `supabase_service.dart` | 109 | `as String` → `as String?` + null check | 10 dk |
| 3 | `restaurant_service.dart` | 665 | Hata durumunda `isOpen: true` → `isOpen: false` | 5 dk |
| 4 | `rental_service.dart` | 297 | `sports→'luxury'`, `electric→'economy'` yanlış mapping düzelt | 10 dk |
| 5 | `address_provider.dart` | 267, 281, 325 | 3 metoda `.eq('user_id', userId)` ekle | 20 dk |
| 6 | `communication_service.dart` | 398 | Hard-coded Supabase URL → servis üzerinden al | 10 dk |
| 7 | `security_screen.dart` | 527, 659, 269 | 3 dialog'daki 6 `TextEditingController`'a dispose ekle | 30 dk |
| 8 | `personal_info_screen.dart` | 1037 | OTP dialog `otpController` dispose | 10 dk |
| 9 | `home_screen.dart` | 53, 97, 115 | `FutureProvider` içinde `ref.read` → `ref.watch` | 10 dk |
| 10 | `car_detail_screen.dart` | 65 | `Future.delayed` callback'ine `if (mounted)` | 5 dk |
| 11 | `chat_screen.dart` (emlak) | 49 | `await` sonrası `if (mounted)` ekle | 5 dk |
| 12 | `food_home_screen.dart` | 93 | `_showFiltersPanel` dead code kaldır | 5 dk |
| 13 | `taxi_service.dart` | 488 | `_sqrt(x <= 0)` → `x.clamp(0.0, double.infinity)` | 10 dk |
| 14 | `rental_service.dart` | 207 | `cancelBooking`'e `.eq('user_id', currentUserId)` | 10 dk |
| 15 | `communication_service.dart` | 427 | SOS token → `Random.secure()` ile üret | 15 dk |

---

## MİMARİ SORUNLAR (Uzun Vadeli Teknik Borç)

### 1. Çift Provider Karmaşası
- `userProfileProvider` (`user_provider.dart:104`) + `profileDataProvider` (`profile_provider.dart:11`) → aynı tabloyu iki katmandan okuyor
- `cartProvider` + `storeCartProvider` → neredeyse identik yapı
- `UnifiedFavoritesProvider` + `StoreFavoriteProvider` + `ProductFavoriteProvider` → 3 ayrı favorites

### 2. God-Provider: AuthNotifier
- `auth_provider.dart` hem oturum yönetimi hem DB yazma hem profil senkronizasyonu yapıyor
- `users` tablosuna 6 farklı dosyadan doğrudan erişim (`auth_provider`, `user_provider`, `profile_service`, `live_support_service`, `login_screen`, `supabase_service`)

### 3. Model Duplikasyonu
- `UserAddress` → 2 farklı şema (`address_provider.dart` vs `profile_service.dart`)
- `Restaurant` → servis dosyasına gömülü (`restaurant_service.dart:6`)
- `JobListing` (demo) + `JobListingData` (Supabase) → iki paralel model
- `Restaurant.fromMerchantJson()` + `Store.fromMerchant()` → aynı tablo, iki model

### 4. Navigasyon Tutarsızlığı
- Taksi akışının tamamı `Navigator.push` ile açılıyor; GoRouter stack'i dışında çalışıyor
- **GoRouter'da tanımsız ama kullanılan ekranlar:** `TaxiDestinationScreen`, `TaxiVehicleSelectionScreen`, `PropertyFilterScreen`, `RentalLocationPicker`
- Bazı ekranlar hem GoRouter'da tanımlı hem `Navigator.push` ile açılıyor (çift stack)

### 5. Servis Katmanı Tekrarı
- `RestaurantService` + `StoreService` + `MarketService` → 3 servis, aynı `merchants` tablosu, ~1638 satır tekrar
- Pagination: `emlak` ve `jobs`'ta var; `restaurant`/`store`/`market`'ta yok
- `autoDispose`: Family provider'larda hiç kullanılmıyor → bellek birikimi

### 6. İki Harita Kütüphanesi
- `google_maps_flutter` (taksi/rental) + `flutter_map` + `latlong2` (emlak, sadece 2 ekran)
- `flutter_map` kaldırılabilir; emlak haritaları Google Maps'e geçilebilir

---

## MODÜL BAZLI BULGULAR

### 🚕 Taksi Modülü
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| arriveAtPickup/startRide/completeRide ownership yok | KRİTİK | taxi_service.dart:882 |
| subscribeToNewRideRequests filtersiz realtime | KRİTİK | taxi_service.dart:975 |
| rateRide ownership yok | KRİTİK | taxi_service.dart:197 |
| acceptRide race condition | KRİTİK | taxi_service.dart:826 |
| updateDriverLocation ownership yok | YÜKSEK | taxi_service.dart:749 |
| Taksi akışı GoRouter dışında | KRİTİK | taxi_home_screen.dart:84 |
| TaxiDestination/VehicleSelection route tanımsız | KRİTİK | app_router.dart |
| 10+ metod try-catch yok | ORTA | taxi_service.dart |
| deleteSavedLocation ownership yok | YÜKSEK | taxi_service.dart:421 |
| Realtime payload `as double?` cast hatası | ORTA | taxi_service.dart:356 |

### 🏠 Emlak Modülü
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| build() içinde provider atama — reaktif model ihlali | KRİTİK | emlak_home_screen.dart:285 |
| Chat realtime seller_id filtresi eksik | ORTA | chat_provider.dart:96 |
| Favori butonu boş (onTap: {}) | ORTA | emlak_home_screen.dart:1496 |
| Telefon/dosya butonları stub | ORTA | chat_screen.dart:229 |
| AppointmentsNotifier filtersiz realtime | YÜKSEK | chat_provider.dart:381 |

### 🍔 Yemek Modülü
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| OrdersScreen tamamen hardcoded mock veri | KRİTİK | orders_screen.dart:7 |
| createOrder null döndürüyor | KRİTİK | restaurant_service.dart:521 |
| store_name alanı yazılmıyor — bildirimde "Restoran" | ORTA | restaurant_service.dart:572 |
| Arama "Tüm sonuçları gör" stub | ORTA | food_home_screen.dart:1396 |
| Notification overlay ref.read stale UI | ORTA | food_home_screen.dart:439 |
| Hata = isOpen:true (kapalı restorandan sipariş) | ORTA | restaurant_service.dart:665 |

### 🛒 Mağaza Modülü
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| StoreSearchScreen mock data | KRİTİK | store_search_screen.dart:71 |
| featuredAsync.whenData() — loading/error yok | ORTA | store_detail_screen.dart:292 |
| Store siparişleri realtime overlay göstermiyor | ORTA | order_notification_service.dart |

### 🚗 Araç Kiralama
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| cancelBooking ownership yok | KRİTİK | rental_service.dart:207 |
| weeklyPrice hatalı hesap | KRİTİK | rental_service.dart:241 |
| Tarih müsaitlik race condition | KRİTİK | rental_service.dart:42 |
| sports→luxury, electric→economy yanlış mapping | ORTA | rental_service.dart:297 |

### 💼 İş İlanları
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| JobsHomeScreen sonsuz timer zinciri | KRİTİK | jobs_home_screen.dart:52 |
| Jobs deep link demo veriye düşüyor | KRİTİK | app_router.dart:686 |
| JobListing + JobListingData iki paralel model | KRİTİK | job_models.dart |
| "Tümünü Gör" butonları boş | ORTA | jobs_home_screen.dart:127 |

### 👤 Profil & Güvenlik
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| 3 dialog'da 6 TextEditingController dispose yok | KRİTİK | security_screen.dart:527,659,269 |
| Biyometrik toggle hardcoded true | ORTA | security_screen.dart:18 |
| Şifre göster/gizle toggle çalışmıyor | ORTA | security_screen.dart:631 |
| userProfileProvider isim çakışması | ORTA | profile_provider.dart + user_provider.dart |

### 🔔 Bildirim Sistemi
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| Login sonrası orderNotificationService başlatılmıyor | KRİTİK | auth_provider.dart:56 |
| property_message push notification chat'e gitmiyor | ORTA | main.dart:219 |
| FCM re-login sonrası initialize edilmiyor | KRİTİK | auth_provider.dart, main.dart |
| Tek cihaz token upsert (çoklu cihaz sorunu) | ORTA | push_notification_service.dart:163 |
| deleteToken tüm token'ları siliyor | ORTA | push_notification_service.dart:280 |

### 💬 Canlı Destek
| Sorun | Şiddet | Dosya:Satır |
|-------|--------|------------|
| StreamController dispose edilmiyor → memory leak | KRİTİK | live_support_service.dart:11 |

---

## GÜVENLİK RİSK MATRİSİ

| # | Sorun | Olasılık | Etki | Risk |
|---|-------|----------|------|------|
| 1 | arriveAtPickup/startRide/completeRide ownership yok | Yüksek | Kritik | **25/25** |
| 2 | subscribeToNewRideRequests filtersiz | Yüksek | Kritik | **25/25** |
| 3 | rateRide ownership yok | Yüksek | Kritik | **25/25** |
| 4 | Ücret hesabı client-side, sunucu doğrulama yok | Yüksek | Yüksek | **20/25** |
| 5 | SOS token tahmin edilebilir | Orta | Kritik | **20/25** |
| 6 | updateDriverLocation ownership yok | Orta | Yüksek | **15/25** |
| 7 | AppointmentsNotifier filtersiz realtime | Orta | Yüksek | **15/25** |
| 8 | updateAddress ownership yok | Orta | Yüksek | **15/25** |
| 9 | cancelBooking ownership yok | Orta | Yüksek | **15/25** |
| 10 | deactivateShareLink ownership yok | Orta | Yüksek | **15/25** |
| 11 | .env APK içine paketleniyor | Düşük | Kritik | **15/25** |
| 12 | Chat realtime buyer_id filtresi eksik | Orta | Orta | **12/25** |
| 13 | Rol kontrolü fail-open | Düşük | Orta | **8/25** |

---

## DÜZELTME PLANI

### FAZ 1 — Hızlı Kritik (Bugün/Yarın, ~4 saat)
1. `rental_service.dart:241` — weeklyPrice parantez hatası
2. `supabase_service.dart:109` — null-safe cast
3. `restaurant_service.dart:665` — hata = kapalı say
4. `auth_provider.dart:462` — logout FCM token sil
5. `auth_provider.dart:56` — signedIn'de FCM + orderNotification init
6. `store_search_screen.dart:71` — mock data kaldır
7. `security_screen.dart` — 6 TextEditingController dispose
8. `personal_info_screen.dart:1037` — OTP dialog controller dispose
9. `home_screen.dart:52-122` — FutureProvider içinde ref.watch
10. `communication_service.dart:427` — SOS token güvenli üretim

### FAZ 2 — Güvenlik & Yetkilendirme (Bu Hafta, ~2-3 gün)
1. `taxi_service.dart:882` — arriveAtPickup/startRide/completeRide + sürücü kontrolü
2. `taxi_service.dart:197` + `1006` — rateRide ownership check
3. `taxi_service.dart:749` — updateDriverLocation ownership check
4. `rental_service.dart:207` — cancelBooking user_id filtresi
5. `address_provider.dart` — 3 metoda user_id filtresi
6. `chat_provider.dart:96` — buyer+seller realtime filtresi
7. `communication_service.dart:398` — hard-coded URL kaldır
8. `taxi_service.dart` — 10+ metoda try-catch
9. `jobs_home_screen.dart:52` — Timer.periodic + dispose
10. `live_support_service.dart:11` — StreamController lifecycle

### FAZ 3 — Navigasyon & Mimari (Gelecek Hafta, ~3-4 gün)
1. `app_router.dart` — TaxiDestination + TaxiVehicleSelection route ekle
2. `taxi_home_screen.dart` — Navigator.push → context.push
3. `app_router.dart:686` — Jobs demo fallback → JobsService.getJobById
4. `orders_screen.dart` — Supabase entegrasyonu
5. `profile_provider.dart` — profileDataProvider kaldır
6. `profile_service.dart:64` — çift UserAddress birleştir
7. `emlak_home_screen.dart:285` — build() içi provider atama kaldır
8. `restaurant_service.dart` — createOrder null → exception

### FAZ 4 — UX İyileştirmeleri (Serbest Zaman)
1. Security screen şifre toggle
2. Emlak chat butonları (gizle veya implement)
3. Shimmer loading (food/store)
4. NetworkImage → CachedNetworkImage (avatarlar)
5. Restaurant/Store/Market provider'larına pagination
6. autoDispose family provider'lara ekle
7. flutter_map → google_maps_flutter geçişi (emlak)

---

## MİMARİ SKOR KARTI

| Kategori | Puan | Not |
|----------|------|-----|
| Provider Mimarisi | 5/10 | Çift provider, God-provider AuthNotifier, StateNotifier eski API |
| Model Tutarlılığı | 4/10 | Çift UserAddress, Restaurant gömülü, JobListing iki model |
| Güvenlik | 3/10 | Çoklu ownership eksikliği, filtersiz realtime, tahmin edilebilir token |
| Navigasyon | 6/10 | GoRouter iyi kurulmuş ama taksi akışı tamamen dışarıda |
| Hata Yönetimi | 5/10 | Bazı servisler null, bazıları exception — tutarsız |
| Performans | 6/10 | Pagination bazı modüllerde var, family autoDispose eksik |
| Kod Kalitesi | 5/10 | 3000+ satır dosyalar, mock data production'da |

**Toplam Teknik Borç: ~17 gün efor** | **Faz 1+2 (Kritik): ~5.5 gün**

---

> **Not:** Ödeme entegrasyonu (`store_service.dart:443` ve `market_service.dart:329`'daki `payment_status: 'paid'` hard-code dahil) şirket yapısı hazır olana kadar kapsam dışında tutulmuştur.
