-- Finance RPC Functions
-- get_finance_stats(p_days INT) → FinanceStats JSON
-- get_recent_transactions(p_limit INT) → Transaction[] JSON

DROP FUNCTION IF EXISTS get_finance_stats(INT);
DROP FUNCTION IF EXISTS get_recent_transactions(INT);

-- RPC 1: get_finance_stats
CREATE OR REPLACE FUNCTION get_finance_stats(p_days INT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start         TIMESTAMPTZ := now() - (p_days * INTERVAL '1 day');
  v_prev_start    TIMESTAMPTZ := now() - (2 * p_days * INTERVAL '1 day');
  v_prev_end      TIMESTAMPTZ := now() - (p_days * INTERVAL '1 day');

  v_food_rev      NUMERIC := 0;
  v_store_rev     NUMERIC := 0;
  v_taxi_rev      NUMERIC := 0;
  v_rental_rev    NUMERIC := 0;
  v_total_rev     NUMERIC := 0;
  v_commission    NUMERIC := 0;

  v_prev_food     NUMERIC := 0;
  v_prev_store    NUMERIC := 0;
  v_prev_taxi     NUMERIC := 0;
  v_prev_rental   NUMERIC := 0;
  v_prev_total    NUMERIC := 0;
  v_prev_comm     NUMERIC := 0;

  v_partner_pay   NUMERIC := 0;
  v_prev_partner  NUMERIC := 0;
  v_pending       NUMERIC := 0;

  v_daily_bucket  INT;
BEGIN
  -- Current period: food orders (restaurant type merchants)
  SELECT COALESCE(SUM(o.total_amount), 0) INTO v_food_rev
  FROM orders o
  JOIN merchants m ON m.id = o.merchant_id
  WHERE o.status = 'delivered'
    AND o.created_at >= v_start AND o.created_at <= now()
    AND m.type = 'restaurant';

  -- Current period: store orders (market + store type merchants)
  SELECT COALESCE(SUM(o.total_amount), 0) INTO v_store_rev
  FROM orders o
  JOIN merchants m ON m.id = o.merchant_id
  WHERE o.status = 'delivered'
    AND o.created_at >= v_start AND o.created_at <= now()
    AND m.type IN ('market', 'store');

  -- Current period: taxi
  SELECT COALESCE(SUM(fare), 0) INTO v_taxi_rev
  FROM taxi_rides
  WHERE status = 'completed'
    AND created_at >= v_start AND created_at <= now();

  -- Current period: rental invoices
  SELECT COALESCE(SUM(total), 0) INTO v_rental_rev
  FROM invoices
  WHERE source_type = 'rental'
    AND created_at >= v_start AND created_at <= now();

  -- Previous period: food
  SELECT COALESCE(SUM(o.total_amount), 0) INTO v_prev_food
  FROM orders o
  JOIN merchants m ON m.id = o.merchant_id
  WHERE o.status = 'delivered'
    AND o.created_at >= v_prev_start AND o.created_at < v_prev_end
    AND m.type = 'restaurant';

  -- Previous period: store
  SELECT COALESCE(SUM(o.total_amount), 0) INTO v_prev_store
  FROM orders o
  JOIN merchants m ON m.id = o.merchant_id
  WHERE o.status = 'delivered'
    AND o.created_at >= v_prev_start AND o.created_at < v_prev_end
    AND m.type IN ('market', 'store');

  SELECT COALESCE(SUM(fare), 0) INTO v_prev_taxi
  FROM taxi_rides
  WHERE status = 'completed'
    AND created_at >= v_prev_start AND created_at < v_prev_end;

  SELECT COALESCE(SUM(total), 0) INTO v_prev_rental
  FROM invoices
  WHERE source_type = 'rental'
    AND created_at >= v_prev_start AND created_at < v_prev_end;

  v_total_rev   := v_food_rev + v_store_rev + v_taxi_rev + v_rental_rev;
  v_prev_total  := v_prev_food + v_prev_store + v_prev_taxi + v_prev_rental;

  -- Commission: food/store 15%, taxi 20%, rental 15%
  v_commission  := (v_food_rev + v_store_rev) * 0.15 + v_taxi_rev * 0.20 + v_rental_rev * 0.15;
  v_prev_comm   := (v_prev_food + v_prev_store) * 0.15 + v_prev_taxi * 0.20 + v_prev_rental * 0.15;

  -- Partner payments: taxi drivers get 80% of taxi revenue
  v_partner_pay  := v_taxi_rev * 0.80;
  v_prev_partner := v_prev_taxi * 0.80;

  -- Pending payments: invoices with status='issued'
  SELECT COALESCE(SUM(total), 0) INTO v_pending
  FROM invoices
  WHERE status = 'issued';

  v_daily_bucket := CASE WHEN p_days <= 7 THEN 7 ELSE 30 END;

  RETURN json_build_object(
    'summary', json_build_object(
      'total_revenue',             ROUND(v_total_rev, 2),
      'prev_total_revenue',        ROUND(v_prev_total, 2),
      'commission_revenue',        ROUND(v_commission, 2),
      'prev_commission_revenue',   ROUND(v_prev_comm, 2),
      'partner_payments',          ROUND(v_partner_pay, 2),
      'prev_partner_payments',     ROUND(v_prev_partner, 2),
      'pending_payments',          ROUND(v_pending, 2)
    ),
    'revenue_distribution', json_build_object(
      'food_revenue',    ROUND(v_food_rev, 2),
      'store_revenue',   ROUND(v_store_rev, 2),
      'taxi_revenue',    ROUND(v_taxi_rev, 2),
      'rental_revenue',  ROUND(v_rental_rev, 2)
    ),
    'monthly_revenue', (
      WITH month_series AS (
        SELECT
          gs AS offset_months,
          date_trunc('month', now() - ((gs - 1) * INTERVAL '1 month')) AS mstart,
          date_trunc('month', now() - ((gs - 1) * INTERVAL '1 month')) + INTERVAL '1 month' AS mend,
          (12 - gs + 1) AS month_num,
          EXTRACT(MONTH FROM (now() - ((gs - 1) * INTERVAL '1 month')))::INT AS cal_month
        FROM generate_series(1, 12) AS gs
      ),
      food_store_agg AS (
        SELECT
          ms.month_num,
          ms.cal_month,
          COALESCE(SUM(o.total_amount), 0) AS rev
        FROM month_series ms
        LEFT JOIN orders o
          ON o.status = 'delivered'
          AND o.created_at >= ms.mstart
          AND o.created_at < ms.mend
        GROUP BY ms.month_num, ms.cal_month
      ),
      taxi_agg AS (
        SELECT
          ms.month_num,
          ms.cal_month,
          COALESCE(SUM(tr.fare), 0) AS rev
        FROM month_series ms
        LEFT JOIN taxi_rides tr
          ON tr.status = 'completed'
          AND tr.created_at >= ms.mstart
          AND tr.created_at < ms.mend
        GROUP BY ms.month_num, ms.cal_month
      ),
      combined AS (
        SELECT
          f.month_num,
          f.cal_month,
          f.rev + t.rev AS total_rev,
          f.rev * 0.15 + t.rev * 0.20 AS total_comm
        FROM food_store_agg f
        JOIN taxi_agg t USING (month_num, cal_month)
      )
      SELECT json_agg(
        json_build_object(
          'month_num',  c.month_num,
          'month_name', (ARRAY['Oca','Şub','Mar','Nis','May','Haz','Tem','Ağu','Eyl','Eki','Kas','Ara'])[c.cal_month],
          'revenue',    ROUND(c.total_rev::NUMERIC, 2),
          'commission', ROUND(c.total_comm::NUMERIC, 2)
        ) ORDER BY c.month_num
      )
      FROM combined c
    ),
    'daily_revenue', (
      WITH day_series AS (
        SELECT
          gs AS offset_days,
          date_trunc('day', now() - ((gs - 1) * INTERVAL '1 day')) AS dstart,
          date_trunc('day', now() - ((gs - 1) * INTERVAL '1 day')) + INTERVAL '1 day' AS dend,
          (v_daily_bucket - gs + 1) AS day_num,
          EXTRACT(DOW FROM (now() - ((gs - 1) * INTERVAL '1 day')))::INT AS dow
        FROM generate_series(1, v_daily_bucket) AS gs
      ),
      food_agg AS (
        SELECT
          ds.day_num,
          ds.dow,
          COALESCE(SUM(o.total_amount), 0) AS rev
        FROM day_series ds
        LEFT JOIN orders o
          ON o.status = 'delivered'
          AND o.created_at >= ds.dstart
          AND o.created_at < ds.dend
        GROUP BY ds.day_num, ds.dow
      ),
      taxi_agg AS (
        SELECT
          ds.day_num,
          ds.dow,
          COALESCE(SUM(tr.fare), 0) AS rev
        FROM day_series ds
        LEFT JOIN taxi_rides tr
          ON tr.status = 'completed'
          AND tr.created_at >= ds.dstart
          AND tr.created_at < ds.dend
        GROUP BY ds.day_num, ds.dow
      ),
      combined AS (
        SELECT
          f.day_num,
          f.dow,
          f.rev + t.rev AS total_rev
        FROM food_agg f
        JOIN taxi_agg t USING (day_num, dow)
      )
      SELECT json_agg(
        json_build_object(
          'day_num',  c.day_num,
          'day_name', (ARRAY['Paz','Pzt','Sal','Çar','Per','Cum','Cmt'])[c.dow + 1],
          'revenue',  ROUND(c.total_rev::NUMERIC, 2)
        ) ORDER BY c.day_num
      )
      FROM combined c
    )
  );
END;
$$;

-- RPC 2: get_recent_transactions
CREATE FUNCTION get_recent_transactions(p_limit INT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT json_agg(t)
    FROM (
      SELECT
        id::TEXT                     AS transaction_id,
        'income'::TEXT               AS type,
        CASE source_type
          WHEN 'taxi'   THEN 'Taksi Siparişi #'  || id::TEXT
          WHEN 'food'   THEN 'Yemek Siparişi #'  || id::TEXT
          WHEN 'store'  THEN 'Market Siparişi #' || id::TEXT
          WHEN 'rental' THEN 'Kiralama #'         || id::TEXT
          ELSE               'Sipariş #'          || id::TEXT
        END                          AS description,
        COALESCE(total, 0)::NUMERIC  AS amount,
        created_at::TEXT             AS date,
        source_type                  AS source
      FROM invoices
      ORDER BY created_at DESC
      LIMIT p_limit
    ) t
  );
END;
$$;

-- Permissions
GRANT EXECUTE ON FUNCTION get_finance_stats(INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_recent_transactions(INT) TO authenticated, service_role, anon;
