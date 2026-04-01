-- ============================================================
-- Sync promotion payments into finance_entries
-- Adds triggers for auto-sync on future promotion approvals
-- Updates get_finance_stats to include promotion revenue
-- ============================================================

-- ============================================================
-- 1. Sync existing promotion payments to finance_entries
-- ============================================================
CREATE OR REPLACE FUNCTION sync_promotion_finance_entries()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_car_synced INT := 0;
  v_property_synced INT := 0;
  v_job_synced INT := 0;
  v_kdv_rate NUMERIC := 20.00;
BEGIN
  -- ── CAR LISTING PROMOTIONS ──
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at
  )
  SELECT
    'income',
    'one_cikarma_geliri',
    p.promotion_type,
    'Araç öne çıkarma - ' || COALESCE(p.promotion_type, 'featured') || ' (' || p.duration_days || ' gün)',
    ROUND(p.amount_paid / (1 + v_kdv_rate / 100), 2),
    v_kdv_rate,
    ROUND(p.amount_paid - (p.amount_paid / (1 + v_kdv_rate / 100)), 2),
    p.amount_paid,
    'promotion',
    p.id::text,
    CASE WHEN p.payment_status = 'completed' THEN 'paid' ELSE 'pending' END,
    p.payment_method,
    CASE WHEN p.payment_status = 'completed' THEN COALESCE(p.started_at, p.created_at) ELSE NULL END,
    p.created_at
  FROM car_listing_promotions p
  WHERE p.payment_status = 'completed'
    AND p.amount_paid > 0
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = p.id::text AND fe.source_type = 'promotion'
    );
  GET DIAGNOSTICS v_car_synced = ROW_COUNT;

  -- ── PROPERTY PROMOTIONS ──
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at
  )
  SELECT
    'income',
    'one_cikarma_geliri',
    p.promotion_type,
    'Emlak öne çıkarma - ' || COALESCE(p.promotion_type, 'featured') || ' (' || p.duration_days || ' gün)',
    ROUND(p.amount_paid / (1 + v_kdv_rate / 100), 2),
    v_kdv_rate,
    ROUND(p.amount_paid - (p.amount_paid / (1 + v_kdv_rate / 100)), 2),
    p.amount_paid,
    'promotion',
    p.id::text,
    CASE WHEN p.payment_status = 'completed' THEN 'paid' ELSE 'pending' END,
    p.payment_method,
    CASE WHEN p.payment_status = 'completed' THEN COALESCE(p.started_at, p.created_at) ELSE NULL END,
    p.created_at
  FROM property_promotions p
  WHERE p.payment_status = 'completed'
    AND p.amount_paid > 0
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = p.id::text AND fe.source_type = 'promotion'
    );
  GET DIAGNOSTICS v_property_synced = ROW_COUNT;

  -- ── JOB LISTING PROMOTIONS ──
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at
  )
  SELECT
    'income',
    'one_cikarma_geliri',
    p.promotion_type,
    'İş ilanı öne çıkarma - ' || COALESCE(p.promotion_type, 'featured') || ' (' || p.duration_days || ' gün)',
    ROUND(p.amount_paid / (1 + v_kdv_rate / 100), 2),
    v_kdv_rate,
    ROUND(p.amount_paid - (p.amount_paid / (1 + v_kdv_rate / 100)), 2),
    p.amount_paid,
    'promotion',
    p.id::text,
    CASE WHEN p.payment_status = 'completed' THEN 'paid' ELSE 'pending' END,
    p.payment_method,
    CASE WHEN p.payment_status = 'completed' THEN COALESCE(p.starts_at, p.created_at) ELSE NULL END,
    p.created_at
  FROM job_listing_promotions p
  WHERE p.payment_status = 'completed'
    AND p.amount_paid > 0
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = p.id::text AND fe.source_type = 'promotion'
    );
  GET DIAGNOSTICS v_job_synced = ROW_COUNT;

  RETURN jsonb_build_object(
    'car_promotions_synced', v_car_synced,
    'property_promotions_synced', v_property_synced,
    'job_promotions_synced', v_job_synced,
    'total_synced', v_car_synced + v_property_synced + v_job_synced
  );
END;
$$;

-- ============================================================
-- 2. Auto-sync trigger function for promotion payments
-- ============================================================
CREATE OR REPLACE FUNCTION sync_promotion_to_finance()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_kdv_rate NUMERIC := 20.00;
  v_description TEXT;
  v_sector TEXT;
BEGIN
  -- Only trigger when payment_status changes to 'completed' and amount > 0
  IF NEW.payment_status = 'completed' AND NEW.amount_paid > 0
     AND (OLD IS NULL OR OLD.payment_status != 'completed') THEN

    -- Determine sector from table name
    IF TG_TABLE_NAME = 'car_listing_promotions' THEN
      v_sector := 'Araç';
    ELSIF TG_TABLE_NAME = 'property_promotions' THEN
      v_sector := 'Emlak';
    ELSIF TG_TABLE_NAME = 'job_listing_promotions' THEN
      v_sector := 'İş ilanı';
    END IF;

    v_description := v_sector || ' öne çıkarma - ' || COALESCE(NEW.promotion_type, 'featured') || ' (' || NEW.duration_days || ' gün)';

    -- Prevent duplicate entries
    IF NOT EXISTS (
      SELECT 1 FROM finance_entries WHERE source_id = NEW.id::text AND source_type = 'promotion'
    ) THEN
      INSERT INTO finance_entries (
        entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
        source_type, source_id, payment_status, payment_method, paid_at, created_at
      ) VALUES (
        'income',
        'one_cikarma_geliri',
        NEW.promotion_type,
        v_description,
        ROUND(NEW.amount_paid / (1 + v_kdv_rate / 100), 2),
        v_kdv_rate,
        ROUND(NEW.amount_paid - (NEW.amount_paid / (1 + v_kdv_rate / 100)), 2),
        NEW.amount_paid,
        'promotion',
        NEW.id::text,
        'paid',
        NEW.payment_method,
        NOW(),
        NEW.created_at
      );
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- ============================================================
-- 3. Create triggers on all three promotion tables
-- ============================================================
DROP TRIGGER IF EXISTS trg_car_promotion_finance ON car_listing_promotions;
CREATE TRIGGER trg_car_promotion_finance
  AFTER INSERT OR UPDATE OF payment_status ON car_listing_promotions
  FOR EACH ROW EXECUTE FUNCTION sync_promotion_to_finance();

DROP TRIGGER IF EXISTS trg_property_promotion_finance ON property_promotions;
CREATE TRIGGER trg_property_promotion_finance
  AFTER INSERT OR UPDATE OF payment_status ON property_promotions
  FOR EACH ROW EXECUTE FUNCTION sync_promotion_to_finance();

DROP TRIGGER IF EXISTS trg_job_promotion_finance ON job_listing_promotions;
CREATE TRIGGER trg_job_promotion_finance
  AFTER INSERT OR UPDATE OF payment_status ON job_listing_promotions
  FOR EACH ROW EXECUTE FUNCTION sync_promotion_to_finance();

-- ============================================================
-- 4. Update get_finance_stats to include promotion revenue
-- ============================================================
CREATE OR REPLACE FUNCTION get_finance_stats(p_days INT DEFAULT 30)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start DATE;
  v_prev_start DATE;
  v_prev_end DATE;
  v_total_commission NUMERIC := 0;
  v_prev_total_commission NUMERIC := 0;
  v_total_kdv NUMERIC := 0;
  v_prev_total_kdv NUMERIC := 0;
  v_paid_commission NUMERIC := 0;
  v_pending_commission NUMERIC := 0;
  v_online_collected NUMERIC := 0;
  v_food_commission NUMERIC := 0;
  v_store_commission NUMERIC := 0;
  v_taxi_commission NUMERIC := 0;
  v_rental_commission NUMERIC := 0;
  v_promotion_commission NUMERIC := 0;
  v_food_order_total NUMERIC := 0;
  v_store_order_total NUMERIC := 0;
  v_taxi_order_total NUMERIC := 0;
  v_rental_order_total NUMERIC := 0;
  v_monthly JSONB;
  v_daily JSONB;
BEGIN
  v_start := CURRENT_DATE - (p_days || ' days')::INTERVAL;
  v_prev_end := v_start - INTERVAL '1 day';
  v_prev_start := v_prev_end - (p_days || ' days')::INTERVAL;

  -- Toplam komisyon geliri (hizmet bedeli, KDV hariç)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_commission
  FROM finance_entries WHERE entry_type = 'income' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(amount), 0) INTO v_prev_total_commission
  FROM finance_entries WHERE entry_type = 'income' AND created_at::date BETWEEN v_prev_start AND v_prev_end;

  -- Toplam KDV (gerçek, DB'den)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_total_kdv
  FROM finance_entries WHERE entry_type = 'income' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_prev_total_kdv
  FROM finance_entries WHERE entry_type = 'income' AND created_at::date BETWEEN v_prev_start AND v_prev_end;

  -- Tahsil edilen komisyon (online ödeme → direkt kesildi)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_paid_commission
  FROM finance_entries WHERE entry_type = 'income' AND payment_status = 'paid' AND created_at::date >= v_start;

  -- Bekleyen komisyon (kapıda ödeme → işletme borçlu)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_pending_commission
  FROM finance_entries WHERE entry_type = 'income' AND payment_status IN ('pending', 'overdue');

  -- Sektöre göre komisyon gelirleri
  SELECT COALESCE(SUM(amount), 0) INTO v_food_commission
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'food' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(amount), 0) INTO v_store_commission
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'store' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(amount), 0) INTO v_taxi_commission
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'taxi' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(amount), 0) INTO v_rental_commission
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'rental' AND created_at::date >= v_start;

  -- Öne çıkarma geliri
  SELECT COALESCE(SUM(amount), 0) INTO v_promotion_commission
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'promotion' AND created_at::date >= v_start;

  -- Sektöre göre toplam sipariş cirosu (notes'tan parse)
  SELECT COALESCE(SUM(
    CASE WHEN notes LIKE 'siparis_tutari:%'
      THEN SPLIT_PART(SPLIT_PART(notes, 'siparis_tutari:', 2), '|', 1)::NUMERIC
      WHEN notes LIKE 'sefer_tutari:%'
      THEN SPLIT_PART(SPLIT_PART(notes, 'sefer_tutari:', 2), '|', 1)::NUMERIC
      WHEN notes LIKE 'rezervasyon_tutari:%'
      THEN SPLIT_PART(SPLIT_PART(notes, 'rezervasyon_tutari:', 2), '|', 1)::NUMERIC
      ELSE 0
    END
  ), 0) INTO v_food_order_total
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'food' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(
    CASE WHEN notes LIKE 'siparis_tutari:%'
      THEN SPLIT_PART(SPLIT_PART(notes, 'siparis_tutari:', 2), '|', 1)::NUMERIC
      ELSE 0
    END
  ), 0) INTO v_store_order_total
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'store' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(
    CASE WHEN notes LIKE 'sefer_tutari:%'
      THEN SPLIT_PART(SPLIT_PART(notes, 'sefer_tutari:', 2), '|', 1)::NUMERIC
      ELSE 0
    END
  ), 0) INTO v_taxi_order_total
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'taxi' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(
    CASE WHEN notes LIKE 'rezervasyon_tutari:%'
      THEN SPLIT_PART(SPLIT_PART(notes, 'rezervasyon_tutari:', 2), '|', 1)::NUMERIC
      ELSE 0
    END
  ), 0) INTO v_rental_order_total
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'rental' AND created_at::date >= v_start;

  -- Aylık komisyon geliri (son 12 ay)
  SELECT COALESCE(jsonb_agg(row_to_json(mr)::jsonb ORDER BY mr.month_num), '[]'::jsonb)
  INTO v_monthly
  FROM (
    SELECT
      EXTRACT(MONTH FROM DATE_TRUNC('month', created_at))::INT AS month_num,
      TO_CHAR(DATE_TRUNC('month', created_at), 'TMmon') AS month_name,
      ROUND(SUM(amount)::NUMERIC, 2) AS revenue,
      ROUND(SUM(kdv_amount)::NUMERIC, 2) AS kdv
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at >= (CURRENT_DATE - INTERVAL '12 months')
    GROUP BY DATE_TRUNC('month', created_at)
  ) mr;

  -- Günlük gelir (son p_days gün)
  SELECT COALESCE(jsonb_agg(row_to_json(dr)::jsonb ORDER BY dr.day_num), '[]'::jsonb)
  INTO v_daily
  FROM (
    SELECT
      EXTRACT(DOW FROM created_at::date)::INT AS day_num,
      TO_CHAR(created_at::date, 'Dy') AS day_name,
      ROUND(SUM(amount)::NUMERIC, 2) AS revenue
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at::date >= v_start
    GROUP BY created_at::date
  ) dr;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total_commission', v_total_commission,
      'prev_total_commission', v_prev_total_commission,
      'total_revenue', v_total_commission,
      'prev_total_revenue', v_prev_total_commission,
      'total_kdv', v_total_kdv,
      'prev_total_kdv', v_prev_total_kdv,
      'paid_commission', v_paid_commission,
      'pending_commission', v_pending_commission,
      'pending_payments', v_pending_commission,
      'total_order_volume', v_food_order_total + v_store_order_total + v_taxi_order_total + v_rental_order_total
    ),
    'revenue_distribution', jsonb_build_object(
      'food_revenue', v_food_commission,
      'store_revenue', v_store_commission,
      'taxi_revenue', v_taxi_commission,
      'rental_revenue', v_rental_commission,
      'promotion_revenue', v_promotion_commission
    ),
    'monthly_revenue', v_monthly,
    'daily_revenue', v_daily
  );
END;
$$;

-- ============================================================
-- 5. Run initial sync
-- ============================================================
SELECT sync_promotion_finance_entries();

-- ============================================================
-- 6. Grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION sync_promotion_finance_entries() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION sync_promotion_to_finance() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_finance_stats(INT) TO authenticated, service_role, anon;
