-- ============================================================
-- PROMOTION SYSTEM MIGRATION
-- Date: 2026-03-18
-- ============================================================

-- ==================== 1. property_promotion_prices ====================
CREATE TABLE IF NOT EXISTS property_promotion_prices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  promotion_type TEXT NOT NULL CHECK (promotion_type IN ('featured', 'premium')),
  duration_days INTEGER NOT NULL,
  price NUMERIC(10,2) NOT NULL,
  discounted_price NUMERIC(10,2),
  label TEXT,
  description TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS for property_promotion_prices
ALTER TABLE property_promotion_prices ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read active property promotion prices"
  ON property_promotion_prices FOR SELECT
  USING (is_active = true);
CREATE POLICY "Admins can manage property promotion prices"
  ON property_promotion_prices FOR ALL
  USING (auth.role() = 'authenticated');

-- Seed: featured 7/14/30 gün
INSERT INTO property_promotion_prices (promotion_type, duration_days, price, label, description, sort_order) VALUES
  ('featured', 7,  149, 'Öne Çıkar - 1 Hafta',   '7 gün boyunca listelerde ön sırada görün', 1),
  ('featured', 14, 249, 'Öne Çıkar - 2 Hafta',   '14 gün boyunca listelerde ön sırada görün', 2),
  ('featured', 30, 449, 'Öne Çıkar - 1 Ay',      '30 gün boyunca listelerde ön sırada görün', 3),
  ('premium',  7,  299, 'Premium - 1 Hafta',      '7 gün boyunca en üst sırada, vurgulu badge ile görün', 4),
  ('premium',  14, 499, 'Premium - 2 Hafta',      '14 gün boyunca en üst sırada, vurgulu badge ile görün', 5),
  ('premium',  30, 899, 'Premium - 1 Ay',         '30 gün boyunca en üst sırada, vurgulu badge ile görün', 6)
ON CONFLICT DO NOTHING;

-- ==================== 2. property_promotions ====================
CREATE TABLE IF NOT EXISTS property_promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES property_listings(id) ON DELETE CASCADE,
  realtor_id UUID REFERENCES realtors(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price_id UUID REFERENCES property_promotion_prices(id) ON DELETE SET NULL,
  promotion_type TEXT NOT NULL CHECK (promotion_type IN ('featured', 'premium')),
  duration_days INTEGER NOT NULL,
  amount_paid NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method TEXT,
  payment_reference TEXT,
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled')),
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  -- Admin fields
  approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  admin_note TEXT,
  -- Stats
  views_before INTEGER NOT NULL DEFAULT 0,
  views_during INTEGER NOT NULL DEFAULT 0,
  is_featured BOOLEAN GENERATED ALWAYS AS (promotion_type IN ('featured', 'premium')) STORED,
  is_premium BOOLEAN GENERATED ALWAYS AS (promotion_type = 'premium') STORED,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS for property_promotions
ALTER TABLE property_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Realtors can view and insert their own property promotions"
  ON property_promotions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all property promotions"
  ON property_promotions FOR ALL
  USING (auth.role() = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_property_promotions_listing_id ON property_promotions(listing_id);
CREATE INDEX IF NOT EXISTS idx_property_promotions_user_id ON property_promotions(user_id);
CREATE INDEX IF NOT EXISTS idx_property_promotions_status ON property_promotions(status);

-- ==================== 3. job_listing_promotions ====================
-- Check if job_promotion_prices exists (referenced as price_id)
CREATE TABLE IF NOT EXISTS job_listing_promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  listing_id UUID NOT NULL REFERENCES job_listings(id) ON DELETE CASCADE,
  company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  price_id UUID REFERENCES job_promotion_prices(id) ON DELETE SET NULL,
  promotion_type TEXT NOT NULL CHECK (promotion_type IN ('featured', 'premium')),
  duration_days INTEGER NOT NULL,
  amount_paid NUMERIC(10,2) NOT NULL DEFAULT 0,
  payment_method TEXT,
  payment_reference TEXT,
  payment_status TEXT NOT NULL DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'expired', 'cancelled')),
  started_at TIMESTAMPTZ,
  expires_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  cancellation_reason TEXT,
  -- Admin fields
  approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  approved_at TIMESTAMPTZ,
  admin_note TEXT,
  -- Stats
  views_before INTEGER NOT NULL DEFAULT 0,
  views_during INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- RLS for job_listing_promotions
ALTER TABLE job_listing_promotions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view and insert their own job promotions"
  ON job_listing_promotions FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admins can manage all job promotions"
  ON job_listing_promotions FOR ALL
  USING (auth.role() = 'authenticated');

CREATE INDEX IF NOT EXISTS idx_job_listing_promotions_listing_id ON job_listing_promotions(listing_id);
CREATE INDEX IF NOT EXISTS idx_job_listing_promotions_status ON job_listing_promotions(status);

-- ==================== 4. ALTER car_listing_promotions ====================

-- Add admin columns if they don't exist
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='car_listing_promotions' AND column_name='approved_by') THEN
    ALTER TABLE car_listing_promotions ADD COLUMN approved_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='car_listing_promotions' AND column_name='approved_at') THEN
    ALTER TABLE car_listing_promotions ADD COLUMN approved_at TIMESTAMPTZ;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='car_listing_promotions' AND column_name='admin_note') THEN
    ALTER TABLE car_listing_promotions ADD COLUMN admin_note TEXT;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='car_listing_promotions' AND column_name='payment_status') THEN
    ALTER TABLE car_listing_promotions ADD COLUMN payment_status TEXT NOT NULL DEFAULT 'pending';
  END IF;
END $$;

-- Drop old CHECK constraint on status and recreate with 'pending'
DO $$
DECLARE
  constraint_name TEXT;
BEGIN
  SELECT conname INTO constraint_name
  FROM pg_constraint
  WHERE conrelid = 'car_listing_promotions'::regclass
    AND contype = 'c'
    AND pg_get_constraintdef(oid) LIKE '%status%';

  IF constraint_name IS NOT NULL THEN
    EXECUTE 'ALTER TABLE car_listing_promotions DROP CONSTRAINT ' || quote_ident(constraint_name);
  END IF;
END $$;

ALTER TABLE car_listing_promotions
  ADD CONSTRAINT car_listing_promotions_status_check
  CHECK (status IN ('pending', 'active', 'expired', 'cancelled'));

-- Add payment_status CHECK if not exists
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'car_listing_promotions'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%payment_status%'
  ) THEN
    ALTER TABLE car_listing_promotions
      ADD CONSTRAINT car_listing_promotions_payment_status_check
      CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded'));
  END IF;
END $$;

-- Admin RLS policy for car_listing_promotions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'car_listing_promotions'
      AND policyname = 'Admins can manage all car promotions'
  ) THEN
    CREATE POLICY "Admins can manage all car promotions"
      ON car_listing_promotions FOR ALL
      USING (auth.role() = 'authenticated');
  END IF;
END $$;

-- ==================== 5. RPC: get_promotion_charges_for_invoice ====================
CREATE OR REPLACE FUNCTION get_promotion_charges_for_invoice(
  p_sector TEXT,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS TABLE (
  merchant_id TEXT,
  merchant_name TEXT,
  listing_title TEXT,
  promotion_type TEXT,
  duration_days INTEGER,
  amount NUMERIC,
  approved_at TIMESTAMPTZ,
  sector TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_sector = 'carSales' OR p_sector = 'car_sales' THEN
    RETURN QUERY
      SELECT
        COALESCE(cd.user_id::TEXT, clp.user_id::TEXT) AS merchant_id,
        COALESCE(cd.business_name, 'Galeri') AS merchant_name,
        COALESCE(cl.title, 'Araç İlanı') AS listing_title,
        clp.promotion_type,
        clp.duration_days,
        clp.amount_paid AS amount,
        clp.approved_at,
        'carSales'::TEXT AS sector
      FROM car_listing_promotions clp
      LEFT JOIN car_listings cl ON cl.id = clp.listing_id
      LEFT JOIN car_dealers cd ON cd.user_id = clp.user_id AND cd.status = 'active'
      WHERE clp.payment_status = 'completed'
        AND clp.approved_at BETWEEN p_start_date AND p_end_date;

  ELSIF p_sector = 'realEstate' OR p_sector = 'real_estate' THEN
    RETURN QUERY
      SELECT
        pp.user_id::TEXT AS merchant_id,
        COALESCE(r.business_name, r.full_name, 'Emlakçı') AS merchant_name,
        COALESCE(pl.title, 'Emlak İlanı') AS listing_title,
        pp.promotion_type,
        pp.duration_days,
        pp.amount_paid AS amount,
        pp.approved_at,
        'realEstate'::TEXT AS sector
      FROM property_promotions pp
      LEFT JOIN property_listings pl ON pl.id = pp.listing_id
      LEFT JOIN realtors r ON r.user_id = pp.user_id
      WHERE pp.payment_status = 'completed'
        AND pp.approved_at BETWEEN p_start_date AND p_end_date;

  ELSIF p_sector = 'jobs' THEN
    RETURN QUERY
      SELECT
        jlp.user_id::TEXT AS merchant_id,
        COALESCE(c.name, 'Şirket') AS merchant_name,
        COALESCE(jl.title, 'İş İlanı') AS listing_title,
        jlp.promotion_type,
        jlp.duration_days,
        jlp.amount_paid AS amount,
        jlp.approved_at,
        'jobs'::TEXT AS sector
      FROM job_listing_promotions jlp
      LEFT JOIN job_listings jl ON jl.id = jlp.listing_id
      LEFT JOIN companies c ON c.id = jlp.company_id
      WHERE jlp.payment_status = 'completed'
        AND jlp.approved_at BETWEEN p_start_date AND p_end_date;

  END IF;
END;
$$;
