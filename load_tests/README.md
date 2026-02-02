# Super App Yük Testi Rehberi

## 1. Backend Yük Testi (k6)

### Kurulum

```bash
# Windows (Chocolatey)
choco install k6

# Windows (Winget)
winget install k6

# macOS
brew install k6

# Linux
sudo apt install k6
```

### Testi Çalıştırma

```bash
cd c:\A\load_tests

# Temel test
k6 run k6_load_test.js

# Daha az kullanıcı ile test (geliştirme için)
k6 run --vus 10 --duration 30s k6_load_test.js

# Sonuçları JSON'a kaydet
k6 run --out json=results.json k6_load_test.js
```

### Test Profili

| Aşama | Süre | Kullanıcı | Açıklama |
|-------|------|-----------|----------|
| Isınma | 30s | 10 | Sistemi hazırla |
| Orta Yük | 1m | 50 | Normal kullanım |
| Yüksek Yük | 2m | 100 | Yoğun saatler |
| Stres | 1m | 200 | Maksimum kapasite |
| Soğuma | 30s | 0 | Yavaşça bitir |

### Başarı Kriterleri

- ✅ %95 istek < 2 saniye
- ✅ Hata oranı < %5
- ✅ Dashboard yanıtı < 1 saniye

---

## 2. Veritabanı Sorgu Analizi

Supabase Dashboard'da kontrol edin:
1. https://supabase.com/dashboard → Projenizi seçin
2. **Database → Query Performance**
3. **Logs → Postgres Logs** (yavaş sorgular için)

### Kontrol Edilecekler

- [ ] Yavaş sorgular (>100ms)
- [ ] Eksik indeksler
- [ ] Full table scan yapan sorgular
- [ ] N+1 sorgu problemleri

---

## 3. Flutter UI Profiling

### DevTools Açma

```bash
# Uygulamayı profile modda çalıştır
flutter run --profile

# DevTools'u aç
flutter pub global activate devtools
flutter pub global run devtools
```

### Kontrol Edilecekler

1. **Performance Tab:**
   - Frame render süreleri (hedef: <16ms = 60 FPS)
   - Jank tespit (kırmızı çerçeveler)

2. **Widget Rebuild:**
   - Gereksiz rebuild'ler
   - Const constructor kullanımı

3. **Memory Tab:**
   - Memory leak tespiti
   - Dispose edilmeyen controller'lar

---

## 4. Sonuç Yorumlama

### İyi Sonuçlar
- p95 < 500ms
- Hata oranı < %1
- 60 FPS tutarlı

### Sorunlu Sonuçlar
- p95 > 2000ms → Sorgu optimizasyonu gerekli
- Hata oranı > %5 → Rate limiting veya bağlantı sorunu
- FPS < 30 → UI optimizasyonu gerekli

---

## Hızlı Komutlar

```bash
# Hafif test (geliştirme)
k6 run --vus 5 --duration 10s k6_load_test.js

# Orta test
k6 run --vus 50 --duration 1m k6_load_test.js

# Ağır test (dikkatli kullan!)
k6 run k6_load_test.js
```
