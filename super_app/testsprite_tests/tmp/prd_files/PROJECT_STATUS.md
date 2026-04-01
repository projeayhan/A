# SUPER APP - Proje Durum Dosyası

> **ÖNEMLİ:** Her yeni sohbete başlarken bu dosyayı oku!
> Son Güncelleme: 2026-01-05

---

## 📱 Proje Bilgileri

| Özellik | Değer |
|---------|-------|
| Proje Adı | Super App |
| Platform | Flutter (Android + iOS + Web) |
| Backend | Supabase (%100) |
| State Management | Riverpod |
| Navigation | Go Router |
| Proje Dizini | `c:/A/super_app` |

---

## 🎯 7 Hizmet (Planlandı)

1. 🍔 **Yemek** - Yemek siparişi ✅ (TAMAMLANDI)
2. 🛒 **Market** - Market alışverişi (Placeholder)
3. 📦 **Kurye** - Kurye servisi (Placeholder)
4. 🚕 **Taksi** - Taksi çağırma (Placeholder)
5. 🔧 **Hizmet** - Ev hizmetleri (Placeholder)
6. 📅 **Randevu** - Randevu sistemi (Placeholder)
7. 💰 **Cüzdan** - Ödeme sistemi (Placeholder)

---

## ✅ Tamamlanan Ekranlar

### Auth Ekranları

#### 1. Giriş (Login) Ekranı
- **Dosya:** `lib/screens/auth/login_screen.dart`
- E-posta/şifre ile giriş, Google/Apple ile giriş, Dark/Light tema

#### 2. Kayıt (Register) Ekranı
- **Dosya:** `lib/screens/auth/register_screen.dart`
- Form validasyonu, Google/Apple ile kayıt

#### 3. Şifremi Unuttum Ekranı
- **Dosya:** `lib/screens/auth/forgot_password_screen.dart`
- Supabase şifre sıfırlama entegrasyonu

### Ana Ekranlar

#### 4. Ana Sayfa (Home)
- **Ana Shell:** `lib/screens/main_shell.dart`
- **Home İçeriği:** `lib/screens/home/home_screen.dart`
- Bottom Navigation (4 tab), 7 Servis kartı, Promosyon banner

#### 5. Profil Ekranı
- **Dosya:** `lib/screens/profile/profile_screen.dart`
- Profil bilgileri, menü öğeleri, çıkış butonu

---

## 🍔 Yemek Servisi (TAMAMLANDI)

### Ekranlar

| Ekran | Dosya | Durum |
|-------|-------|-------|
| Yemek Ana Sayfa | `lib/screens/food/food_home_screen.dart` | ✅ |
| Restoran Detay | `lib/screens/food/restaurant_detail_screen.dart` | ✅ |
| Yemek Detay | `lib/screens/food/food_item_detail_screen.dart` | ✅ |
| Sepet | `lib/screens/food/cart_screen.dart` | ✅ |
| Sipariş Başarılı | `lib/screens/food/order_success_screen.dart` | ✅ |
| Sipariş Takip | `lib/screens/food/order_tracking_screen.dart` | ✅ |
| Siparişlerim | `lib/screens/food/orders_screen.dart` | ✅ |

### Widget'lar

| Widget | Dosya | Açıklama |
|--------|-------|----------|
| Restoran Kartı | `lib/widgets/food/restaurant_card.dart` | Restoran listesi için |
| Menü Item Kartı | `lib/widgets/food/menu_item_card.dart` | Restoran menüsü için |
| Kategori Item | `lib/widgets/food/food_category_item.dart` | Yemek kategorileri |
| Promo Banner | `lib/widgets/food/food_promo_banner.dart` | Kampanya bannerları |
| Sepet Animasyonu | `lib/widgets/food/add_to_cart_animation.dart` | Sepete ekleme efekti |

### Yemek Ana Sayfa Özellikleri (food_home_screen.dart)

1. **Inline Arama Sistemi**
   - Hem yemek hem restoran arar
   - Sonuçlar overlay dropdown olarak gösterilir
   - Yemeklerde restoran adı gösterilir
   - Tıklandığında ilgili detay sayfasına yönlendirir

2. **Kategori Filtreleme**
   - Kategoriler: Tümü, Burger, Pizza, Kebap, Sushi, Salata
   - Seçilen kategoriye göre restoranlar filtrelenir
   - "Tümü" seçildiğinde tüm restoranlar gösterilir
   - Seçili kategori görsel olarak vurgulanır

3. **Alt Navigasyon**
   - Ana Sayfa, Favoriler, Siparişlerim, Profil
   - Siparişlerim: OrdersScreenContent widget'ı kullanır

4. **Restoran Listesi**
   - 5 restoran tanımlı (mock data)
   - Her restoran kategorilere göre etiketli
   - Filtreleme ile dinamik olarak güncellenir

### Siparişlerim Özellikleri (orders_screen.dart)

1. **İki Tab**
   - Aktif Siparişler (badge ile sayı gösterir)
   - Geçmiş Siparişler

2. **Aktif Sipariş Kartları**
   - Durum göstergesi (Hazırlanıyor=amber, Yolda=mavi)
   - "Takip Et" butonu → Sipariş takip ekranına
   - Restoran bilgileri ve toplam tutar

3. **Geçmiş Sipariş Kartları**
   - Teslim edildi badge'i
   - Puan gösterimi
   - "Tekrarla" butonu

4. **OrdersScreenContent**
   - Bottom navigation içinde kullanmak için AppBar'sız versiyon

### Sepete Ekleme Animasyonu (add_to_cart_animation.dart)

1. **Uçan Ürün Animasyonu**
   - Parabolik Bezier eğrisi yolu
   - 360° dönme efekti
   - Boyut değişimi (büyüyüp küçülme)
   - Turuncu glow efekti
   - 800ms süre

2. **Parçacık Patlaması**
   - Sepete ulaşınca turuncu parçacıklar
   - 12 parçacık dağılımı

3. **Sepet İkonu Bounce**
   - Ürün eklendiğinde sepet ikonu zıplar
   - Shake efekti

### Sipariş Takip Ekranı (order_tracking_screen.dart)

- Google Maps entegrasyonu
- Canlı harita görünümü
- Kurye konum gösterimi
- Sipariş durumu timeline
- Tahmini teslimat süresi

---

## 📁 Proje Yapısı (Güncel)

```
super_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── theme/app_theme.dart
│   │   ├── services/supabase_service.dart
│   │   ├── providers/auth_provider.dart
│   │   └── router/app_router.dart
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   ├── register_screen.dart
│   │   │   └── forgot_password_screen.dart
│   │   ├── home/home_screen.dart
│   │   ├── favorites/favorites_screen.dart
│   │   ├── orders/orders_screen.dart
│   │   ├── profile/profile_screen.dart
│   │   ├── food/                          ✅ YENİ
│   │   │   ├── food_home_screen.dart      ✅ Arama + Kategori filtre
│   │   │   ├── restaurant_detail_screen.dart
│   │   │   ├── food_item_detail_screen.dart
│   │   │   ├── cart_screen.dart
│   │   │   ├── order_success_screen.dart
│   │   │   ├── order_tracking_screen.dart
│   │   │   └── orders_screen.dart         ✅ Aktif/Geçmiş siparişler
│   │   └── main_shell.dart
│   └── widgets/
│       ├── home/
│       │   ├── service_card.dart
│       │   ├── promo_banner.dart
│       │   └── recent_transaction_card.dart
│       └── food/                          ✅ YENİ
│           ├── restaurant_card.dart
│           ├── menu_item_card.dart
│           ├── food_category_item.dart
│           ├── food_promo_banner.dart
│           └── add_to_cart_animation.dart  ✅ Gelişmiş animasyon
├── .env
├── pubspec.yaml
├── android/app/src/main/AndroidManifest.xml  (Google Maps API key)
└── web/index.html                            (Google Maps JS API)
```

---

## 📦 Yüklü Paketler

```yaml
dependencies:
  supabase_flutter: ^2.8.0
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.2
  shared_preferences: ^2.3.4
  flutter_dotenv: ^5.2.1
  google_sign_in: ^6.2.2
  sign_in_with_apple: ^6.1.4
  google_maps_flutter: ^2.10.0        # YENİ - Harita
  google_maps_flutter_web: ^0.5.10    # YENİ - Web harita
```

---

## 🔧 API Keys

### Google Maps
- Android: `AndroidManifest.xml` içinde
- Web: `web/index.html` içinde
- Key: `AIzaSyDKGWWyuU8vbE_8H50XaFCi7exSSFolLnQ`

### Supabase
- `.env` dosyasında

---

## 🚀 Sonraki Adımlar

1. ~~Yemek Servisi~~ ✅ TAMAMLANDI
2. [ ] Market Servisi
3. [ ] Kurye Servisi
4. [ ] Taksi Servisi
5. [ ] Hizmet Servisi
6. [ ] Randevu Servisi
7. [ ] Cüzdan Sistemi

---

## 🔄 Sohbet Geçmişi

### Sohbet 1 (2026-01-04)
- Proje oluşturuldu
- Auth ekranları (Login, Register, Forgot Password)
- Ana sayfa ve bottom navigation
- Supabase entegrasyonu

### Sohbet 2 (2026-01-05)
- **Yemek Servisi Tam Implementasyonu:**
  - Food Home Screen (ana sayfa)
  - Restaurant Detail Screen
  - Food Item Detail Screen
  - Cart Screen
  - Order Success Screen
  - Order Tracking Screen (Google Maps)
  - Orders Screen (Aktif/Geçmiş siparişler)

- **Gelişmiş Özellikler:**
  - Sepete ekleme animasyonu (Bezier eğrisi + parçacık efekti)
  - Inline arama (yemek + restoran)
  - Kategori filtreleme sistemi
  - Siparişlerim tab sistemi (Aktif/Geçmiş)
  - Google Maps entegrasyonu

---

## 📝 Önemli Notlar

1. **FoodColors Sınıfı:** `food_home_screen.dart` içinde tanımlı, diğer food ekranları buradan import eder
2. **OrdersScreenContent:** Bottom nav içinde AppBar'sız kullanım için
3. **Mock Data:** Restoranlar ve yemekler `food_home_screen.dart` içinde tanımlı
4. **Kategori Filtreleme:** `_selectedCategory` state'i ile kontrol edilir
5. **Arama Overlay:** `CompositedTransformTarget/Follower` ile konumlanır

---

**Yeni sohbete başlarken:**
1. Bu dosyayı oku
2. Kaldığın yerden devam et
3. Her değişiklikte bu dosyayı güncelle
