-- ============================================
-- RLS FIX - MISSING TABLE POLICIES
-- Tarih: 2026-03-15
-- Açıklama: car_brands, car_features, car_promotion_prices,
--            car_listing_views ve car_settings tablolarına
--            eksik RLS politikaları eklenir.
--            car_contact_requests anonim INSERT iyileştirmesi.
-- ============================================

-- ============================================
-- 1. CAR_BRANDS - Sadece okuma (public), tam erişim (service_role)
-- ============================================
ALTER TABLE car_brands ENABLE ROW LEVEL SECURITY;

-- Herkes aktif markaları okuyabilir
CREATE POLICY "Public can view active car brands" ON car_brands
  FOR SELECT USING (is_active = true);

-- Yalnızca service_role tüm işlemleri yapabilir (admin paneli)
CREATE POLICY "Service role has full access to car brands" ON car_brands
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- 2. CAR_FEATURES - Sadece okuma (public), tam erişim (service_role)
-- ============================================
ALTER TABLE car_features ENABLE ROW LEVEL SECURITY;

-- Herkes aktif özellikleri okuyabilir
CREATE POLICY "Public can view active car features" ON car_features
  FOR SELECT USING (is_active = true);

-- Yalnızca service_role tüm işlemleri yapabilir (admin paneli)
CREATE POLICY "Service role has full access to car features" ON car_features
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- 3. CAR_PROMOTION_PRICES - Kimlik doğrulamalı okuma, tam erişim (service_role)
-- ============================================
ALTER TABLE car_promotion_prices ENABLE ROW LEVEL SECURITY;

-- Oturum açmış kullanıcılar fiyatları görebilir
CREATE POLICY "Authenticated users can view promotion prices" ON car_promotion_prices
  FOR SELECT USING (auth.role() = 'authenticated');

-- Yalnızca service_role tüm işlemleri yapabilir (admin paneli)
CREATE POLICY "Service role has full access to promotion prices" ON car_promotion_prices
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- 4. CAR_LISTING_VIEWS - Doğrudan INSERT yok (fonksiyon kullanılır),
--    ilan sahibi kendi görüntülenmelerini okuyabilir, service_role tam erişim.
-- ============================================
ALTER TABLE car_listing_views ENABLE ROW LEVEL SECURITY;

-- İlan sahibi kendi ilanının görüntülenme kayıtlarını okuyabilir
CREATE POLICY "Listing owner can view their listing views" ON car_listing_views
  FOR SELECT USING (
    listing_id IN (
      SELECT id FROM car_listings WHERE user_id = auth.uid()
    )
  );

-- Yalnızca service_role tüm işlemleri yapabilir
-- (görüntülenme kaydı increment_car_listing_view() SECURITY DEFINER fonksiyonu üzerinden eklenir)
CREATE POLICY "Service role has full access to car listing views" ON car_listing_views
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- 5. CAR_SETTINGS - Yalnızca service_role (admin paneli)
-- ============================================
ALTER TABLE car_settings ENABLE ROW LEVEL SECURITY;

-- Hiçbir public/authenticated kullanıcı okuyamaz; sadece service_role erişir
CREATE POLICY "Service role has full access to car settings" ON car_settings
  FOR ALL USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- ============================================
-- 6. CAR_CONTACT_REQUESTS - Anonim INSERT güçlendirmesi
--    Mevcut "Anyone can create contact requests" politikası (WITH CHECK (true))
--    değiştirilerek saat başına çok fazla istek gönderilmesi zorlaştırılır.
--    Makul bir oran sınırı: aynı listing_id + phone çiftinden son 1 saatte
--    yalnızca 1 kayıt oluşturulabilir.
-- ============================================

-- Mevcut sınırsız INSERT politikasını kaldır
DROP POLICY IF EXISTS "Anyone can create contact requests" ON car_contact_requests;

-- Yeni politika: rate limiting ile anonim INSERT
CREATE POLICY "Rate-limited contact request creation" ON car_contact_requests
  FOR INSERT WITH CHECK (
    -- Aynı ilan ve telefon kombinasyonu son 1 saat içinde 1 kereden fazla başvuramaz
    NOT EXISTS (
      SELECT 1
      FROM car_contact_requests existing
      WHERE existing.listing_id = car_contact_requests.listing_id
        AND existing.phone = car_contact_requests.phone
        AND existing.created_at > NOW() - INTERVAL '1 hour'
    )
  );
