-- ============================================================
-- FINANCE MODULE REWRITE: Commission-Based Accounting
-- ============================================================
-- Platform geliri = komisyon hizmet bedeli (sipariş toplamı DEĞİL)
-- Platform KDV = komisyon × platform_kdv_rate (company_settings'den)
-- Online tahsilat = müşteriden platforma gelen para
-- Kapıda tahsilat = müşteriden işletmeye giden para
-- Net transfer = online_tahsilat - (komisyon + KDV)
-- ============================================================

-- ============================================================
-- 0. Helper: Platform KDV oranını company_settings'den oku
-- ============================================================
CREATE OR REPLACE FUNCTION get_platform_kdv_rate()
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_rate NUMERIC;
BEGIN
  SELECT COALESCE((kdv_rate::NUMERIC) / 100.0, 0.20)
  INTO v_rate
  FROM company_settings
  LIMIT 1;
  RETURN COALESCE(v_rate, 0.20);
EXCEPTION WHEN OTHERS THEN
  RETURN 0.20;
END;
$$;

-- ============================================================
-- 0b. Helper: Sektöre göre komisyon oranını oku
-- ============================================================
CREATE OR REPLACE FUNCTION get_commission_rate(p_sector TEXT, p_merchant_id UUID DEFAULT NULL)
RETURNS NUMERIC
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
  v_rate NUMERIC;
BEGIN
  -- Önce merchant-specific override kontrol et
  IF p_merchant_id IS NOT NULL THEN
    SELECT custom_rate INTO v_rate
    FROM merchant_commission_overrides
    WHERE merchant_id = p_merchant_id
      AND merchant_type = p_sector
    LIMIT 1;
    IF v_rate IS NOT NULL THEN
      RETURN v_rate / 100.0;
    END IF;
  END IF;

  -- Sonra sektör default rate
  SELECT default_rate INTO v_rate
  FROM commission_rates
  WHERE sector = p_sector
  LIMIT 1;

  RETURN COALESCE(v_rate / 100.0, 0.15);
END;
$$;

-- ============================================================
-- 1. Mevcut yanlış finance_entries'i temizle
-- ============================================================
DELETE FROM finance_entries WHERE source_type IN ('food', 'store', 'market', 'taxi', 'rental');

-- ============================================================
-- 2. Yeniden sync — komisyon bazlı
-- ============================================================
CREATE OR REPLACE FUNCTION sync_all_finance_entries()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_orders_synced INT := 0;
  v_taxi_synced INT := 0;
  v_rental_synced INT := 0;
  v_platform_kdv_rate NUMERIC;
  v_commission_rate NUMERIC;
BEGIN
  v_platform_kdv_rate := get_platform_kdv_rate();

  -- ══════════════════════════════════════════════════
  -- ORDERS (food/store) — Platform geliri = komisyon
  -- ══════════════════════════════════════════════════
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description,
    amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, merchant_id,
    payment_status, payment_method, paid_at,
    created_at, due_date, notes
  )
  SELECT
    'income',
    'komisyon_geliri',
    CASE
      WHEN m.type = 'restaurant' THEN 'yemek_komisyon'
      WHEN m.type = 'store' THEN 'market_komisyon'
      ELSE 'diger_komisyon'
    END,
    'Komisyon - Sipariş #' || COALESCE(o.order_number, LEFT(o.id::text, 8)) || ' (' || m.business_name || ')',

    -- amount = sipariş toplamı × komisyon oranı (hizmet bedeli)
    ROUND(o.total_amount * COALESCE(o.commission_rate, get_commission_rate(
      CASE WHEN m.type = 'restaurant' THEN 'food' ELSE 'store' END, o.merchant_id
    ) * 100) / 100, 2),

    -- KDV oranı = platform KDV oranı (company_settings'den)
    v_platform_kdv_rate * 100,

    -- KDV tutarı = hizmet bedeli × platform KDV oranı
    ROUND(
      (o.total_amount * COALESCE(o.commission_rate, get_commission_rate(
        CASE WHEN m.type = 'restaurant' THEN 'food' ELSE 'store' END, o.merchant_id
      ) * 100) / 100) * v_platform_kdv_rate
    , 2),

    -- total_amount = hizmet bedeli + KDV
    ROUND(
      (o.total_amount * COALESCE(o.commission_rate, get_commission_rate(
        CASE WHEN m.type = 'restaurant' THEN 'food' ELSE 'store' END, o.merchant_id
      ) * 100) / 100) * (1 + v_platform_kdv_rate)
    , 2),

    CASE WHEN m.type = 'restaurant' THEN 'food' ELSE 'store' END,
    o.id,
    o.merchant_id,

    -- payment_status: online ödeme ise 'paid', kapıda ise 'pending' (işletme borçlu)
    CASE
      WHEN o.payment_method IN ('online', 'stripe', 'credit_card') AND o.payment_status = 'paid'
        THEN 'paid'
      ELSE 'pending'
    END,

    o.payment_method,

    CASE
      WHEN o.payment_method IN ('online', 'stripe', 'credit_card') AND o.payment_status = 'paid'
        THEN COALESCE(o.delivered_at, o.created_at)
      ELSE NULL
    END,

    o.created_at,

    -- Kapıda ödeme ise 30 gün vade
    CASE
      WHEN o.payment_method NOT IN ('online', 'stripe', 'credit_card') OR o.payment_status != 'paid'
        THEN (o.created_at + INTERVAL '30 days')::date
      ELSE NULL
    END,

    -- Sipariş detaylarını notes'a yaz (fatura ve raporlarda kullanılacak)
    'siparis_tutari:' || o.total_amount::text ||
    '|odeme_yontemi:' || COALESCE(o.payment_method, 'bilinmiyor') ||
    '|odeme_durumu:' || COALESCE(o.payment_status, 'bilinmiyor')

  FROM orders o
  JOIN merchants m ON m.id = o.merchant_id
  WHERE o.status = 'delivered'
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe
      WHERE fe.source_id = o.id
        AND fe.source_type IN ('food', 'store')
        AND fe.entry_type = 'income'
    );
  GET DIAGNOSTICS v_orders_synced = ROW_COUNT;

  -- ══════════════════════════════════════════════════
  -- TAXI RIDES — Platform geliri = komisyon (%20)
  -- ══════════════════════════════════════════════════
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description,
    amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id,
    payment_status, payment_method, paid_at,
    created_at, notes
  )
  SELECT
    'income',
    'komisyon_geliri',
    'taksi_komisyon',
    'Komisyon - Taksi #' || COALESCE(t.ride_number, LEFT(t.id::text, 8)),

    -- Taksi komisyonu: fare × %20 (default taxi rate)
    ROUND(t.fare * get_commission_rate('taxi'), 2),
    v_platform_kdv_rate * 100,
    ROUND(t.fare * get_commission_rate('taxi') * v_platform_kdv_rate, 2),
    ROUND(t.fare * get_commission_rate('taxi') * (1 + v_platform_kdv_rate), 2),

    'taxi',
    t.id,

    -- Taksi: payment_method kolonu yok, şimdilik tamamlanmış = paid
    'paid',
    COALESCE(t.payment_method, 'online'),
    COALESCE(t.completed_at, t.created_at),
    t.created_at,

    'sefer_tutari:' || t.fare::text

  FROM taxi_rides t
  WHERE t.status = 'completed'
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe
      WHERE fe.source_id = t.id AND fe.source_type = 'taxi' AND fe.entry_type = 'income'
    );
  GET DIAGNOSTICS v_taxi_synced = ROW_COUNT;

  -- ══════════════════════════════════════════════════
  -- RENTAL BOOKINGS — Platform geliri = komisyon (%15)
  -- ══════════════════════════════════════════════════
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description,
    amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id,
    payment_status, payment_method, paid_at,
    created_at, due_date, notes
  )
  SELECT
    'income',
    'komisyon_geliri',
    'kiralama_komisyon',
    'Komisyon - Kiralama #' || COALESCE(rb.booking_number, LEFT(rb.id::text, 8)),

    ROUND(rb.total_amount * get_commission_rate('rental'), 2),
    v_platform_kdv_rate * 100,
    ROUND(rb.total_amount * get_commission_rate('rental') * v_platform_kdv_rate, 2),
    ROUND(rb.total_amount * get_commission_rate('rental') * (1 + v_platform_kdv_rate), 2),

    'rental',
    rb.id,

    CASE
      WHEN rb.payment_method IN ('online', 'stripe', 'credit_card') AND rb.payment_status = 'paid'
        THEN 'paid'
      ELSE 'pending'
    END,
    rb.payment_method,
    CASE
      WHEN rb.payment_method IN ('online', 'stripe', 'credit_card') AND rb.payment_status = 'paid'
        THEN rb.confirmed_at
      ELSE NULL
    END,
    rb.created_at,
    CASE
      WHEN rb.payment_method NOT IN ('online', 'stripe', 'credit_card') OR rb.payment_status != 'paid'
        THEN (rb.created_at + INTERVAL '30 days')::date
      ELSE NULL
    END,

    'rezervasyon_tutari:' || rb.total_amount::text ||
    '|odeme_yontemi:' || COALESCE(rb.payment_method, 'bilinmiyor')

  FROM rental_bookings rb
  WHERE rb.status IN ('completed', 'confirmed', 'active')
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe
      WHERE fe.source_id = rb.id AND fe.source_type = 'rental' AND fe.entry_type = 'income'
    );
  GET DIAGNOSTICS v_rental_synced = ROW_COUNT;

  RETURN jsonb_build_object(
    'orders_synced', v_orders_synced,
    'taxi_synced', v_taxi_synced,
    'rental_synced', v_rental_synced,
    'total_synced', v_orders_synced + v_taxi_synced + v_rental_synced
  );
END;
$$;

GRANT EXECUTE ON FUNCTION sync_all_finance_entries() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_platform_kdv_rate() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_commission_rate(TEXT, UUID) TO authenticated, service_role;

-- ============================================================
-- 3. Trigger: Sipariş teslim → komisyon geliri kaydı
-- ============================================================
CREATE OR REPLACE FUNCTION trg_order_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_platform_kdv_rate NUMERIC;
  v_comm_rate NUMERIC;
  v_commission NUMERIC;
  v_kdv NUMERIC;
  v_total NUMERIC;
  v_sector TEXT;
  v_merchant_name TEXT;
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    v_platform_kdv_rate := get_platform_kdv_rate();

    -- Sektörü belirle
    SELECT
      CASE WHEN m.type = 'restaurant' THEN 'food' ELSE 'store' END,
      m.business_name
    INTO v_sector, v_merchant_name
    FROM merchants m WHERE m.id = NEW.merchant_id;

    -- Komisyon oranı: önce order.commission_rate, yoksa DB'den
    v_comm_rate := COALESCE(NEW.commission_rate, get_commission_rate(v_sector, NEW.merchant_id) * 100) / 100;

    -- Hesaplamalar
    v_commission := ROUND(NEW.total_amount * v_comm_rate, 2);
    v_kdv := ROUND(v_commission * v_platform_kdv_rate, 2);
    v_total := v_commission + v_kdv;

    -- Komisyon geliri kaydı
    INSERT INTO finance_entries (
      entry_type, category, subcategory, description,
      amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, merchant_id,
      payment_status, payment_method, paid_at,
      created_at, due_date, notes
    ) VALUES (
      'income', 'komisyon_geliri',
      CASE WHEN v_sector = 'food' THEN 'yemek_komisyon' ELSE 'market_komisyon' END,
      'Komisyon - Sipariş #' || COALESCE(NEW.order_number, LEFT(NEW.id::text, 8)) || ' (' || COALESCE(v_merchant_name, '') || ')',
      v_commission, v_platform_kdv_rate * 100, v_kdv, v_total,
      v_sector, NEW.id, NEW.merchant_id,
      -- Online ödeme = para platformda, komisyon direkt kesilir (paid)
      -- Kapıda ödeme = işletme komisyonu borçlu (pending)
      CASE
        WHEN NEW.payment_method IN ('online', 'stripe', 'credit_card') AND NEW.payment_status = 'paid'
          THEN 'paid'
        ELSE 'pending'
      END,
      NEW.payment_method,
      CASE
        WHEN NEW.payment_method IN ('online', 'stripe', 'credit_card') AND NEW.payment_status = 'paid'
          THEN NOW()
        ELSE NULL
      END,
      NEW.created_at,
      CASE
        WHEN NEW.payment_method NOT IN ('online', 'stripe', 'credit_card') OR NEW.payment_status != 'paid'
          THEN (NEW.created_at + INTERVAL '30 days')::date
        ELSE NULL
      END,
      'siparis_tutari:' || NEW.total_amount::text ||
      '|odeme_yontemi:' || COALESCE(NEW.payment_method, 'bilinmiyor') ||
      '|komisyon_orani:' || (v_comm_rate * 100)::text
    ) ON CONFLICT DO NOTHING;

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_order_finance ON orders;
CREATE TRIGGER trg_order_finance
  AFTER UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION trg_order_finance_entry();

-- ============================================================
-- 4. Trigger: Taksi tamamlandı → komisyon geliri kaydı
-- ============================================================
CREATE OR REPLACE FUNCTION trg_taxi_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_platform_kdv_rate NUMERIC;
  v_comm_rate NUMERIC;
  v_commission NUMERIC;
  v_kdv NUMERIC;
  v_total NUMERIC;
  v_payment_method TEXT;
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    v_platform_kdv_rate := get_platform_kdv_rate();
    v_comm_rate := get_commission_rate('taxi');
    v_commission := ROUND(NEW.fare * v_comm_rate, 2);
    v_kdv := ROUND(v_commission * v_platform_kdv_rate, 2);
    v_total := v_commission + v_kdv;

    -- payment_method kolonu varsa kullan, yoksa default 'online'
    BEGIN
      EXECUTE 'SELECT ($1).payment_method' INTO v_payment_method USING NEW;
    EXCEPTION WHEN OTHERS THEN
      v_payment_method := 'online';
    END;

    INSERT INTO finance_entries (
      entry_type, category, subcategory, description,
      amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id,
      payment_status, payment_method, paid_at,
      created_at, notes
    ) VALUES (
      'income', 'komisyon_geliri', 'taksi_komisyon',
      'Komisyon - Taksi #' || COALESCE(NEW.ride_number, LEFT(NEW.id::text, 8)),
      v_commission, v_platform_kdv_rate * 100, v_kdv, v_total,
      'taxi', NEW.id,
      'paid', COALESCE(v_payment_method, 'online'), NOW(),
      NEW.created_at,
      'sefer_tutari:' || NEW.fare::text || '|komisyon_orani:' || (v_comm_rate * 100)::text
    ) ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_taxi_finance ON taxi_rides;
CREATE TRIGGER trg_taxi_finance
  AFTER UPDATE ON taxi_rides
  FOR EACH ROW
  EXECUTE FUNCTION trg_taxi_finance_entry();

-- ============================================================
-- 5. Trigger: Kiralama tamamlandı → komisyon geliri kaydı
-- ============================================================
CREATE OR REPLACE FUNCTION trg_rental_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_platform_kdv_rate NUMERIC;
  v_comm_rate NUMERIC;
  v_commission NUMERIC;
  v_kdv NUMERIC;
  v_total NUMERIC;
BEGIN
  IF NEW.status IN ('completed', 'confirmed') AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'confirmed')) THEN
    v_platform_kdv_rate := get_platform_kdv_rate();
    v_comm_rate := get_commission_rate('rental');
    v_commission := ROUND(NEW.total_amount * v_comm_rate, 2);
    v_kdv := ROUND(v_commission * v_platform_kdv_rate, 2);
    v_total := v_commission + v_kdv;

    INSERT INTO finance_entries (
      entry_type, category, subcategory, description,
      amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id,
      payment_status, payment_method, paid_at,
      created_at, due_date, notes
    ) VALUES (
      'income', 'komisyon_geliri', 'kiralama_komisyon',
      'Komisyon - Kiralama #' || COALESCE(NEW.booking_number, LEFT(NEW.id::text, 8)),
      v_commission, v_platform_kdv_rate * 100, v_kdv, v_total,
      'rental', NEW.id,
      CASE
        WHEN NEW.payment_method IN ('online', 'stripe', 'credit_card') AND NEW.payment_status = 'paid'
          THEN 'paid'
        ELSE 'pending'
      END,
      NEW.payment_method,
      CASE
        WHEN NEW.payment_method IN ('online', 'stripe', 'credit_card') AND NEW.payment_status = 'paid'
          THEN NOW()
        ELSE NULL
      END,
      NEW.created_at,
      CASE
        WHEN NEW.payment_method NOT IN ('online', 'stripe', 'credit_card') OR NEW.payment_status != 'paid'
          THEN (NEW.created_at + INTERVAL '30 days')::date
        ELSE NULL
      END,
      'rezervasyon_tutari:' || NEW.total_amount::text ||
      '|odeme_yontemi:' || COALESCE(NEW.payment_method, 'bilinmiyor')
    ) ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_rental_finance ON rental_bookings;
CREATE TRIGGER trg_rental_finance
  AFTER UPDATE ON rental_bookings
  FOR EACH ROW
  EXECUTE FUNCTION trg_rental_finance_entry();

-- ============================================================
-- 6. get_finance_stats — Komisyon bazlı, gerçek KDV
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

  -- Günlük komisyon geliri (son 7 gün)
  SELECT COALESCE(jsonb_agg(row_to_json(dr)::jsonb ORDER BY dr.day_num), '[]'::jsonb)
  INTO v_daily
  FROM (
    SELECT
      EXTRACT(DOW FROM created_at::date)::INT AS day_num,
      TO_CHAR(created_at::date, 'TMdy') AS day_name,
      ROUND(SUM(amount)::NUMERIC, 2) AS revenue
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at::date >= (CURRENT_DATE - INTERVAL '7 days')
    GROUP BY created_at::date
  ) dr;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total_commission', ROUND(v_total_commission, 2),
      'prev_total_commission', ROUND(v_prev_total_commission, 2),
      'total_kdv', ROUND(v_total_kdv, 2),
      'prev_total_kdv', ROUND(v_prev_total_kdv, 2),
      'paid_commission', ROUND(v_paid_commission, 2),
      'pending_commission', ROUND(v_pending_commission, 2),
      'total_order_volume', ROUND(v_food_order_total + v_store_order_total + v_taxi_order_total + v_rental_order_total, 2),
      -- Eski alanlar backward compat
      'total_revenue', ROUND(v_total_commission, 2),
      'prev_total_revenue', ROUND(v_prev_total_commission, 2),
      'commission_revenue', ROUND(v_total_commission, 2),
      'prev_commission_revenue', ROUND(v_prev_total_commission, 2),
      'partner_payments', 0,
      'prev_partner_payments', 0,
      'pending_payments', ROUND(v_pending_commission, 2)
    ),
    'revenue_distribution', jsonb_build_object(
      'food_revenue', ROUND(v_food_commission, 2),
      'store_revenue', ROUND(v_store_commission, 2),
      'taxi_revenue', ROUND(v_taxi_commission, 2),
      'rental_revenue', ROUND(v_rental_commission, 2)
    ),
    'order_volume', jsonb_build_object(
      'food_total', ROUND(v_food_order_total, 2),
      'store_total', ROUND(v_store_order_total, 2),
      'taxi_total', ROUND(v_taxi_order_total, 2),
      'rental_total', ROUND(v_rental_order_total, 2)
    ),
    'monthly_revenue', v_monthly,
    'daily_revenue', v_daily
  );
END;
$$;

-- ============================================================
-- 7. get_profit_loss — Komisyon bazlı
-- ============================================================
CREATE OR REPLACE FUNCTION get_profit_loss(p_start DATE, p_end DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_revenue  NUMERIC := 0;
  v_total_expenses NUMERIC := 0;
  v_monthly        JSONB;
  v_sectors        JSONB;
  v_expense_cats   JSONB;
BEGIN
  -- Gelir = komisyon hizmet bedeli (amount, KDV hariç)
  SELECT COALESCE(SUM(amount), 0) INTO v_total_revenue
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date >= p_start AND created_at::date <= p_end;

  -- Gider = manuel girilen giderler (varsa)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_expenses
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND created_at::date >= p_start AND created_at::date <= p_end;

  -- Sektör bazlı gelirler
  SELECT COALESCE(jsonb_agg(row_to_json(s)::jsonb), '[]'::jsonb)
  INTO v_sectors
  FROM (
    SELECT
      source_type AS sector,
      ROUND(SUM(amount)::NUMERIC, 2) AS revenue,
      ROUND(SUM(kdv_amount)::NUMERIC, 2) AS kdv
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at::date >= p_start AND created_at::date <= p_end
      AND source_type IS NOT NULL
    GROUP BY source_type
  ) s;

  -- Gider kategorileri
  SELECT COALESCE(jsonb_agg(row_to_json(ec)::jsonb), '[]'::jsonb)
  INTO v_expense_cats
  FROM (
    SELECT
      category,
      ROUND(SUM(total_amount)::NUMERIC, 2) AS amount
    FROM finance_entries
    WHERE entry_type = 'expense'
      AND created_at::date >= p_start AND created_at::date <= p_end
    GROUP BY category
  ) ec;

  -- Aylık kar/zarar
  SELECT COALESCE(jsonb_agg(row_to_json(m)::jsonb ORDER BY m.month), '[]'::jsonb)
  INTO v_monthly
  FROM (
    SELECT
      TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') AS month,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN amount ELSE 0 END), 0)::NUMERIC, 2) AS revenue,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)::NUMERIC, 2) AS expenses,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN amount ELSE 0 END), 0)::NUMERIC
          - COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)::NUMERIC, 2) AS profit
    FROM finance_entries
    WHERE created_at::date >= p_start AND created_at::date <= p_end
    GROUP BY DATE_TRUNC('month', created_at)
  ) m;

  RETURN jsonb_build_object(
    'total_revenue', ROUND(v_total_revenue, 2),
    'total_expenses', ROUND(v_total_expenses, 2),
    'net_profit', ROUND(v_total_revenue - v_total_expenses, 2),
    'sector_revenues', v_sectors,
    'expense_categories', v_expense_cats,
    'monthly_profits', v_monthly
  );
END;
$$;

-- ============================================================
-- 8. get_kdv_summary — Platform komisyon KDV'si
-- ============================================================
CREATE OR REPLACE FUNCTION get_kdv_summary(p_year INT, p_month INT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_collected  NUMERIC := 0;
  v_paid       NUMERIC := 0;
  v_start      DATE;
  v_end        DATE;
  v_sectors    JSONB;
BEGIN
  v_start := make_date(p_year, p_month, 1);
  v_end := (v_start + INTERVAL '1 month')::date;

  -- Toplanan KDV = komisyon faturalarındaki KDV
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_collected
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status = 'paid'
    AND created_at::date >= v_start AND created_at::date < v_end;

  -- Ödenen KDV = giderlerdeki indirilebilir KDV
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_paid
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND payment_status = 'paid'
    AND created_at::date >= v_start AND created_at::date < v_end;

  -- Sektör bazlı KDV
  SELECT COALESCE(jsonb_agg(row_to_json(sk)::jsonb), '[]'::jsonb)
  INTO v_sectors
  FROM (
    SELECT
      source_type AS sector,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2) AS kdv_collected,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'expense' AND tax_deductible = TRUE THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2) AS kdv_paid,
      ROUND(AVG(CASE WHEN entry_type = 'income' THEN kdv_rate ELSE NULL END)::NUMERIC, 0) AS kdv_rate
    FROM finance_entries
    WHERE created_at::date >= v_start AND created_at::date < v_end
      AND source_type IS NOT NULL
    GROUP BY source_type
  ) sk;

  RETURN jsonb_build_object(
    'total_kdv_collected', ROUND(v_collected, 2),
    'total_kdv_paid', ROUND(v_paid, 2),
    'net_kdv', ROUND(v_collected - v_paid, 2),
    'sector_kdv', v_sectors
  );
END;
$$;

-- ============================================================
-- 9. get_balance_sheet — Komisyon bazlı
-- ============================================================
CREATE OR REPLACE FUNCTION get_balance_sheet(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_cash              NUMERIC := 0;
  v_bank              NUMERIC := 0;
  v_receivables       NUMERIC := 0;
  v_other_receivables NUMERIC := 0;
  v_inventory         NUMERIC := 0;
  v_prepaid           NUMERIC := 0;
  v_lt_receivables    NUMERIC := 0;
  v_tangible          NUMERIC := 0;
  v_intangible        NUMERIC := 0;
  v_financial         NUMERIC := 0;
  v_trade_payables    NUMERIC := 0;
  v_other_payables    NUMERIC := 0;
  v_advances          NUMERIC := 0;
  v_taxes_payable     NUMERIC := 0;
  v_provisions        NUMERIC := 0;
  v_bank_loans        NUMERIC := 0;
  v_lt_trade_payables NUMERIC := 0;
  v_lt_other_payables NUMERIC := 0;
  v_current_assets    NUMERIC := 0;
  v_noncurrent_assets NUMERIC := 0;
  v_total_assets      NUMERIC := 0;
  v_current_liab      NUMERIC := 0;
  v_noncurrent_liab   NUMERIC := 0;
  v_total_liab        NUMERIC := 0;
  v_equity            NUMERIC := 0;
  v_current_profit    NUMERIC := 0;
  v_prev_date         DATE;
  v_prev_total_assets NUMERIC := 0;
  v_prev_total_liab   NUMERIC := 0;
  v_prev_equity       NUMERIC := 0;
  v_current_ratio     NUMERIC := 0;
  v_quick_ratio       NUMERIC := 0;
  v_debt_to_equity    NUMERIC := 0;
  v_equity_ratio      NUMERIC := 0;
  v_debt_ratio        NUMERIC := 0;
  v_working_capital   NUMERIC := 0;
  v_prev_cash         NUMERIC := 0;
  v_prev_bank         NUMERIC := 0;
  v_prev_recv         NUMERIC := 0;
  v_prev_trade_pay    NUMERIC := 0;
BEGIN
  v_prev_date := p_date - INTERVAL '1 month';

  -- 100: Kasa/Nakit = nakit tahsilatlar (komisyon geliri nakit ödenen)
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE -total_amount END), 0)
  INTO v_cash
  FROM finance_entries
  WHERE payment_status = 'paid'
    AND payment_method IN ('cash', 'nakit')
    AND created_at::date <= p_date;

  -- 102: Banka = online/kart tahsilatlar (komisyon geliri online ödenen)
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE -total_amount END), 0)
  INTO v_bank
  FROM finance_entries
  WHERE payment_status = 'paid'
    AND (payment_method IS NULL OR payment_method NOT IN ('cash', 'nakit'))
    AND created_at::date <= p_date;

  -- 120: Ticari Alacaklar = işletmelerden alınacak komisyon borçları
  SELECT COALESCE(SUM(total_amount), 0) INTO v_receivables
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status IN ('pending', 'overdue')
    AND (due_date IS NULL OR due_date <= (p_date + INTERVAL '1 year'))
    AND created_at::date <= p_date;

  -- 136: Diğer Alacaklar (KDV iade alacağı)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_other_receivables
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND payment_status = 'paid'
    AND created_at::date <= p_date;

  v_inventory := 0;

  -- 180: Peşin Ödenmiş Giderler
  SELECT COALESCE(SUM(total_amount), 0) INTO v_prepaid
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status = 'paid'
    AND due_date IS NOT NULL
    AND due_date > p_date
    AND created_at::date <= p_date;

  -- 220: Uzun Vadeli Alacaklar
  SELECT COALESCE(SUM(total_amount), 0) INTO v_lt_receivables
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status IN ('pending', 'overdue')
    AND due_date IS NOT NULL
    AND due_date > (p_date + INTERVAL '1 year')
    AND created_at::date <= p_date;

  -- Non-current assets
  SELECT COALESCE(SUM(total_amount), 0) INTO v_tangible
  FROM finance_entries
  WHERE entry_type = 'expense' AND payment_status = 'paid'
    AND category IN ('equipment', 'ekipman', 'demirbaş', 'araç', 'vehicle', 'furniture', 'mobilya')
    AND created_at::date <= p_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_intangible
  FROM finance_entries
  WHERE entry_type = 'expense' AND payment_status = 'paid'
    AND category IN ('software', 'yazılım', 'lisans', 'license', 'patent', 'marka')
    AND created_at::date <= p_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_financial
  FROM finance_entries
  WHERE entry_type = 'expense' AND payment_status = 'paid'
    AND category IN ('investment', 'yatırım', 'hisse', 'securities')
    AND created_at::date <= p_date;

  -- 320: Ticari Borçlar (short-term)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_trade_payables
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status IN ('pending', 'overdue')
    AND (due_date IS NULL OR due_date <= (p_date + INTERVAL '1 year'))
    AND created_at::date <= p_date;

  -- 360: Ödenecek Vergi (toplanan KDV - indirilen KDV)
  SELECT COALESCE(SUM(kdv_amount), 0) - COALESCE(
    (SELECT SUM(kdv_amount) FROM finance_entries WHERE entry_type = 'expense' AND tax_deductible = TRUE AND payment_status = 'paid' AND created_at::date <= p_date), 0)
  INTO v_taxes_payable
  FROM finance_entries
  WHERE entry_type = 'income' AND payment_status = 'paid' AND created_at::date <= p_date;
  IF v_taxes_payable < 0 THEN v_taxes_payable := 0; END IF;

  v_other_payables := 0;
  v_advances := 0;
  v_provisions := 0;
  v_bank_loans := 0;

  -- 420: Uzun Vadeli Ticari Borçlar
  SELECT COALESCE(SUM(total_amount), 0) INTO v_lt_trade_payables
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status IN ('pending', 'overdue')
    AND due_date IS NOT NULL
    AND due_date > (p_date + INTERVAL '1 year')
    AND created_at::date <= p_date;

  v_trade_payables := v_trade_payables - v_lt_trade_payables;
  v_lt_other_payables := 0;

  -- Totals
  v_current_assets := GREATEST(v_cash, 0) + GREATEST(v_bank, 0) + v_receivables + v_other_receivables + v_inventory + v_prepaid;
  v_noncurrent_assets := v_lt_receivables + v_tangible + v_intangible + v_financial;
  v_total_assets := v_current_assets + v_noncurrent_assets;

  v_current_liab := v_trade_payables + v_other_payables + v_advances + v_taxes_payable + v_provisions;
  v_noncurrent_liab := v_bank_loans + v_lt_trade_payables + v_lt_other_payables;
  v_total_liab := v_current_liab + v_noncurrent_liab;

  v_equity := v_total_assets - v_total_liab;
  v_current_profit := v_equity;

  -- Ratios
  IF v_current_liab > 0 THEN
    v_current_ratio := ROUND(v_current_assets / v_current_liab, 2);
    v_quick_ratio := ROUND((v_current_assets - v_inventory) / v_current_liab, 2);
  ELSE
    v_current_ratio := CASE WHEN v_current_assets > 0 THEN 999.99 ELSE 0 END;
    v_quick_ratio := CASE WHEN v_current_assets > 0 THEN 999.99 ELSE 0 END;
  END IF;

  IF v_equity > 0 THEN
    v_debt_to_equity := ROUND(v_total_liab / v_equity, 2);
  ELSE
    v_debt_to_equity := CASE WHEN v_total_liab > 0 THEN 999.99 ELSE 0 END;
  END IF;

  IF v_total_assets > 0 THEN
    v_equity_ratio := ROUND(v_equity / v_total_assets, 2);
    v_debt_ratio := ROUND(v_total_liab / v_total_assets, 2);
  ELSE
    v_equity_ratio := 0;
    v_debt_ratio := 0;
  END IF;

  v_working_capital := v_current_assets - v_current_liab;

  RETURN jsonb_build_object(
    'total_assets', ROUND(v_total_assets, 2),
    'total_liabilities', ROUND(v_total_liab, 2),
    'equity', ROUND(v_equity, 2),
    'assets', jsonb_build_array(
      jsonb_build_object('category', 'Kasa / Nakit', 'amount', ROUND(GREATEST(v_cash, 0), 2), 'prev_amount', 0, 'group', 'current', 'code', '100'),
      jsonb_build_object('category', 'Banka Hesapları', 'amount', ROUND(GREATEST(v_bank, 0), 2), 'prev_amount', 0, 'group', 'current', 'code', '102'),
      jsonb_build_object('category', 'Ticari Alacaklar', 'amount', ROUND(v_receivables, 2), 'prev_amount', 0, 'group', 'current', 'code', '120'),
      jsonb_build_object('category', 'Diğer Alacaklar', 'amount', ROUND(v_other_receivables, 2), 'prev_amount', 0, 'group', 'current', 'code', '136'),
      jsonb_build_object('category', 'Stoklar', 'amount', ROUND(v_inventory, 2), 'prev_amount', 0, 'group', 'current', 'code', '150'),
      jsonb_build_object('category', 'Peşin Ödenmiş Giderler', 'amount', ROUND(v_prepaid, 2), 'prev_amount', 0, 'group', 'current', 'code', '180'),
      jsonb_build_object('category', 'Maddi Duran Varlıklar', 'amount', ROUND(v_tangible, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '250'),
      jsonb_build_object('category', 'Maddi Olmayan Duran Varlıklar', 'amount', ROUND(v_intangible, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '260'),
      jsonb_build_object('category', 'Mali Duran Varlıklar', 'amount', ROUND(v_financial, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '240'),
      jsonb_build_object('category', 'Uzun Vadeli Alacaklar', 'amount', ROUND(v_lt_receivables, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '220')
    ),
    'liabilities', jsonb_build_array(
      jsonb_build_object('category', 'Ticari Borçlar', 'amount', ROUND(v_trade_payables, 2), 'prev_amount', 0, 'group', 'current', 'code', '320'),
      jsonb_build_object('category', 'Ödenecek Vergi ve Fonlar', 'amount', ROUND(v_taxes_payable, 2), 'prev_amount', 0, 'group', 'current', 'code', '360'),
      jsonb_build_object('category', 'Diğer Borçlar', 'amount', ROUND(v_other_payables, 2), 'prev_amount', 0, 'group', 'current', 'code', '336'),
      jsonb_build_object('category', 'Alınan Avanslar', 'amount', ROUND(v_advances, 2), 'prev_amount', 0, 'group', 'current', 'code', '340'),
      jsonb_build_object('category', 'Borç ve Gider Karşılıkları', 'amount', ROUND(v_provisions, 2), 'prev_amount', 0, 'group', 'current', 'code', '370'),
      jsonb_build_object('category', 'Banka Kredileri', 'amount', ROUND(v_bank_loans, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '400'),
      jsonb_build_object('category', 'Uzun Vadeli Ticari Borçlar', 'amount', ROUND(v_lt_trade_payables, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '420'),
      jsonb_build_object('category', 'Diğer Uzun Vadeli Borçlar', 'amount', ROUND(v_lt_other_payables, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '436')
    ),
    'equity_breakdown', jsonb_build_object(
      'capital', 0,
      'reserves', 0,
      'profit_reserves', 0,
      'prev_year_profit', 0,
      'current_profit', ROUND(v_current_profit, 2)
    ),
    'subtotals', jsonb_build_object(
      'current_assets', ROUND(v_current_assets, 2),
      'noncurrent_assets', ROUND(v_noncurrent_assets, 2),
      'current_liabilities', ROUND(v_current_liab, 2),
      'noncurrent_liabilities', ROUND(v_noncurrent_liab, 2)
    ),
    'prev_period', jsonb_build_object(
      'total_assets', 0,
      'total_liabilities', 0,
      'equity', 0
    ),
    'ratios', jsonb_build_object(
      'current_ratio', v_current_ratio,
      'quick_ratio', v_quick_ratio,
      'debt_to_equity', v_debt_to_equity,
      'equity_ratio', v_equity_ratio,
      'debt_ratio', v_debt_ratio,
      'working_capital', ROUND(v_working_capital, 2)
    )
  );
END;
$$;

-- ============================================================
-- 10. get_batch_invoice_preview — Online/kapıda ayrımlı
-- ============================================================
CREATE OR REPLACE FUNCTION get_batch_invoice_preview(
  p_sector TEXT,
  p_start_date TIMESTAMPTZ,
  p_end_date TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_platform_kdv_rate NUMERIC;
BEGIN
  v_platform_kdv_rate := get_platform_kdv_rate();

  IF p_sector IN ('food', 'store') THEN
    RETURN COALESCE((
      SELECT jsonb_agg(row_to_json(r)::jsonb)
      FROM (
        SELECT
          o.merchant_id,
          m.business_name AS merchant_name,
          COUNT(*) AS order_count,
          ROUND(SUM(o.total_amount)::NUMERIC, 2) AS total_order_amount,

          -- Online tahsilat (platform tahsil etti)
          ROUND(COALESCE(SUM(CASE
            WHEN o.payment_method IN ('online', 'stripe', 'credit_card') AND o.payment_status = 'paid'
            THEN o.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS online_total,

          -- Kapıda tahsilat (işletme tahsil etti)
          ROUND(COALESCE(SUM(CASE
            WHEN o.payment_method NOT IN ('online', 'stripe', 'credit_card') OR o.payment_status != 'paid'
            THEN o.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS cash_total,

          -- Komisyon hesabı
          ROUND(SUM(o.total_amount * COALESCE(o.commission_rate,
            get_commission_rate(p_sector, o.merchant_id) * 100) / 100)::NUMERIC, 2) AS subtotal,

          -- KDV
          ROUND(SUM(o.total_amount * COALESCE(o.commission_rate,
            get_commission_rate(p_sector, o.merchant_id) * 100) / 100 * v_platform_kdv_rate)::NUMERIC, 2) AS kdv_amount,

          -- Toplam fatura = komisyon + KDV
          ROUND(SUM(o.total_amount * COALESCE(o.commission_rate,
            get_commission_rate(p_sector, o.merchant_id) * 100) / 100 * (1 + v_platform_kdv_rate))::NUMERIC, 2) AS total,

          -- Net transfer = online tahsilat - fatura tutarı
          ROUND(
            COALESCE(SUM(CASE
              WHEN o.payment_method IN ('online', 'stripe', 'credit_card') AND o.payment_status = 'paid'
              THEN o.total_amount ELSE 0 END), 0) -
            SUM(o.total_amount * COALESCE(o.commission_rate,
              get_commission_rate(p_sector, o.merchant_id) * 100) / 100 * (1 + v_platform_kdv_rate))
          ::NUMERIC, 2) AS net_transfer,

          p_sector AS sector
        FROM orders o
        JOIN merchants m ON m.id = o.merchant_id
        WHERE o.status = 'delivered'
          AND o.created_at >= p_start_date
          AND o.created_at <= p_end_date
          AND (
            (p_sector = 'food' AND m.type = 'restaurant') OR
            (p_sector = 'store' AND m.type != 'restaurant')
          )
        GROUP BY o.merchant_id, m.business_name
        ORDER BY m.business_name
      ) r
    ), '[]'::jsonb);

  ELSIF p_sector = 'taxi' THEN
    RETURN COALESCE((
      SELECT jsonb_agg(row_to_json(r)::jsonb)
      FROM (
        SELECT
          t.driver_id AS merchant_id,
          COALESCE(u.first_name || ' ' || u.last_name, 'Sürücü') AS merchant_name,
          COUNT(*) AS order_count,
          ROUND(SUM(t.fare)::NUMERIC, 2) AS total_order_amount,
          ROUND(SUM(t.fare)::NUMERIC, 2) AS online_total,
          0::NUMERIC AS cash_total,
          ROUND(SUM(t.fare * get_commission_rate('taxi'))::NUMERIC, 2) AS subtotal,
          ROUND(SUM(t.fare * get_commission_rate('taxi') * v_platform_kdv_rate)::NUMERIC, 2) AS kdv_amount,
          ROUND(SUM(t.fare * get_commission_rate('taxi') * (1 + v_platform_kdv_rate))::NUMERIC, 2) AS total,
          ROUND(SUM(t.fare) - SUM(t.fare * get_commission_rate('taxi') * (1 + v_platform_kdv_rate))::NUMERIC, 2) AS net_transfer,
          'taxi' AS sector
        FROM taxi_rides t
        LEFT JOIN users u ON u.id = t.driver_id
        WHERE t.status = 'completed'
          AND t.created_at >= p_start_date
          AND t.created_at <= p_end_date
        GROUP BY t.driver_id, u.first_name, u.last_name
        ORDER BY merchant_name
      ) r
    ), '[]'::jsonb);

  ELSIF p_sector = 'rental' THEN
    RETURN COALESCE((
      SELECT jsonb_agg(row_to_json(r)::jsonb)
      FROM (
        SELECT
          rb.company_id AS merchant_id,
          COALESCE(rc.company_name, 'Firma') AS merchant_name,
          COUNT(*) AS order_count,
          ROUND(SUM(rb.total_amount)::NUMERIC, 2) AS total_order_amount,
          ROUND(COALESCE(SUM(CASE
            WHEN rb.payment_method IN ('online', 'stripe', 'credit_card') AND rb.payment_status = 'paid'
            THEN rb.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS online_total,
          ROUND(COALESCE(SUM(CASE
            WHEN rb.payment_method NOT IN ('online', 'stripe', 'credit_card') OR rb.payment_status != 'paid'
            THEN rb.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS cash_total,
          ROUND(SUM(rb.total_amount * get_commission_rate('rental'))::NUMERIC, 2) AS subtotal,
          ROUND(SUM(rb.total_amount * get_commission_rate('rental') * v_platform_kdv_rate)::NUMERIC, 2) AS kdv_amount,
          ROUND(SUM(rb.total_amount * get_commission_rate('rental') * (1 + v_platform_kdv_rate))::NUMERIC, 2) AS total,
          ROUND(
            COALESCE(SUM(CASE
              WHEN rb.payment_method IN ('online', 'stripe', 'credit_card') AND rb.payment_status = 'paid'
              THEN rb.total_amount ELSE 0 END), 0) -
            SUM(rb.total_amount * get_commission_rate('rental') * (1 + v_platform_kdv_rate))
          ::NUMERIC, 2) AS net_transfer,
          'rental' AS sector
        FROM rental_bookings rb
        LEFT JOIN rental_companies rc ON rc.id = rb.company_id
        WHERE rb.status IN ('completed', 'confirmed', 'active')
          AND rb.created_at >= p_start_date
          AND rb.created_at <= p_end_date
        GROUP BY rb.company_id, rc.company_name
        ORDER BY merchant_name
      ) r
    ), '[]'::jsonb);
  ELSE
    RETURN '[]'::jsonb;
  END IF;
END;
$$;

-- ============================================================
-- 11. Permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION get_balance_sheet(DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_profit_loss(DATE, DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_kdv_summary(INT, INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_finance_stats(INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_recent_transactions(INT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_batch_invoice_preview(TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role, anon;

-- ============================================================
-- 12. Mevcut verileri doğru şekilde yeniden oluştur
-- ============================================================
SELECT sync_all_finance_entries();
