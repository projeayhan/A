-- ============================================
-- ARAÇ SATIŞ SİSTEMİ - SUPABASE MIGRATION
-- Tarih: 2026-01-22
-- Açıklama: Araç satış modülü için tüm tablolar
-- ============================================

-- ============================================
-- 1. CAR_BRANDS - Araç Markaları
-- ============================================
CREATE TABLE IF NOT EXISTS car_brands (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  logo_url TEXT,
  country VARCHAR(50),
  is_premium BOOLEAN DEFAULT FALSE,
  is_popular BOOLEAN DEFAULT FALSE,
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Popüler markalar için başlangıç verileri
INSERT INTO car_brands (id, name, country, is_premium, is_popular, sort_order) VALUES
  ('toyota', 'Toyota', 'Japonya', false, true, 1),
  ('volkswagen', 'Volkswagen', 'Almanya', false, true, 2),
  ('mercedes', 'Mercedes-Benz', 'Almanya', true, true, 3),
  ('bmw', 'BMW', 'Almanya', true, true, 4),
  ('audi', 'Audi', 'Almanya', true, true, 5),
  ('ford', 'Ford', 'Amerika', false, true, 6),
  ('renault', 'Renault', 'Fransa', false, true, 7),
  ('hyundai', 'Hyundai', 'Güney Kore', false, true, 8),
  ('honda', 'Honda', 'Japonya', false, true, 9),
  ('fiat', 'Fiat', 'İtalya', false, true, 10),
  ('porsche', 'Porsche', 'Almanya', true, false, 11),
  ('tesla', 'Tesla', 'Amerika', true, false, 12),
  ('volvo', 'Volvo', 'İsveç', true, false, 13),
  ('lexus', 'Lexus', 'Japonya', true, false, 14),
  ('land_rover', 'Land Rover', 'İngiltere', true, false, 15),
  ('jaguar', 'Jaguar', 'İngiltere', true, false, 16),
  ('mazda', 'Mazda', 'Japonya', false, false, 17),
  ('nissan', 'Nissan', 'Japonya', false, false, 18),
  ('kia', 'Kia', 'Güney Kore', false, false, 19),
  ('peugeot', 'Peugeot', 'Fransa', false, false, 20),
  ('citroen', 'Citroën', 'Fransa', false, false, 21),
  ('opel', 'Opel', 'Almanya', false, false, 22),
  ('skoda', 'Skoda', 'Çekya', false, false, 23),
  ('seat', 'SEAT', 'İspanya', false, false, 24),
  ('dacia', 'Dacia', 'Romanya', false, false, 25),
  ('mitsubishi', 'Mitsubishi', 'Japonya', false, false, 26),
  ('suzuki', 'Suzuki', 'Japonya', false, false, 27),
  ('jeep', 'Jeep', 'Amerika', false, false, 28),
  ('chevrolet', 'Chevrolet', 'Amerika', false, false, 29),
  ('mini', 'MINI', 'İngiltere', true, false, 30),
  ('alfa_romeo', 'Alfa Romeo', 'İtalya', true, false, 31),
  ('maserati', 'Maserati', 'İtalya', true, false, 32),
  ('ferrari', 'Ferrari', 'İtalya', true, false, 33),
  ('lamborghini', 'Lamborghini', 'İtalya', true, false, 34),
  ('bentley', 'Bentley', 'İngiltere', true, false, 35),
  ('rolls_royce', 'Rolls-Royce', 'İngiltere', true, false, 36),
  ('aston_martin', 'Aston Martin', 'İngiltere', true, false, 37),
  ('subaru', 'Subaru', 'Japonya', false, false, 38),
  ('infiniti', 'Infiniti', 'Japonya', true, false, 39)
ON CONFLICT (id) DO NOTHING;

-- Index
CREATE INDEX IF NOT EXISTS idx_car_brands_popular ON car_brands(is_popular) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_car_brands_premium ON car_brands(is_premium) WHERE is_active = true;

-- ============================================
-- 2. CAR_FEATURES - Araç Özellikleri/Donanım
-- ============================================
CREATE TABLE IF NOT EXISTS car_features (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  category VARCHAR(50) NOT NULL, -- security, comfort, multimedia, exterior, interior
  icon VARCHAR(50),
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Özellik verileri
INSERT INTO car_features (id, name, category, icon, sort_order) VALUES
  -- Güvenlik
  ('abs', 'ABS', 'security', 'security', 1),
  ('esp', 'ESP', 'security', 'security', 2),
  ('airbag_driver', 'Sürücü Airbag', 'security', 'airline_seat_recline_extra', 3),
  ('airbag_passenger', 'Yolcu Airbag', 'security', 'airline_seat_recline_extra', 4),
  ('airbag_side', 'Yan Airbag', 'security', 'airline_seat_recline_extra', 5),
  ('blind_spot', 'Kör Nokta Uyarısı', 'security', 'visibility', 6),
  ('lane_assist', 'Şerit Takip', 'security', 'swap_horiz', 7),
  ('parking_sensor_front', 'Ön Park Sensörü', 'security', 'sensors', 8),
  ('parking_sensor_rear', 'Arka Park Sensörü', 'security', 'sensors', 9),
  ('rear_camera', 'Geri Görüş Kamerası', 'security', 'camera_rear', 10),
  ('camera_360', '360° Kamera', 'security', 'camera', 11),
  ('tire_pressure', 'Lastik Basınç Sensörü', 'security', 'tire_repair', 12),
  -- Konfor
  ('climate_control', 'Klima', 'comfort', 'ac_unit', 13),
  ('climate_dual', 'Çift Bölgeli Klima', 'comfort', 'ac_unit', 14),
  ('heated_seats', 'Isıtmalı Koltuk', 'comfort', 'event_seat', 15),
  ('cooled_seats', 'Soğutmalı Koltuk', 'comfort', 'event_seat', 16),
  ('leather_seats', 'Deri Koltuk', 'comfort', 'event_seat', 17),
  ('electric_seats', 'Elektrikli Koltuk', 'comfort', 'event_seat', 18),
  ('memory_seats', 'Hafızalı Koltuk', 'comfort', 'event_seat', 19),
  ('sunroof', 'Cam Tavan', 'comfort', 'wb_sunny', 20),
  ('panoramic_roof', 'Panoramik Cam Tavan', 'comfort', 'wb_sunny', 21),
  ('keyless_entry', 'Anahtarsız Giriş', 'comfort', 'key_off', 22),
  ('keyless_start', 'Anahtarsız Çalıştırma', 'comfort', 'power_settings_new', 23),
  ('cruise_control', 'Hız Sabitleyici', 'comfort', 'speed', 24),
  ('adaptive_cruise', 'Adaptif Hız Sabitleyici', 'comfort', 'speed', 25),
  ('heated_steering', 'Isıtmalı Direksiyon', 'comfort', 'radio_button_checked', 26),
  -- Multimedya
  ('bluetooth', 'Bluetooth', 'multimedia', 'bluetooth', 27),
  ('usb', 'USB Girişi', 'multimedia', 'usb', 28),
  ('navigation', 'Navigasyon', 'multimedia', 'navigation', 29),
  ('apple_carplay', 'Apple CarPlay', 'multimedia', 'phone_iphone', 30),
  ('android_auto', 'Android Auto', 'multimedia', 'android', 31),
  ('premium_audio', 'Premium Ses Sistemi', 'multimedia', 'speaker', 32),
  ('wireless_charging', 'Kablosuz Şarj', 'multimedia', 'battery_charging_full', 33),
  ('head_up_display', 'Head-Up Display', 'multimedia', 'desktop_windows', 34),
  ('digital_cockpit', 'Dijital Gösterge', 'multimedia', 'dashboard', 35),
  -- Dış Donanım
  ('led_headlights', 'LED Farlar', 'exterior', 'highlight', 36),
  ('xenon_headlights', 'Xenon Farlar', 'exterior', 'highlight', 37),
  ('adaptive_lights', 'Adaptif Farlar', 'exterior', 'highlight', 38),
  ('fog_lights', 'Sis Farları', 'exterior', 'blur_on', 39),
  ('alloy_wheels', 'Alaşım Jant', 'exterior', 'radio_button_unchecked', 40),
  ('electric_mirrors', 'Elektrikli Ayna', 'exterior', 'flip', 41),
  ('heated_mirrors', 'Isıtmalı Ayna', 'exterior', 'flip', 42),
  ('roof_rails', 'Tavan Rayları', 'exterior', 'view_stream', 43),
  ('tinted_windows', 'Renkli Cam', 'exterior', 'gradient', 44),
  ('auto_tailgate', 'Elektrikli Bagaj', 'exterior', 'sensor_door', 45)
ON CONFLICT (id) DO NOTHING;

-- Index
CREATE INDEX IF NOT EXISTS idx_car_features_category ON car_features(category) WHERE is_active = true;

-- ============================================
-- 3. CAR_DEALERS - Galeri/Satıcı Profilleri
-- ============================================
CREATE TABLE IF NOT EXISTS car_dealers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dealer_type VARCHAR(20) NOT NULL DEFAULT 'individual', -- individual, dealer, authorized_dealer

  -- Profil Bilgileri
  business_name VARCHAR(200),
  owner_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(100),
  tax_number VARCHAR(20),

  -- Adres
  city VARCHAR(50) NOT NULL,
  district VARCHAR(50),
  address TEXT,
  latitude DECIMAL(10,8),
  longitude DECIMAL(11,8),

  -- Medya
  logo_url TEXT,
  cover_url TEXT,
  gallery_images JSONB DEFAULT '[]'::jsonb,

  -- Çalışma Saatleri
  working_hours JSONB DEFAULT '{}'::jsonb,

  -- İstatistikler
  total_listings INT DEFAULT 0,
  active_listings INT DEFAULT 0,
  total_sold INT DEFAULT 0,
  average_rating DECIMAL(2,1) DEFAULT 0,
  total_reviews INT DEFAULT 0,
  response_rate INT DEFAULT 0,
  avg_response_time INT DEFAULT 0,

  -- Durum
  status VARCHAR(20) DEFAULT 'pending', -- pending, active, suspended, rejected
  is_verified BOOLEAN DEFAULT FALSE,
  is_premium_dealer BOOLEAN DEFAULT FALSE,

  -- Üyelik
  membership_type VARCHAR(20) DEFAULT 'free', -- free, basic, premium, enterprise
  membership_starts_at TIMESTAMP WITH TIME ZONE,
  membership_expires_at TIMESTAMP WITH TIME ZONE,

  -- Meta
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT unique_dealer_user UNIQUE (user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_dealers_user ON car_dealers(user_id);
CREATE INDEX IF NOT EXISTS idx_car_dealers_status ON car_dealers(status);
CREATE INDEX IF NOT EXISTS idx_car_dealers_city ON car_dealers(city);
CREATE INDEX IF NOT EXISTS idx_car_dealers_type ON car_dealers(dealer_type);

-- RLS
ALTER TABLE car_dealers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active dealers" ON car_dealers
  FOR SELECT USING (status = 'active');

CREATE POLICY "Users can manage own dealer profile" ON car_dealers
  FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 4. CAR_DEALER_APPLICATIONS - Satıcı Başvuruları
-- ============================================
CREATE TABLE IF NOT EXISTS car_dealer_applications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  dealer_type VARCHAR(20) NOT NULL DEFAULT 'individual',

  -- Başvuru Bilgileri
  business_name VARCHAR(200),
  owner_name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(100),
  tax_number VARCHAR(20),
  city VARCHAR(50) NOT NULL,
  district VARCHAR(50),
  address TEXT,

  -- Belgeler
  documents JSONB DEFAULT '[]'::jsonb, -- [{type, url, status}]

  -- Durum
  status VARCHAR(20) DEFAULT 'pending', -- pending, approved, rejected
  reviewed_at TIMESTAMP WITH TIME ZONE,
  reviewed_by UUID,
  rejection_reason TEXT,
  admin_notes TEXT,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_dealer_applications_user ON car_dealer_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_car_dealer_applications_status ON car_dealer_applications(status);

-- RLS
ALTER TABLE car_dealer_applications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own applications" ON car_dealer_applications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create applications" ON car_dealer_applications
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 5. CAR_LISTINGS - Araç İlanları
-- ============================================
CREATE TABLE IF NOT EXISTS car_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dealer_id UUID REFERENCES car_dealers(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,

  -- Temel Bilgiler
  title VARCHAR(200) NOT NULL,
  description TEXT,

  -- Araç Bilgileri
  brand_id VARCHAR(50) NOT NULL REFERENCES car_brands(id),
  brand_name VARCHAR(50) NOT NULL,
  model_name VARCHAR(100) NOT NULL,
  year INT NOT NULL,
  body_type VARCHAR(30) NOT NULL, -- sedan, hatchback, suv, crossover, coupe, convertible, station_wagon, pickup, van, minivan, sports, luxury

  -- Teknik Özellikler
  fuel_type VARCHAR(20) NOT NULL, -- petrol, diesel, electric, hybrid, plugin_hybrid, lpg
  transmission VARCHAR(20) NOT NULL, -- automatic, manual, semi_automatic
  traction VARCHAR(10) DEFAULT 'fwd', -- fwd, rwd, awd, 4wd
  engine_cc INT,
  horsepower INT,
  mileage INT NOT NULL,

  -- Renk
  exterior_color VARCHAR(30),
  interior_color VARCHAR(30),

  -- Durum Bilgileri
  condition VARCHAR(30) DEFAULT 'good', -- brand_new, like_new, excellent, good, fair, needs_repair
  previous_owners INT DEFAULT 1,
  has_original_paint BOOLEAN DEFAULT TRUE,
  has_accident_history BOOLEAN DEFAULT FALSE,
  has_warranty BOOLEAN DEFAULT FALSE,
  warranty_details TEXT,
  damage_report TEXT,
  plate_city VARCHAR(10),
  service_history TEXT,

  -- Fiyat
  price DECIMAL(12,2) NOT NULL,
  currency VARCHAR(3) DEFAULT 'TRY',
  is_price_negotiable BOOLEAN DEFAULT FALSE,
  is_exchange_accepted BOOLEAN DEFAULT FALSE,

  -- Medya
  images JSONB DEFAULT '[]'::jsonb,
  video_url TEXT,

  -- Özellikler
  features JSONB DEFAULT '[]'::jsonb, -- ['abs', 'esp', 'sunroof', ...]

  -- Konum
  location VARCHAR(100),
  city VARCHAR(50),
  district VARCHAR(50),

  -- Durum
  status VARCHAR(20) DEFAULT 'pending', -- pending, active, sold, reserved, expired, rejected
  rejection_reason TEXT,

  -- Öne Çıkarma
  is_featured BOOLEAN DEFAULT FALSE,
  is_premium BOOLEAN DEFAULT FALSE,
  featured_until TIMESTAMP WITH TIME ZONE,
  premium_until TIMESTAMP WITH TIME ZONE,

  -- İstatistikler
  view_count INT DEFAULT 0,
  favorite_count INT DEFAULT 0,
  contact_count INT DEFAULT 0,
  share_count INT DEFAULT 0,

  -- Zaman
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  published_at TIMESTAMP WITH TIME ZONE,
  sold_at TIMESTAMP WITH TIME ZONE,
  expires_at TIMESTAMP WITH TIME ZONE
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_listings_user ON car_listings(user_id);
CREATE INDEX IF NOT EXISTS idx_car_listings_dealer ON car_listings(dealer_id);
CREATE INDEX IF NOT EXISTS idx_car_listings_brand ON car_listings(brand_id);
CREATE INDEX IF NOT EXISTS idx_car_listings_status ON car_listings(status);
CREATE INDEX IF NOT EXISTS idx_car_listings_city ON car_listings(city);
CREATE INDEX IF NOT EXISTS idx_car_listings_price ON car_listings(price);
CREATE INDEX IF NOT EXISTS idx_car_listings_year ON car_listings(year);
CREATE INDEX IF NOT EXISTS idx_car_listings_featured ON car_listings(is_featured) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_car_listings_premium ON car_listings(is_premium) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_car_listings_created ON car_listings(created_at DESC);

-- Full text search index
CREATE INDEX IF NOT EXISTS idx_car_listings_search ON car_listings
  USING GIN (to_tsvector('turkish', coalesce(title, '') || ' ' || coalesce(brand_name, '') || ' ' || coalesce(model_name, '') || ' ' || coalesce(description, '')));

-- RLS
ALTER TABLE car_listings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view active listings" ON car_listings
  FOR SELECT USING (status = 'active');

CREATE POLICY "Users can view own listings" ON car_listings
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create listings" ON car_listings
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own listings" ON car_listings
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own listings" ON car_listings
  FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- 6. CAR_PROMOTION_PRICES - Promosyon Fiyatları
-- ============================================
CREATE TABLE IF NOT EXISTS car_promotion_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_type VARCHAR(20) NOT NULL, -- featured, premium
  duration_days INT NOT NULL, -- 7, 14, 30
  price DECIMAL(10,2) NOT NULL,
  discounted_price DECIMAL(10,2),
  description TEXT,
  benefits JSONB DEFAULT '[]'::jsonb,
  is_active BOOLEAN DEFAULT TRUE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT unique_promotion_price UNIQUE (promotion_type, duration_days)
);

-- Başlangıç fiyatları
INSERT INTO car_promotion_prices (promotion_type, duration_days, price, discounted_price, description, benefits, sort_order) VALUES
  ('featured', 7, 149.00, NULL, '7 Günlük Öne Çıkarma', '["Öne çıkan listesinde görünür", "~%150 daha fazla görüntülenme", "Arama sonuçlarında öncelik"]', 1),
  ('featured', 14, 249.00, 229.00, '14 Günlük Öne Çıkarma', '["Öne çıkan listesinde görünür", "~%150 daha fazla görüntülenme", "Arama sonuçlarında öncelik"]', 2),
  ('featured', 30, 449.00, 399.00, '30 Günlük Öne Çıkarma', '["Öne çıkan listesinde görünür", "~%150 daha fazla görüntülenme", "Arama sonuçlarında öncelik"]', 3),
  ('premium', 7, 299.00, NULL, '7 Günlük Premium', '["Premium altın rozet", "~%300 daha fazla görüntülenme", "En üst sıralarda listeleme", "Özel vurgu tasarımı"]', 4),
  ('premium', 14, 499.00, 449.00, '14 Günlük Premium', '["Premium altın rozet", "~%300 daha fazla görüntülenme", "En üst sıralarda listeleme", "Özel vurgu tasarımı"]', 5),
  ('premium', 30, 899.00, 799.00, '30 Günlük Premium', '["Premium altın rozet", "~%300 daha fazla görüntülenme", "En üst sıralarda listeleme", "Özel vurgu tasarımı"]', 6)
ON CONFLICT (promotion_type, duration_days) DO NOTHING;

-- ============================================
-- 7. CAR_LISTING_PROMOTIONS - Aktif Promosyonlar
-- ============================================
CREATE TABLE IF NOT EXISTS car_listing_promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES car_listings(id) ON DELETE CASCADE,
  dealer_id UUID REFERENCES car_dealers(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price_id UUID REFERENCES car_promotion_prices(id),

  -- Promosyon Tipi
  promotion_type VARCHAR(20) NOT NULL, -- featured, premium
  duration_days INT NOT NULL,

  -- Süre
  starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE NOT NULL,

  -- Ödeme (şimdilik boş, sonra entegre edilecek)
  amount_paid DECIMAL(10,2),
  payment_method VARCHAR(20),
  payment_reference VARCHAR(100),
  payment_status VARCHAR(20) DEFAULT 'pending', -- pending, completed, failed, refunded

  -- Durum
  status VARCHAR(20) DEFAULT 'active', -- active, expired, cancelled

  -- İstatistikler
  views_before INT DEFAULT 0,
  views_during INT DEFAULT 0,
  contacts_before INT DEFAULT 0,
  contacts_during INT DEFAULT 0,
  favorites_before INT DEFAULT 0,
  favorites_during INT DEFAULT 0,

  -- İptal
  cancelled_at TIMESTAMP WITH TIME ZONE,
  cancellation_reason TEXT,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_promotions_listing ON car_listing_promotions(listing_id);
CREATE INDEX IF NOT EXISTS idx_car_promotions_user ON car_listing_promotions(user_id);
CREATE INDEX IF NOT EXISTS idx_car_promotions_status ON car_listing_promotions(status);
CREATE INDEX IF NOT EXISTS idx_car_promotions_expires ON car_listing_promotions(expires_at);

-- RLS
ALTER TABLE car_listing_promotions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own promotions" ON car_listing_promotions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can create promotions" ON car_listing_promotions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ============================================
-- 8. CAR_LISTING_VIEWS - Görüntülenme Takibi
-- ============================================
CREATE TABLE IF NOT EXISTS car_listing_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES car_listings(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  session_id VARCHAR(100),
  ip_address VARCHAR(45),
  user_agent TEXT,
  referrer TEXT,
  viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_views_listing ON car_listing_views(listing_id);
CREATE INDEX IF NOT EXISTS idx_car_views_date ON car_listing_views(viewed_at);

-- ============================================
-- 9. CAR_FAVORITES - Favoriler
-- ============================================
CREATE TABLE IF NOT EXISTS car_favorites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES car_listings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT unique_car_favorite UNIQUE (listing_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_favorites_user ON car_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_car_favorites_listing ON car_favorites(listing_id);

-- RLS
ALTER TABLE car_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own favorites" ON car_favorites
  FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- 10. CAR_CONTACT_REQUESTS - İletişim Talepleri
-- ============================================
CREATE TABLE IF NOT EXISTS car_contact_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES car_listings(id) ON DELETE CASCADE,
  dealer_id UUID REFERENCES car_dealers(id) ON DELETE SET NULL,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,

  -- İletişim Bilgileri
  name VARCHAR(100) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  email VARCHAR(100),
  message TEXT,

  -- Durum
  status VARCHAR(20) DEFAULT 'new', -- new, read, replied, spam
  replied_at TIMESTAMP WITH TIME ZONE,
  reply_message TEXT,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_contacts_listing ON car_contact_requests(listing_id);
CREATE INDEX IF NOT EXISTS idx_car_contacts_dealer ON car_contact_requests(dealer_id);
CREATE INDEX IF NOT EXISTS idx_car_contacts_status ON car_contact_requests(status);

-- RLS
ALTER TABLE car_contact_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Dealers can view their contact requests" ON car_contact_requests
  FOR SELECT USING (
    dealer_id IN (SELECT id FROM car_dealers WHERE user_id = auth.uid())
    OR listing_id IN (SELECT id FROM car_listings WHERE user_id = auth.uid())
  );

CREATE POLICY "Anyone can create contact requests" ON car_contact_requests
  FOR INSERT WITH CHECK (true);

-- ============================================
-- 11. CAR_SETTINGS - Sistem Ayarları
-- ============================================
CREATE TABLE IF NOT EXISTS car_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key VARCHAR(100) UNIQUE NOT NULL,
  value JSONB NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Başlangıç ayarları
INSERT INTO car_settings (key, value, description) VALUES
  ('listing_duration_days', '90', 'İlan yayın süresi (gün)'),
  ('max_images_per_listing', '20', 'İlan başına maksimum fotoğraf'),
  ('min_price', '10000', 'Minimum ilan fiyatı (TL)'),
  ('max_price', '50000000', 'Maksimum ilan fiyatı (TL)'),
  ('auto_approve_listings', 'false', 'İlanları otomatik onayla'),
  ('require_phone_verification', 'true', 'Telefon doğrulaması zorunlu'),
  ('commission_rate', '0', 'Komisyon oranı (%)'),
  ('featured_boost_multiplier', '1.5', 'Öne çıkarma görüntülenme çarpanı'),
  ('premium_boost_multiplier', '3.0', 'Premium görüntülenme çarpanı')
ON CONFLICT (key) DO NOTHING;

-- ============================================
-- 12. CAR_DEALER_REVIEWS - Satıcı Değerlendirmeleri
-- ============================================
CREATE TABLE IF NOT EXISTS car_dealer_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  dealer_id UUID NOT NULL REFERENCES car_dealers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  listing_id UUID REFERENCES car_listings(id) ON DELETE SET NULL,

  rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,

  -- Satıcı Yanıtı
  reply TEXT,
  replied_at TIMESTAMP WITH TIME ZONE,

  is_verified_purchase BOOLEAN DEFAULT FALSE,
  is_visible BOOLEAN DEFAULT TRUE,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

  CONSTRAINT unique_dealer_review UNIQUE (dealer_id, user_id, listing_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_car_reviews_dealer ON car_dealer_reviews(dealer_id);
CREATE INDEX IF NOT EXISTS idx_car_reviews_user ON car_dealer_reviews(user_id);

-- RLS
ALTER TABLE car_dealer_reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public can view visible reviews" ON car_dealer_reviews
  FOR SELECT USING (is_visible = true);

CREATE POLICY "Users can create reviews" ON car_dealer_reviews
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own reviews" ON car_dealer_reviews
  FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Updated at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
CREATE TRIGGER update_car_brands_updated_at BEFORE UPDATE ON car_brands
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_dealers_updated_at BEFORE UPDATE ON car_dealers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_dealer_applications_updated_at BEFORE UPDATE ON car_dealer_applications
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_listings_updated_at BEFORE UPDATE ON car_listings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_settings_updated_at BEFORE UPDATE ON car_settings
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_car_promotion_prices_updated_at BEFORE UPDATE ON car_promotion_prices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Increment view count function
CREATE OR REPLACE FUNCTION increment_car_listing_view(p_listing_id UUID, p_user_id UUID DEFAULT NULL, p_session_id VARCHAR DEFAULT NULL)
RETURNS void AS $$
BEGIN
  -- Insert view record
  INSERT INTO car_listing_views (listing_id, user_id, session_id)
  VALUES (p_listing_id, p_user_id, p_session_id);

  -- Update listing view count
  UPDATE car_listings SET view_count = view_count + 1 WHERE id = p_listing_id;

  -- Update promotion views if active
  UPDATE car_listing_promotions
  SET views_during = views_during + 1
  WHERE listing_id = p_listing_id
    AND status = 'active'
    AND expires_at > NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update dealer stats function
CREATE OR REPLACE FUNCTION update_dealer_listing_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update dealer listing counts
  UPDATE car_dealers SET
    total_listings = (SELECT COUNT(*) FROM car_listings WHERE dealer_id = COALESCE(NEW.dealer_id, OLD.dealer_id)),
    active_listings = (SELECT COUNT(*) FROM car_listings WHERE dealer_id = COALESCE(NEW.dealer_id, OLD.dealer_id) AND status = 'active'),
    total_sold = (SELECT COUNT(*) FROM car_listings WHERE dealer_id = COALESCE(NEW.dealer_id, OLD.dealer_id) AND status = 'sold')
  WHERE id = COALESCE(NEW.dealer_id, OLD.dealer_id);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_dealer_stats_on_listing_change
  AFTER INSERT OR UPDATE OR DELETE ON car_listings
  FOR EACH ROW EXECUTE FUNCTION update_dealer_listing_stats();

-- Update dealer rating function
CREATE OR REPLACE FUNCTION update_dealer_rating()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE car_dealers SET
    average_rating = (SELECT COALESCE(AVG(rating), 0) FROM car_dealer_reviews WHERE dealer_id = COALESCE(NEW.dealer_id, OLD.dealer_id) AND is_visible = true),
    total_reviews = (SELECT COUNT(*) FROM car_dealer_reviews WHERE dealer_id = COALESCE(NEW.dealer_id, OLD.dealer_id) AND is_visible = true)
  WHERE id = COALESCE(NEW.dealer_id, OLD.dealer_id);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_dealer_rating_on_review
  AFTER INSERT OR UPDATE OR DELETE ON car_dealer_reviews
  FOR EACH ROW EXECUTE FUNCTION update_dealer_rating();

-- Expire promotions function (cron job ile çalıştırılacak)
CREATE OR REPLACE FUNCTION expire_car_promotions()
RETURNS void AS $$
BEGIN
  -- Expire promotions
  UPDATE car_listing_promotions
  SET status = 'expired'
  WHERE status = 'active' AND expires_at < NOW();

  -- Remove featured/premium flags from listings
  UPDATE car_listings SET
    is_featured = FALSE,
    featured_until = NULL
  WHERE is_featured = TRUE
    AND featured_until < NOW()
    AND NOT EXISTS (
      SELECT 1 FROM car_listing_promotions
      WHERE listing_id = car_listings.id
        AND promotion_type = 'featured'
        AND status = 'active'
        AND expires_at > NOW()
    );

  UPDATE car_listings SET
    is_premium = FALSE,
    premium_until = NULL
  WHERE is_premium = TRUE
    AND premium_until < NOW()
    AND NOT EXISTS (
      SELECT 1 FROM car_listing_promotions
      WHERE listing_id = car_listings.id
        AND promotion_type = 'premium'
        AND status = 'active'
        AND expires_at > NOW()
    );
END;
$$ LANGUAGE plpgsql;

-- Dashboard stats function
CREATE OR REPLACE FUNCTION get_car_sales_dashboard_stats()
RETURNS JSON AS $$
DECLARE
  result JSON;
BEGIN
  SELECT json_build_object(
    'total_listings', (SELECT COUNT(*) FROM car_listings),
    'active_listings', (SELECT COUNT(*) FROM car_listings WHERE status = 'active'),
    'pending_listings', (SELECT COUNT(*) FROM car_listings WHERE status = 'pending'),
    'sold_listings', (SELECT COUNT(*) FROM car_listings WHERE status = 'sold'),
    'total_dealers', (SELECT COUNT(*) FROM car_dealers),
    'active_dealers', (SELECT COUNT(*) FROM car_dealers WHERE status = 'active'),
    'pending_applications', (SELECT COUNT(*) FROM car_dealer_applications WHERE status = 'pending'),
    'total_views_today', (SELECT COUNT(*) FROM car_listing_views WHERE viewed_at >= CURRENT_DATE),
    'total_views_week', (SELECT COUNT(*) FROM car_listing_views WHERE viewed_at >= CURRENT_DATE - INTERVAL '7 days'),
    'active_promotions', (SELECT COUNT(*) FROM car_listing_promotions WHERE status = 'active' AND expires_at > NOW()),
    'promotion_revenue', (SELECT COALESCE(SUM(amount_paid), 0) FROM car_listing_promotions WHERE payment_status = 'completed'),
    'top_brands', (
      SELECT json_agg(brand_data) FROM (
        SELECT brand_name, COUNT(*) as count
        FROM car_listings WHERE status = 'active'
        GROUP BY brand_name
        ORDER BY count DESC
        LIMIT 5
      ) brand_data
    )
  ) INTO result;

  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- GRANTS (Admin kullanıcıları için)
-- ============================================
-- Not: Supabase service role otomatik olarak tüm tablolara erişebilir
-- Admin paneli service role kullanacak

COMMENT ON TABLE car_brands IS 'Araç markaları - Admin tarafından yönetilir';
COMMENT ON TABLE car_features IS 'Araç özellikleri/donanımları - Admin tarafından yönetilir';
COMMENT ON TABLE car_dealers IS 'Galeri ve satıcı profilleri';
COMMENT ON TABLE car_dealer_applications IS 'Satıcı başvuruları - Admin onayı gerektirir';
COMMENT ON TABLE car_listings IS 'Araç ilanları';
COMMENT ON TABLE car_promotion_prices IS 'Promosyon fiyatları - Admin tarafından yönetilir';
COMMENT ON TABLE car_listing_promotions IS 'Aktif promosyonlar';
COMMENT ON TABLE car_listing_views IS 'İlan görüntülenme kayıtları';
COMMENT ON TABLE car_favorites IS 'Kullanıcı favorileri';
COMMENT ON TABLE car_contact_requests IS 'İletişim talepleri';
COMMENT ON TABLE car_settings IS 'Sistem ayarları - Admin tarafından yönetilir';
COMMENT ON TABLE car_dealer_reviews IS 'Satıcı değerlendirmeleri';
