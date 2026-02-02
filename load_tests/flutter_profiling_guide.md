# Flutter UI Profiling Rehberi

## 1. Profile Modda Çalıştırma

```bash
# super_app için
cd c:\A\super_app
flutter run --profile

# admin_panel için
cd c:\A\admin_panel
flutter run --profile -d chrome
```

## 2. DevTools Açma

Flutter uygulaması çalışırken terminalde bir URL göreceksiniz:
```
Flutter DevTools debugging is available at: http://127.0.0.1:9100
```

Bu URL'yi tarayıcıda açın.

## 3. Performance Tab Kullanımı

### Frame Analizi
1. **Performance** sekmesine gidin
2. **Record** butonuna tıklayın
3. Uygulamada scroll yapın, sayfalar arası geçiş yapın
4. **Stop** butonuna tıklayın

### Kontrol Edilecekler:

| Metrik | İyi | Kötü |
|--------|-----|------|
| Frame süresi | < 16ms | > 16ms (kırmızı) |
| FPS | 60 | < 30 |
| Jank | Yok | Mavi/Kırmızı çubuklar |

## 4. Widget Rebuild İzleme

### DevTools'da:
1. **Performance Overlay** açın
2. Yeşil çubuk = UI thread
3. Mavi çubuk = GPU thread

### Kod İle:
```dart
// main.dart'a ekleyin (sadece debug için)
import 'package:flutter/rendering.dart';

void main() {
  debugRepaintRainbowEnabled = true;  // Repaint edilen alanları göster
  runApp(MyApp());
}
```

## 5. Memory Leak Tespiti

### DevTools Memory Tab:
1. **Memory** sekmesine gidin
2. **Take Heap Snapshot** butonuna tıklayın
3. Sayfalar arası geçiş yapın
4. Tekrar snapshot alın
5. Karşılaştırın

### Kontrol Edilecekler:
- [ ] AnimationController dispose edilmiş mi?
- [ ] StreamSubscription iptal edilmiş mi?
- [ ] TextEditingController dispose edilmiş mi?
- [ ] ScrollController dispose edilmiş mi?

## 6. Performans Kodları

### Scroll Performansı İyileştirme
```dart
// ListView için
ListView.builder(
  addAutomaticKeepAlives: false,  // Bellek tasarrufu
  addRepaintBoundaries: true,     // Repaint optimizasyonu
  itemBuilder: (context, index) => MyItem(),
)
```

### Const Widget Kullanımı
```dart
// KÖTÜ - her build'de yeni instance
child: Text('Merhaba')

// İYİ - compile-time sabit
child: const Text('Merhaba')
```

### Memoization
```dart
// KÖTÜ - her build'de hesaplama
Widget build(context) {
  final total = items.fold(0, (a, b) => a + b.price);
  return Text('$total');
}

// İYİ - sadece items değiştiğinde hesapla
final _memoizedTotal = useMemoized(() =>
  items.fold(0, (a, b) => a + b.price),
  [items]
);
```

## 7. Hızlı Test Senaryoları

### Senaryo 1: Scroll Performansı
1. Profile modda çalıştır
2. DevTools aç → Performance
3. Record başlat
4. 10 saniye hızlı scroll yap
5. Stop et ve analiz et

### Senaryo 2: Sayfa Geçişleri
1. Record başlat
2. Ana sayfa → Detay → Geri → Başka sayfa
3. Her geçişte frame drop var mı kontrol et

### Senaryo 3: Veri Yükleme
1. Network sekmesini aç
2. Sayfayı yenile
3. API çağrılarının süresini kontrol et

## 8. Bilinen Sorunlar ve Çözümler

| Sorun | Çözüm |
|-------|-------|
| Scroll sırasında jank | setState → ValueNotifier ✅ (Düzeltildi) |
| Dashboard yavaş | Tek RPC çağrısı ✅ (Düzeltildi) |
| Chat sürekli rebuild | Debounce eklendi ✅ (Düzeltildi) |
| Liste yükleme yavaş | Pagination eklendi ✅ (Düzeltildi) |

## 9. Komut Satırı Araçları

```bash
# Uygulama boyutunu analiz et
flutter build apk --analyze-size

# Kullanılmayan kodu bul
flutter pub run dart_code_metrics:metrics analyze lib

# Performance timeline kaydet
flutter run --profile --trace-startup
```
