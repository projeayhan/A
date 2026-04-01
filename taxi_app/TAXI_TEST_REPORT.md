# Taxi App — Kapsamlı Test Raporu
**Tarih:** 2026-03-15
**Analiz Edilen Proje:** `c:\A\taxi_app`
**Dart SDK:** ^3.10.4 | Flutter Riverpod ^3.1.0 | Go Router ^17.0.1 | Supabase ^2.12.0

---

## Özet

| Önem Seviyesi | Sayı |
|---|---|
| KRİTİK | 8 |
| YÜKSEK | 10 |
| ORTA | 13 |
| DÜŞÜK | 7 |
| **TOPLAM** | **38** |

> ⚡ **K7 ve K8 hemen düzeltildi** (cancelled enum, started_at/picked_up_at uyum)

---

## KRİTİK SORUNLAR

### K1 — `.env` dosyası `.gitignore`'da yok
**Dosya:** `.gitignore`
**Sorun:** `SUPABASE_URL` ve `SUPABASE_ANON_KEY` içeren `.env` dosyası `.gitignore`'a eklenmemiş. Bir git commit'te bu dosya repoya gömülürse credentials herkese açık olur.
**Düzeltme:** `.gitignore`'a `.env` ekle.

```
# .gitignore'a ekle:
.env
*.env
```

---

### K2 — IDOR: `arriveAtPickup`, `startRide`, `cancelRide` — sahiplik kontrolü yok
**Dosya:** `lib/core/services/taxi_service.dart`, satır 337-434
**Sorun:** Bu üç fonksiyon yalnızca `rideId`'ye göre update yapıyor. Herhangi bir oturum açmış sürücü, başka bir sürücünün aktif yolculuğunu manipüle edebilir.

```dart
// SORUNLU — herhangi bir sürücü çağırabilir:
await _client.from('taxi_rides')
    .update({'status': 'arrived', ...})
    .eq('id', rideId);  // ← driver_id kontrolü yok!
```

**Düzeltme:** Her üç fonksiyona da driver sahiplik kontrolü ekle:

```dart
static Future<bool> arriveAtPickup(String rideId) async {
  final driver = await getDriverProfile();
  if (driver == null) return false;
  try {
    final result = await _client
        .from('taxi_rides')
        .update({'status': 'arrived', 'arrived_at': DateTime.now().toIso8601String(), 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', rideId)
        .eq('driver_id', driver['id'])  // ← sahiplik kontrolü
        .select();
    return (result as List).isNotEmpty;
  } catch (e) {
    debugPrint('arriveAtPickup error: $e');
    return false;
  }
}
// startRide ve cancelRide için aynı pattern
```

---

### K3 — IDOR: `completeRide` — sahiplik kontrolü yok
**Dosya:** `lib/core/services/taxi_service.dart`, satır 375-413
**Sorun:** `completeRide` sadece `.eq('id', rideId)` ile güncelleme yapıyor. Herhangi bir sürücü herhangi bir yolculuğu tamamlayabilir.
**Düzeltme:** `arriveAtPickup` ile aynı pattern — `getDriverProfile()` çek, `.eq('driver_id', driver['id'])` ekle.

---

### K4 — `updateDriverProfile` hassas alan koruması yok
**Dosya:** `lib/core/services/taxi_service.dart`, satır 158-174
**Sorun:** `updateDriverProfile` caller'dan gelen `updates` map'ini filtresiz olarak DB'ye yazıyor. Bir sürücü `status`, `is_verified`, `rating`, `total_earnings` gibi kritik alanları kendi kendine değiştirebilir.

```dart
await _client.from('taxi_drivers')
    .update({...updates, 'updated_at': ...})  // ← filtresiz!
    .eq('id', driver['id']);
```

**Düzeltme:** İzin verilen alan whitelist'i ekle:

```dart
static const _allowedProfileUpdateFields = {
  'bank_name', 'bank_iban', 'bank_account_holder',
  'phone', 'vehicle_brand', 'vehicle_model', 'vehicle_plate',
  'vehicle_color', 'vehicle_year', 'vehicle_types',
  'profile_photo_url', 'notification_settings',
};

static Future<bool> updateDriverProfile(Map<String, dynamic> updates) async {
  final driver = await getDriverProfile();
  if (driver == null) return false;

  final safeUpdates = Map.fromEntries(
    updates.entries.where((e) => _allowedProfileUpdateFields.contains(e.key)),
  );
  if (safeUpdates.isEmpty) return false;
  // ...
}
```

---

### K5 — SOS token zayıf entropi
**Dosya:** `lib/core/services/communication_service.dart`, satır 480-481
**Sorun:** SOS canlı takip token'ı tahmin edilebilir değerlerle oluşturuluyor:

```dart
final token = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
    userId.substring(0, 8);  // ← zaman damgası + kısmi UUID
```

Birisi timestamp aralığını ve userId'yi bilirse URL'yi tahmin edebilir.
**Düzeltme:** `dart:math` `Random.secure()` ile gerçek rastgele token üret:

```dart
import 'dart:math';
// ...
final rand = Random.secure();
final token = List.generate(32, (_) => rand.nextInt(256))
    .map((b) => b.toRadixString(16).padLeft(2, '0'))
    .join();
```

---

### K6 — Hard-coded Supabase URL (SOS tracking)
**Dosya:** `lib/core/services/communication_service.dart`, satır 449
**Sorun:** SOS tracking URL'si `dotenv` yerine hard-coded:

```dart
static const String _supabaseUrl = 'https://mzgtvdgwxrlhgjboolys.supabase.co';
```

**Düzeltme:**
```dart
static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
```
Ayrıca `flutter_dotenv` importunu da ekle.

---

## YÜKSEK ÖNCELIKLI SORUNLAR

### Y1 — `refresh_token` hard cast crash
**Dosya:** `lib/core/services/supabase_service.dart`, satır 72
**Sorun:** `refresh_token as String` — null dönerse `Null check operator used on a null value` hatası.

```dart
final refreshToken = data['refresh_token'] as String;  // ← crash!
```

**Düzeltme:**
```dart
final refreshToken = data['refresh_token'] as String?;
if (refreshToken == null) throw Exception('Oturum tokeni alınamadı');
```

---

### Y2 — `acceptRide` race condition (TOCTOU)
**Dosya:** `lib/core/services/taxi_service.dart`, satır 300-333
**Sorun:** Pending kontrolü ve update ayrı sorgular — iki sürücü aynı ride'ı eş zamanlı kabul edebilir. Update'te `.eq('status', 'pending')` guard var ama sonuç kontrol edilmiyor: update 0 kayıt güncelledi mi bilinmiyor.

**Düzeltme:** Update sonucunun gerçekten değişiklik yaptığını kontrol et:

```dart
final result = await _client
    .from('taxi_rides')
    .update({'driver_id': driver['id'], 'status': 'accepted', ...})
    .eq('id', rideId)
    .eq('status', 'pending')
    .select('id');  // güncellenen satırı döndür

if ((result as List).isEmpty) {
  debugPrint('acceptRide: Race condition — ride already taken');
  return false;
}
return true;
```

---

### Y3 — `authStateChanges.listen()` StreamSubscription memory leak
**Dosya:** `lib/core/providers/auth_provider.dart`, satır 60-68
**Sorun:** `SupabaseService.authStateChanges.listen()` bir `StreamSubscription` döndürüyor fakat referans tutulmuyor ve hiçbir zaman `cancel()` çağrılmıyor.

**Düzeltme:** `AuthNotifier`'a subscription saklama ekle:

```dart
class AuthNotifier extends Notifier<AuthState> {
  StreamSubscription<AuthState>? _authSub;

  @override
  AuthState build() {
    ref.onDispose(() => _authSub?.cancel());
    _init();
    return const AuthState();
  }

  void _init() async {
    // ...
    _authSub = SupabaseService.authStateChanges.listen((authState) async {
      // ...
    });
  }
}
```

---

### Y4 — `signOut` driver profil cache'ini temizlemiyor
**Dosya:** `lib/core/providers/auth_provider.dart`, satır 376-379
**Sorun:** Çıkış yapıldığında `TaxiService.invalidateProfileCache()` çağrılmıyor. Sonraki kullanıcı (farklı sürücü) eski kullanıcının verilerini görebilir.

**Düzeltme:**
```dart
Future<void> signOut() async {
  TaxiService.invalidateProfileCache();  // ← ekle
  await SupabaseService.signOut();
  state = const AuthState(status: AuthStatus.unauthenticated);
}
```

---

### Y5 — Askıya alınmış hesap (`AuthStatus.error`) yönlendirmesi yok
**Dosya:** `lib/core/router/app_router.dart`, satır 34-67
**Sorun:** Redirect mantığı `AuthStatus.error` durumunu ele almıyor. Hesabı askıya alınmış bir sürücü uygulama içinde gezinmeye devam edebilir.

**Düzeltme:** Redirect'e suspended kontrolü ekle:

```dart
final isSuspended = authState.status == AuthStatus.error;
if (isSuspended && state.matchedLocation != '/login') {
  return '/login';
}
```

---

### Y6 — `onTokenRefresh.listen()` subscription iptal edilmiyor
**Dosya:** `lib/core/services/push_notification_service.dart`, satır 55
**Sorun:** `_messaging.onTokenRefresh.listen(_saveTokenToSupabase)` için dönen `StreamSubscription` kaydedilmiyor ve `dispose()`'da iptal edilmiyor.

**Düzeltme:** Field ekle ve dispose'da cancel:

```dart
StreamSubscription? _tokenRefreshSub;

// initialize():
_tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveTokenToSupabase);

// dispose():
void dispose() {
  _tokenRefreshSub?.cancel();
  _notificationController?.close();
  _notificationController = null;
}
```

---

### Y7 — `directions_service.dart` hard cast null crash
**Dosya:** `lib/core/services/directions_service.dart`, satır 52-54
**Sorun:** API yanıtı beklenmedik format döndürürse (null, network error sonrası kısmi JSON) `(data['distance_meters'] as num).toDouble()` crash verir.

**Düzeltme:**
```dart
final distanceMeters = (data['distance_meters'] as num?)?.toDouble() ?? 0.0;
final durationSeconds = (data['duration_seconds'] as num?)?.toInt() ?? 0;
final routePointsData = (data['route_points'] as List?) ?? [];
```

---

### Y8 — Yeni yolculuk dialog'u online olmayan sürücüye de gösteriliyor
**Dosya:** `lib/screens/home/home_screen.dart`, satır 103-123
**Sorun:** `_setupRealtimeSubscription()` yeni yolculuk geldiğinde `isOnline` kontrolü yapmadan hem ses çalıp hem dialog açıyor.

**Düzeltme:**
```dart
_ridesChannel = TaxiService.subscribeToNewRides((newRide) {
  if (!ref.read(isOnlineProvider)) return;  // ← ekle
  // ...
  _showNewRideNotification(newRide);
});
```

---

### Y9 — Yeni yolculuk dialog'u aktif yolculuk varken açılıyor
**Dosya:** `lib/screens/home/home_screen.dart`, satır 136-149
**Sorun:** `_showNewRideNotification` sürücünün zaten aktif bir yolculuğu olup olmadığını kontrol etmiyor.

**Düzeltme:**
```dart
void _showNewRideNotification(Map<String, dynamic> ride) {
  final activeRide = ref.read(activeRideProvider).asData?.value;
  if (activeRide != null && activeRide.isActive) return;  // ← zaten aktif
  showDialog(/* ... */);
}
```

---

### Y10 — `completeRide` total_earnings race condition
**Dosya:** `lib/core/services/taxi_service.dart`, satır 394-407
**Sorun:** `total_rides` ve `total_earnings` değerleri önce okunup sonra yazılıyor (read-modify-write). Eşzamanlı çağrılar aynı eski değeri okuyup üzerine yazarsa sayaçlar kaybolur.

**Düzeltme:** DB'de increment kullan:
```dart
await _client.from('taxi_drivers').rpc('increment_driver_stats', params: {
  'driver_id': driver['id'],
  'fare_amount': fare,
});
// Veya mevcut DB rpc yoksa:
await _client.rpc('complete_ride_stats', params: {
  'p_driver_id': driver['id'],
  'p_fare': fare,
});
```
Ya da Supabase DB function ile atomic update yapılmalı.

---

## ORTA ÖNCELİKLİ SORUNLAR

### O1 — `_init()` async void — hata sessizce yutulur
**Dosya:** `lib/core/providers/auth_provider.dart`, satır 51-68
**Sorun:** `build()` içinde `_init()` unawaited çağrılıyor. Herhangi bir hata `build()`'e yansımaz.

**Düzeltme:** Hatayı yakala ve state'e yansıt:
```dart
void _init() async {
  try {
    // ...
  } catch (e) {
    state = AuthState(status: AuthStatus.error, errorMessage: 'Başlatma hatası: $e');
  }
}
```

---

### O2 — `getEarningsSummary` 5 sıralı DB sorgusu
**Dosya:** `lib/core/services/taxi_service.dart`, satır 504-606
**Sorun:** today/week/month/allTime için 4 ayrı sorgu + getCommissionRate = 5 sıralı sorgu. Ekran açılışında 1-2 saniyelik gecikme.

**Düzeltme:** Tüm zamanları kapsayan tek sorgu ile client-side filtreleme yap:
```dart
final allRides = await _client
    .from('taxi_rides')
    .select('fare, completed_at')
    .eq('driver_id', driver['id'])
    .eq('status', 'completed')
    .not('completed_at', 'is', null)
    .gte('completed_at', monthStart.toIso8601String());

// Sonra today/week/month'u Dart'ta hesapla
```

---

### O3 — `markMessagesAsRead` ownership kontrolü yok
**Dosya:** `lib/core/services/communication_service.dart`, satır 117-133
**Sorun:** Herhangi bir kullanıcı herhangi bir `rideId`'deki mesajları okundu olarak işaretleyebilir. `.eq('ride_id', rideId)` yanında ride sahipliği doğrulanmıyor.

---

### O4 — `updateCallStatus` ownership kontrolü yok
**Dosya:** `lib/core/services/communication_service.dart`, satır 190-218
**Sorun:** `callId` bilinen herhangi biri arama durumunu güncelleyebilir. Caller doğrulaması yok.

---

### O5 — SOS emergency contacts akışında `context.mounted` kontrolü eksik
**Dosya:** `lib/core/services/communication_service.dart`, satır 598-601
**Sorun:** `Navigator.of(context).pushNamed('/emergency-contacts')` çağrısından önce tek `context.mounted` kontrolü var, ancak dialog await'inden sonra context başka bir dialog açmadan önce de kontrol edilmeli.

---

### O6 — `deactivateShareLink`, `getShareLinks` ownership doğrulaması yok
**Dosya:** `lib/core/services/communication_service.dart`, satır 289-296
**Sorun:** `linkId` bilen herhangi biri paylaşım linkini deaktif edebilir. RLS yoksa IDOR riski var.

---

### O7 — `push_notification_service` — `_notificationController` lazy init race
**Dosya:** `lib/core/services/push_notification_service.dart`, satır 31-34
**Sorun:** `_notificationController` yalnızca `onNotificationTap` getter'ı ilk çağrıldığında oluşturuluyor. `initialize()` sırasında bir bildirim gelirse ve henüz `onNotificationTap` erişilmemişse, o bildirim event'i kaybolur.

**Düzeltme:** `initialize()` içinde veya constructor'da controller'ı oluştur.

---

### O8 — `app_router.dart` — Profile alt rotaları ShellRoute'ta bottom nav bozuluyor
**Dosya:** `lib/core/router/app_router.dart`, satır 111-134
**Sorun:** `/personal-info`, `/vehicle-info`, `/payment-info` gibi rotalar ShellRoute içinde olduğundan alt navbar görünmeye devam ediyor. Bu sub-screens için navbar gizlenmeli.

**Düzeltme:** Bu rotaları ShellRoute dışına taşı veya ShellRoute builder'da path'e göre navbar'ı gizle.

---

### O9 — `EarningsSummary` model / servis uyumsuzluğu
**Dosya:** `lib/models/ride_models.dart`, `lib/core/services/taxi_service.dart:505-605`
**Sorun:** `getEarningsSummary()` `commission_rate`, `commission_amount`, `net_earnings` gibi alanlar döndürüyor ama `EarningsSummary` modelinde bu alanlar tanımlı değil. Servis raw `Map` döndürüyor, model kullanılmıyor.

**Düzeltme:** `EarningsSummary` modelini servis çıktısıyla senkronize et veya servis direkt model döndürsün.

---

### O10 — `replyToReview` farklı tablolara yazıyor (cross-app uyumsuzluk)
**Dosya:** `lib/core/services/taxi_service.dart:744`, `super_app: taxi_service.dart:1131`
**Sorun:** taxi_app `taxi_rides.driver_reply` alanına yazıyor; super_app `driver_review_details.driver_reply` alanına yazıyor. Sürücünün cevabı müşteride görünmüyor.

**Düzeltme:** Hangi tablo kanoniktir belirlenmeli ve her iki uygulama aynı tabloya yazmalı.

---

### O11 — `completeRide` N+1 sorgu
**Dosya:** `lib/core/services/taxi_service.dart:375-413`
**Sorun:** `getRide()` + `getDriverProfile()` + `update taxi_rides` + `update taxi_drivers` = tek yolculuk tamamlama için 4 sıralı DB çağrısı.

**Düzeltme:** DB'de `complete_ride` stored procedure / Edge Function ile atomik hale getir.

---

### O12 — `createDriverProfile` session için `Future.delayed(500ms)` hack
**Dosya:** `lib/core/services/taxi_service.dart:67`
**Sorun:** `await Future.delayed(const Duration(milliseconds: 500))` session kurulmasını beklemek için kırılgan bir yöntem. Yavaş bağlantılarda yetersiz kalabilir.

**Düzeltme:** `SupabaseService.authStateChanges` stream'ini dinleyerek session ready event'ini bekle.

---

### O13 — 95 adet `debugPrint` — kişisel veri konsola yazılıyor
**Dosya:** `lib/core/services/taxi_service.dart:79,108` ve diğerleri
**Sorun:** `createDriverProfile` içinde `userId`, `email` gibi kişisel veriler production build'larda da konsola yazılıyor.

**Düzeltme:** `if (kDebugMode) debugPrint(...)` guard'ı ekle veya merkezi bir logger servisi kullan.

---

## DÜŞÜK ÖNCELİKLİ SORUNLAR

### D1 — `main.dart` Firebase init hatası yakalanmıyor
**Dosya:** `lib/main.dart`, satır 23-25
**Sorun:** `Firebase.initializeApp()` başarısız olursa uygulama hata mesajı göstermeden crash verebilir.

**Düzeltme:**
```dart
try {
  await Firebase.initializeApp();
} catch (e) {
  debugPrint('Firebase init failed: $e');
  // Push notifications devre dışı ama uygulama devam etsin
}
```

---

### D2 — `directions_service.dart` — Uygulama kaynaklı route noktaları için tip yok
**Dosya:** `lib/core/services/directions_service.dart`
**Sorun:** `LatLng` sınıfı `google_maps_flutter`'ın kendi `LatLng` tipiyle çakışıyor ve manual dönüşüm gerektiriyor. Kod karmaşıklığı artıyor.

**Düzeltme:** `google_maps_flutter`'ın `LatLng`'ini doğrudan kullan veya dosya adında typedef ekle.

---

### D3 — `home_screen.dart` — Yeni yolculuk dialog'u overlay ile çakışabilir
**Dosya:** `lib/screens/home/home_screen.dart`, satır 136-149
**Sorun:** Birden fazla yolculuk talebi kısa süre içinde gelirse, önceki dialog kapanmadan yeni dialog açılabilir (dialog stack birikimi).

**Düzeltme:** Dialog açık olup olmadığını flag ile takip et.

---

### D4 — `SOS tracking URL` `.env` gerektirmeden build olabilir
**Dosya:** `lib/core/services/communication_service.dart`
**Sorun:** K6 ile bağlantılı — URL `.env`'den çekilmezse test/staging ortamında production URL'si kullanılır.

---

### D5 — `vehicleTypes` sürücü profili cache TTL çok kısa
**Dosya:** `lib/core/services/taxi_service.dart`, satır 14
**Sorun:** 60 saniyelik cache TTL çok kısa. Admin sürücü tipini güncelledikten sonra 60 sn içinde cache expire olacak; bu sürede wrong vehicle type filtrelemesi devam eder.

---

### D6 — Riverpod ^3.1.0 vs super_app ^2.6.1 — major versiyon uyumsuzluğu
**Dosya:** `pubspec.yaml:15` vs `super_app/pubspec.yaml:20`
**Sorun:** Her iki uygulama Riverpod'un farklı major versiyonlarını kullanıyor. go_router, supabase_flutter ve diğer paketlerde de önemli versiyon farklılıkları var. Ortak dependency'lerin senkronize edilmesi gerekiyor.

---

### D7 — Provider'lar ekran dosyasında tanımlanmış
**Dosya:** `lib/screens/home/home_screen.dart:14-38`
**Sorun:** `driverProfileProvider`, `pendingRidesProvider`, `activeRideProvider`, `isOnlineProvider` `lib/core/providers/` altında olması gerekirken home_screen.dart içinde tanımlanmış. Test edilemez ve yeniden kullanılamaz.

**Düzeltme:** Tüm provider'ları `lib/core/providers/home_provider.dart` (veya uygun bir dosyaya) taşı.

---

## DÜZELTME PLANI

### FAZ 1 — Güvenlik (Acil)
K1, K2, K3, K4, K5, K6, Y1

1. `.gitignore`'a `.env` ekle
2. `arriveAtPickup`, `startRide`, `cancelRide`, `completeRide`'a driver ownership kontrolü ekle
3. `updateDriverProfile`'a whitelist filtresi ekle
4. SOS token'ı `Random.secure()` ile yeniden yaz
5. Hard-coded URL'yi env'den çek
6. `refresh_token` null-safe cast düzelt

### FAZ 2 — Kritik Hatalar
Y2, Y3, Y4, Y5, Y6

1. `acceptRide` select ile race condition kontrolü
2. `authStateChanges` subscription cancel
3. `signOut`'ta cache invalidation
4. Suspended hesap router redirect
5. `onTokenRefresh` subscription cancel

### FAZ 3 — Yüksek Öncelik
Y7, Y8, Y9, Y10

1. `directions_service` null-safe cast
2. Online kontrolü realtime callback'e ekle
3. Aktif yolculuk varken dialog açılmasını engelle
4. `completeRide` atomic stats update

### FAZ 4 — Orta/Düşük Öncelik
O1-O8, D1-D5

1. `_init()` hata handling
2. `getEarningsSummary` sorgu optimizasyonu
3. `markMessagesAsRead` / `updateCallStatus` ownership
4. FCM controller lazy init düzelt
5. Profile rotalar ShellRoute dışına
6. Firebase init error handling

---

## FAZ 1 PROMPT

```
Aşağıdaki 7 güvenlik düzeltmesini uygula:

1. c:\A\taxi_app\.gitignore dosyasına `.env` satırı ekle

2. taxi_service.dart — arriveAtPickup, startRide, cancelRide, completeRide:
   Her dörtte de başa `final driver = await getDriverProfile(); if (driver == null) return false;` ekle
   ve her update sorgusuna `.eq('driver_id', driver['id'])` ekle

3. taxi_service.dart — updateDriverProfile:
   Aşağıdaki whitelist'i kullan ve sadece izin verilen alanları güncelle:
   {'bank_name','bank_iban','bank_account_holder','phone','vehicle_brand',
    'vehicle_model','vehicle_plate','vehicle_color','vehicle_year',
    'vehicle_types','profile_photo_url','notification_settings'}

4. communication_service.dart — _createSosTracking:
   token üretimini şu şekilde değiştir:
   ```dart
   import 'dart:math';
   final rand = Random.secure();
   final token = List.generate(32, (_) => rand.nextInt(256))
       .map((b) => b.toRadixString(16).padLeft(2, '0')).join();
   ```

5. communication_service.dart — satır 449:
   `static const String _supabaseUrl` → `static String get _supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';`
   ve `package:flutter_dotenv/flutter_dotenv.dart` import ekle

6. supabase_service.dart — satır 72:
   `as String` → `as String?`
   ve bir sonraki satıra: `if (refreshToken == null) throw Exception('Oturum tokeni alınamadı');`

7. communication_service.dart — markMessagesAsRead:
   ride ownership kontrolü için önce `taxi_rides` tablosundan ride'ın bu sürücüye ait olduğunu doğrula
```

---

## FAZ 2 PROMPT

```
Aşağıdaki 5 kritik hata düzeltmesini uygula:

1. taxi_service.dart — acceptRide:
   Update sorgusuna `.select('id')` ekle ve sonuç empty list ise false döndür:
   ```dart
   final result = await _client.from('taxi_rides')
       .update({...}).eq('id', rideId).eq('status', 'pending').select('id');
   return (result as List).isNotEmpty;
   ```

2. auth_provider.dart — AuthNotifier:
   `StreamSubscription<AuthState>? _authSub;` field ekle
   build()'e `ref.onDispose(() => _authSub?.cancel());` ekle
   _init() içinde `SupabaseService.authStateChanges.listen(...)` → `_authSub = SupabaseService.authStateChanges.listen(...)`

3. auth_provider.dart — signOut:
   `await SupabaseService.signOut();` satırından önce `TaxiService.invalidateProfileCache();` ekle

4. app_router.dart — redirect:
   AuthStatus.error (askıya alınmış) için login yönlendirmesi ekle:
   ```dart
   if (authState.status == AuthStatus.error &&
       !isLoggingIn && !isRegistering) {
     return '/login';
   }
   ```

5. push_notification_service.dart — onTokenRefresh:
   `StreamSubscription? _tokenRefreshSub;` field ekle
   initialize()'da: `_tokenRefreshSub = _messaging.onTokenRefresh.listen(_saveTokenToSupabase);`
   dispose()'a: `_tokenRefreshSub?.cancel();` ekle
```

---

## FAZ 3 PROMPT

```
Aşağıdaki 4 düzeltmeyi uygula:

1. directions_service.dart — getDirections:
   Hard cast'leri null-safe yap:
   ```dart
   final distanceMeters = (data['distance_meters'] as num?)?.toDouble() ?? 0.0;
   final durationSeconds = (data['duration_seconds'] as num?)?.toInt() ?? 0;
   final routePointsData = (data['route_points'] as List?) ?? const [];
   ```

2. home_screen.dart — _setupRealtimeSubscription:
   Callback başına ekle: `if (!ref.read(isOnlineProvider)) return;`

3. home_screen.dart — _showNewRideNotification:
   Başına ekle:
   ```dart
   final activeRide = ref.read(activeRideProvider).asData?.value;
   if (activeRide != null && activeRide.isActive) return;
   ```

4. home_screen.dart — _showNewRideNotification:
   Birden fazla dialog açılmasını önlemek için:
   ```dart
   bool _isDialogShowing = false;

   void _showNewRideNotification(Map<String, dynamic> ride) {
     if (_isDialogShowing) return;
     _isDialogShowing = true;
     showDialog(
       context: context,
       barrierDismissible: false,
       builder: (ctx) => _NewRideDialog(
         ride: ride,
         onAccept: () async {
           Navigator.pop(ctx);
           _isDialogShowing = false;
           await _acceptRide(ride['id']);
         },
         onDecline: () {
           Navigator.pop(ctx);
           _isDialogShowing = false;
         },
       ),
     ).then((_) => _isDialogShowing = false);
   }
   ```
```

---

> **Not:** `ride_detail_screen.dart`'taki sorunların çoğu (_isDisposed flag, mounted kontrolleri, dispose()) zaten doğru şekilde yönetiliyor. `_subscribeToRide()` yalnızca initState'de bir kez çağrılıyor ve dispose()'da unsubscribe yapılıyor.

---

## MİMARİ KALİTE SKORU

| Kategori | Puan (1-10) | Not |
|----------|-------------|-----|
| Provider Mimarisi | 5/10 | Provider'lar ekranda, autoDispose yok |
| Model Katmanı | 6/10 | fromJson iyi, toJson yok, EarningsSummary uyumsuzluğu |
| Servis Katmanı | 6/10 | IDOR açıkları, N+1, session hack |
| Güvenlik | 5/10 | Brute force var; IDOR, debugPrint kişisel veri |
| Super App Uyumu | 4/10 | cancelled enum bug, picked_up_at vs started_at (hemen düzeltildi) |
| **Genel** | **5.2/10** | |

---

*Rapor 5 agent ile oluşturulmuştur. 38 sorun tespit edilmiştir (8 KRİTİK, 10 YÜKSEK, 13 ORTA, 7 DÜŞÜK).*
*K7 (cancelled enum) ve K8 (started_at/picked_up_at uyum) + D7 (displayName Türkçe) hemen düzeltildi.*
