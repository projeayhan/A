-- ============================================
-- ARAÇ FİLTRE TİPLERİ - SUPABASE MIGRATION
-- Tarih: 2026-01-26
-- Açıklama: Gövde tipi, yakıt tipi, vites tipi tabloları
-- ============================================

-- ============================================
-- 1. CAR_BODY_TYPES - Gövde Tipleri
-- ============================================
CREATE TABLE IF NOT EXISTS car_body_types (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  icon VARCHAR(50) DEFAULT 'directions_car',
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Gövde tipi verileri
INSERT INTO car_body_types (id, name, icon, sort_order) VALUES
  ('sedan', 'Sedan', 'directions_car', 1),
  ('hatchback', 'Hatchback', 'directions_car_filled', 2),
  ('suv', 'SUV', 'directions_car_filled', 3),
  ('crossover', 'Crossover', 'directions_car', 4),
  ('coupe', 'Coupe', 'sports_motorsports', 5),
  ('convertible', 'Cabrio', 'wb_sunny', 6),
  ('wagon', 'Station Wagon', 'local_shipping', 7),
  ('pickup', 'Pickup', 'local_shipping', 8),
  ('van', 'Van', 'airport_shuttle', 9),
  ('minivan', 'Minivan', 'family_restroom', 10),
  ('sports', 'Spor', 'speed', 11),
  ('luxury', 'Lüks', 'diamond', 12)
ON CONFLICT (id) DO NOTHING;

-- Index
CREATE INDEX IF NOT EXISTS idx_car_body_types_active ON car_body_types(sort_order) WHERE is_active = true;

-- ============================================
-- 2. CAR_FUEL_TYPES - Yakıt Tipleri
-- ============================================
CREATE TABLE IF NOT EXISTS car_fuel_types (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  icon VARCHAR(50) DEFAULT 'local_gas_station',
  color VARCHAR(10) DEFAULT '#6B7280',
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Yakıt tipi verileri
INSERT INTO car_fuel_types (id, name, icon, color, sort_order) VALUES
  ('petrol', 'Benzin', 'local_gas_station', '#EF4444', 1),
  ('diesel', 'Dizel', 'local_gas_station', '#6B7280', 2),
  ('electric', 'Elektrik', 'electric_bolt', '#10B981', 3),
  ('hybrid', 'Hibrit', 'eco', '#3B82F6', 4),
  ('plugin_hybrid', 'Plug-in Hibrit', 'power', '#8B5CF6', 5),
  ('lpg', 'LPG', 'propane_tank', '#F59E0B', 6)
ON CONFLICT (id) DO NOTHING;

-- Index
CREATE INDEX IF NOT EXISTS idx_car_fuel_types_active ON car_fuel_types(sort_order) WHERE is_active = true;

-- ============================================
-- 3. CAR_TRANSMISSIONS - Vites Tipleri
-- ============================================
CREATE TABLE IF NOT EXISTS car_transmissions (
  id VARCHAR(50) PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  icon VARCHAR(50) DEFAULT 'settings',
  sort_order INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vites tipi verileri
INSERT INTO car_transmissions (id, name, icon, sort_order) VALUES
  ('automatic', 'Otomatik', 'settings', 1),
  ('manual', 'Manuel', 'settings_applications', 2),
  ('semi_automatic', 'Yarı Otomatik', 'tune', 3)
ON CONFLICT (id) DO NOTHING;

-- Index
CREATE INDEX IF NOT EXISTS idx_car_transmissions_active ON car_transmissions(sort_order) WHERE is_active = true;

-- ============================================
-- 4. TRIGGER - updated_at otomatik güncelleme
-- ============================================
CREATE OR REPLACE FUNCTION update_filter_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Body types trigger
DROP TRIGGER IF EXISTS trigger_car_body_types_updated_at ON car_body_types;
CREATE TRIGGER trigger_car_body_types_updated_at
  BEFORE UPDATE ON car_body_types
  FOR EACH ROW
  EXECUTE FUNCTION update_filter_types_updated_at();

-- Fuel types trigger
DROP TRIGGER IF EXISTS trigger_car_fuel_types_updated_at ON car_fuel_types;
CREATE TRIGGER trigger_car_fuel_types_updated_at
  BEFORE UPDATE ON car_fuel_types
  FOR EACH ROW
  EXECUTE FUNCTION update_filter_types_updated_at();

-- Transmissions trigger
DROP TRIGGER IF EXISTS trigger_car_transmissions_updated_at ON car_transmissions;
CREATE TRIGGER trigger_car_transmissions_updated_at
  BEFORE UPDATE ON car_transmissions
  FOR EACH ROW
  EXECUTE FUNCTION update_filter_types_updated_at();

-- ============================================
-- 5. RLS POLİCİES
-- ============================================
ALTER TABLE car_body_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_fuel_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE car_transmissions ENABLE ROW LEVEL SECURITY;

-- Herkes okuyabilir (aktif olanları)
CREATE POLICY "Public read car_body_types" ON car_body_types
  FOR SELECT USING (is_active = true);

CREATE POLICY "Public read car_fuel_types" ON car_fuel_types
  FOR SELECT USING (is_active = true);

CREATE POLICY "Public read car_transmissions" ON car_transmissions
  FOR SELECT USING (is_active = true);

-- Admin service_role tüm işlemleri yapabilir (otomatik)
