-- ============================================================
-- FİNANS MODÜLÜ DÜZELTMELERİ — 2026-03-24
-- ============================================================
-- FIX 1: get_batch_invoice_preview — subtotal/kdv/total TÜM siparişlerin komisyonunu kapsamalı
-- FIX 2: get_income_expense_summary — gelir toplamı KDV hariç (amount) olmalı
-- FIX 3: Taksi batch preview — hardcoded 0'lar düzeltildi
-- ============================================================

-- ============================================================
-- FIX 1 + FIX 3: get_batch_invoice_preview
-- subtotal/kdv_amount/total artık TÜM siparişlerin komisyonunu içerir
-- (online + nakit fark etmez — fatura tüm komisyonu kapsar)
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

          -- Online/Nakit sipariş toplamları (bilgi amaçlı)
          ROUND(COALESCE(SUM(CASE
            WHEN o.payment_method IN ('online', 'stripe', 'credit_card_online')
            THEN o.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS online_total,
          ROUND(COALESCE(SUM(CASE
            WHEN o.payment_method NOT IN ('online', 'stripe', 'credit_card_online')
            THEN o.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS cash_total,

          -- Online/Nakit sipariş sayıları
          COUNT(CASE WHEN o.payment_method IN ('online', 'stripe', 'credit_card_online') THEN 1 END) AS online_order_count,
          COUNT(CASE WHEN o.payment_method NOT IN ('online', 'stripe', 'credit_card_online') THEN 1 END) AS cash_order_count,

          -- Online komisyon (zaten tahsil edildi — bilgi amaçlı)
          ROUND(COALESCE(SUM(CASE
            WHEN o.payment_method IN ('online', 'stripe', 'credit_card_online')
            THEN o.total_amount * COALESCE(o.commission_rate,
              get_commission_rate(p_sector, o.merchant_id) * 100) / 100
            ELSE 0 END), 0)::NUMERIC, 2) AS online_commission,

          -- ═══ DÜZELTME: subtotal artık TÜM siparişlerin komisyonu ═══
          ROUND(SUM(o.total_amount * COALESCE(o.commission_rate,
            get_commission_rate(p_sector, o.merchant_id) * 100) / 100)::NUMERIC, 2) AS subtotal,

          -- ═══ DÜZELTME: kdv_amount artık TÜM komisyonların KDV'si ═══
          ROUND(SUM(o.total_amount * COALESCE(o.commission_rate,
            get_commission_rate(p_sector, o.merchant_id) * 100) / 100 * v_platform_kdv_rate)::NUMERIC, 2) AS kdv_amount,

          -- ═══ DÜZELTME: total artık TÜM komisyon + KDV ═══
          ROUND(SUM(o.total_amount * COALESCE(o.commission_rate,
            get_commission_rate(p_sector, o.merchant_id) * 100) / 100 * (1 + v_platform_kdv_rate))::NUMERIC, 2) AS total,

          -- Net transfer: online tahsilattan işletmeye aktarılacak
          ROUND(
            COALESCE(SUM(CASE
              WHEN o.payment_method IN ('online', 'stripe', 'credit_card_online')
              THEN o.total_amount * (1 - COALESCE(o.commission_rate,
                get_commission_rate(p_sector, o.merchant_id) * 100) / 100 * (1 + v_platform_kdv_rate))
              ELSE 0 END), 0)
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
          COUNT(*) AS online_order_count,
          0::BIGINT AS cash_order_count,
          ROUND(SUM(t.fare * get_commission_rate('taxi'))::NUMERIC, 2) AS online_commission,

          -- ═══ DÜZELTME: Taksi için de gerçek komisyon hesabı ═══
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
            WHEN rb.payment_method IN ('online', 'stripe', 'credit_card_online')
            THEN rb.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS online_total,
          ROUND(COALESCE(SUM(CASE
            WHEN rb.payment_method NOT IN ('online', 'stripe', 'credit_card_online')
            THEN rb.total_amount ELSE 0 END), 0)::NUMERIC, 2) AS cash_total,
          COUNT(CASE WHEN rb.payment_method IN ('online', 'stripe', 'credit_card_online') THEN 1 END) AS online_order_count,
          COUNT(CASE WHEN rb.payment_method NOT IN ('online', 'stripe', 'credit_card_online') THEN 1 END) AS cash_order_count,
          ROUND(COALESCE(SUM(CASE
            WHEN rb.payment_method IN ('online', 'stripe', 'credit_card_online')
            THEN rb.total_amount * get_commission_rate('rental')
            ELSE 0 END), 0)::NUMERIC, 2) AS online_commission,

          -- ═══ DÜZELTME: subtotal TÜM rezervasyonların komisyonu ═══
          ROUND(SUM(rb.total_amount * get_commission_rate('rental'))::NUMERIC, 2) AS subtotal,

          -- ═══ DÜZELTME: kdv_amount TÜM komisyonların KDV'si ═══
          ROUND(SUM(rb.total_amount * get_commission_rate('rental') * v_platform_kdv_rate)::NUMERIC, 2) AS kdv_amount,

          -- ═══ DÜZELTME: total TÜM komisyon + KDV ═══
          ROUND(SUM(rb.total_amount * get_commission_rate('rental') * (1 + v_platform_kdv_rate))::NUMERIC, 2) AS total,

          ROUND(
            COALESCE(SUM(CASE
              WHEN rb.payment_method IN ('online', 'stripe', 'credit_card_online')
              THEN rb.total_amount * (1 - get_commission_rate('rental') * (1 + v_platform_kdv_rate))
              ELSE 0 END), 0)
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
-- FIX 2: get_income_expense_summary
-- Gelir toplamı = amount (komisyon hizmet bedeli, KDV hariç)
-- Gider toplamı = total_amount (KDV dahil, gerçek ödeme)
-- total_kdv ayrı gösteriliyor
-- ============================================================
CREATE OR REPLACE FUNCTION get_income_expense_summary(
  p_start_date DATE,
  p_end_date DATE,
  p_type TEXT DEFAULT NULL,
  p_source TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_search TEXT DEFAULT NULL,
  p_aggregation TEXT DEFAULT 'daily'
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_income   NUMERIC := 0;
  v_total_expense  NUMERIC := 0;
  v_total_kdv      NUMERIC := 0;
  v_pending_count  INT := 0;
  v_pending_amount NUMERIC := 0;
  v_entry_count    INT := 0;
  v_prev_start     DATE;
  v_prev_end       DATE;
  v_day_span       INT;
  v_prev_income    NUMERIC := 0;
  v_prev_expense   NUMERIC := 0;
  v_search_pattern TEXT;
BEGIN
  v_day_span := p_end_date - p_start_date;
  v_prev_end := p_start_date - 1;
  v_prev_start := v_prev_end - v_day_span;

  IF p_search IS NOT NULL AND p_search != '' THEN
    v_search_pattern := '%' || p_search || '%';
  END IF;

  -- ═══ DÜZELTME: income → amount (KDV hariç), expense → total_amount (KDV dahil) ═══
  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0),
    COALESCE(SUM(kdv_amount), 0),
    COUNT(*) FILTER (WHERE payment_status = 'pending'),
    COALESCE(SUM(total_amount) FILTER (WHERE payment_status = 'pending'), 0),
    COUNT(*)
  INTO v_total_income, v_total_expense, v_total_kdv, v_pending_count, v_pending_amount, v_entry_count
  FROM finance_entries
  WHERE created_at::date BETWEEN p_start_date AND p_end_date
    AND (p_type IS NULL OR entry_type = p_type)
    AND (p_source IS NULL OR source_type = p_source)
    AND (p_category IS NULL OR category = p_category)
    AND (p_payment_status IS NULL OR payment_status = p_payment_status)
    AND (v_search_pattern IS NULL OR (
      description ILIKE v_search_pattern OR category ILIKE v_search_pattern OR notes ILIKE v_search_pattern
    ));

  -- ═══ DÜZELTME: önceki dönem de aynı mantık ═══
  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' THEN amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_prev_income, v_prev_expense
  FROM finance_entries
  WHERE created_at::date BETWEEN v_prev_start AND v_prev_end
    AND (p_type IS NULL OR entry_type = p_type)
    AND (p_source IS NULL OR source_type = p_source)
    AND (p_category IS NULL OR category = p_category)
    AND (p_payment_status IS NULL OR payment_status = p_payment_status);

  RETURN json_build_object(
    'total_income',   ROUND(v_total_income, 2),
    'total_expense',  ROUND(v_total_expense, 2),
    'net_balance',    ROUND(v_total_income - v_total_expense, 2),
    'total_kdv',      ROUND(v_total_kdv, 2),
    'pending_count',  v_pending_count,
    'pending_amount', ROUND(v_pending_amount, 2),
    'entry_count',    v_entry_count,
    'prev_income',    ROUND(v_prev_income, 2),
    'prev_expense',   ROUND(v_prev_expense, 2),
    'time_series', (
      SELECT COALESCE(json_agg(json_build_object(
        'date', d, 'income', COALESCE(t.inc, 0), 'expense', COALESCE(t.exp, 0)
      ) ORDER BY d), '[]'::json)
      FROM generate_series(
        p_start_date::timestamp, p_end_date::timestamp,
        CASE p_aggregation
          WHEN 'weekly' THEN '1 week'::interval
          WHEN 'monthly' THEN '1 month'::interval
          ELSE '1 day'::interval
        END
      ) d
      LEFT JOIN (
        SELECT
          CASE p_aggregation
            WHEN 'weekly' THEN date_trunc('week', created_at)::date
            WHEN 'monthly' THEN date_trunc('month', created_at)::date
            ELSE created_at::date
          END AS period,
          -- ═══ DÜZELTME: income → amount ═══
          ROUND(SUM(CASE WHEN entry_type = 'income' THEN amount ELSE 0 END)::NUMERIC, 2) AS inc,
          ROUND(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END)::NUMERIC, 2) AS exp
        FROM finance_entries
        WHERE created_at::date BETWEEN p_start_date AND p_end_date
          AND (p_type IS NULL OR entry_type = p_type)
          AND (p_source IS NULL OR source_type = p_source)
          AND (p_category IS NULL OR category = p_category)
          AND (p_payment_status IS NULL OR payment_status = p_payment_status)
          AND (v_search_pattern IS NULL OR (
            description ILIKE v_search_pattern OR category ILIKE v_search_pattern OR notes ILIKE v_search_pattern
          ))
        GROUP BY period
      ) t ON t.period = d::date
    ),
    'category_breakdown', (
      SELECT COALESCE(json_agg(json_build_object(
        'category', sub.category, 'total', sub.total, 'count', sub.cnt
      ) ORDER BY sub.total DESC), '[]'::json)
      FROM (
        SELECT category, ROUND(SUM(total_amount)::NUMERIC, 2) AS total, COUNT(*) AS cnt
        FROM finance_entries
        WHERE entry_type = 'expense'
          AND created_at::date BETWEEN p_start_date AND p_end_date
          AND (p_source IS NULL OR source_type = p_source)
          AND (p_category IS NULL OR category = p_category)
          AND (p_payment_status IS NULL OR payment_status = p_payment_status)
          AND (v_search_pattern IS NULL OR (
            description ILIKE v_search_pattern OR category ILIKE v_search_pattern OR notes ILIKE v_search_pattern
          ))
        GROUP BY category
      ) sub
    ),
    'source_breakdown', (
      SELECT COALESCE(json_agg(json_build_object(
        'source_type', sub.source_type, 'total', sub.total, 'count', sub.cnt
      ) ORDER BY sub.total DESC), '[]'::json)
      FROM (
        -- ═══ DÜZELTME: kaynak dağılımı da amount kullanmalı ═══
        SELECT source_type, ROUND(SUM(amount)::NUMERIC, 2) AS total, COUNT(*) AS cnt
        FROM finance_entries
        WHERE entry_type = 'income'
          AND created_at::date BETWEEN p_start_date AND p_end_date
          AND (p_source IS NULL OR source_type = p_source)
          AND (p_category IS NULL OR category = p_category)
        GROUP BY source_type
      ) sub
    ),
    'budget_alerts', (
      SELECT COALESCE(json_agg(json_build_object(
        'category', bt.category, 'target', bt.target_amount,
        'actual', COALESCE(act.total, 0),
        'percentage', ROUND(COALESCE(act.total, 0) / bt.target_amount * 100, 1)
      )), '[]'::json)
      FROM budget_targets bt
      LEFT JOIN (
        SELECT category, SUM(total_amount) AS total
        FROM finance_entries
        WHERE entry_type = 'expense'
          AND created_at::date BETWEEN
            date_trunc('month', CURRENT_DATE)::date
            AND (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date
        GROUP BY category
      ) act ON act.category = bt.category
      WHERE bt.period_type = 'monthly'
        AND bt.year = EXTRACT(YEAR FROM CURRENT_DATE)::INT
        AND (bt.month IS NULL OR bt.month = EXTRACT(MONTH FROM CURRENT_DATE)::INT)
        AND bt.entry_type = 'expense'
        AND COALESCE(act.total, 0) / bt.target_amount * 100 >= bt.alert_threshold
    )
  );
END;
$$;

-- ============================================================
-- İZİNLER
-- ============================================================
GRANT EXECUTE ON FUNCTION get_batch_invoice_preview(TEXT, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_income_expense_summary(DATE, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
