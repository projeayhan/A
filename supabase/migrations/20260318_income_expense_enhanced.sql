-- ============================================================
-- Gelir/Gider Ekranı - Enhanced Backend
-- Depends on: finance_entries, expense_categories, budget_targets
-- ============================================================

-- ============================================================
-- 1. finance_entries tablosuna yeni sütunlar
-- ============================================================
ALTER TABLE finance_entries ADD COLUMN IF NOT EXISTS tags TEXT[];
ALTER TABLE finance_entries ADD COLUMN IF NOT EXISTS recurring_entry_id UUID;
ALTER TABLE finance_entries ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_finance_entries_tags ON finance_entries USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_finance_entries_recurring ON finance_entries(recurring_entry_id);

-- ============================================================
-- 2. recurring_entries — tekrarlayan gelir/gider tanımları
-- ============================================================
CREATE TABLE IF NOT EXISTS recurring_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_type VARCHAR(10) NOT NULL CHECK (entry_type IN ('income', 'expense')),
  category VARCHAR(100) NOT NULL,
  subcategory VARCHAR(100),
  description TEXT,
  amount DECIMAL(15,2) NOT NULL,
  kdv_rate DECIMAL(5,2) NOT NULL DEFAULT 20.00,
  source_type VARCHAR(20) DEFAULT 'manual',
  payment_method VARCHAR(50),
  tax_deductible BOOLEAN DEFAULT FALSE,
  frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('weekly', 'monthly', 'quarterly', 'yearly')),
  next_run_date DATE NOT NULL,
  last_run_date DATE,
  day_of_month INT,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recurring_entries_active ON recurring_entries(is_active, next_run_date);
CREATE INDEX idx_recurring_entries_type ON recurring_entries(entry_type);

ALTER TABLE recurring_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage recurring_entries" ON recurring_entries
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- ============================================================
-- 3. entry_attachments — belge ekleri
-- ============================================================
CREATE TABLE IF NOT EXISTS entry_attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  finance_entry_id UUID NOT NULL REFERENCES finance_entries(id) ON DELETE CASCADE,
  file_name VARCHAR(255) NOT NULL,
  file_url TEXT NOT NULL,
  file_type VARCHAR(50),
  file_size INT,
  uploaded_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_entry_attachments_entry ON entry_attachments(finance_entry_id);

ALTER TABLE entry_attachments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage entry_attachments" ON entry_attachments
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- ============================================================
-- 4. budget_targets — bütçe hedefleri
-- ============================================================
CREATE TABLE IF NOT EXISTS budget_targets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  category VARCHAR(100) NOT NULL,
  entry_type VARCHAR(10) NOT NULL CHECK (entry_type IN ('income', 'expense')),
  target_amount DECIMAL(15,2) NOT NULL,
  period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('monthly', 'quarterly', 'yearly')),
  year INT NOT NULL,
  month INT,
  quarter INT,
  alert_threshold DECIMAL(5,2) NOT NULL DEFAULT 80.00,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(category, entry_type, period_type, year, month, quarter)
);

CREATE INDEX idx_budget_targets_lookup ON budget_targets(category, entry_type, year);

ALTER TABLE budget_targets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage budget_targets" ON budget_targets
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- ============================================================
-- 5. RPC: get_income_expense_summary
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
  v_prev_kdv       NUMERIC := 0;
  v_prev_pending_count  INT := 0;
  v_prev_pending_amount NUMERIC := 0;
  v_prev_entry_count    INT := 0;
  v_search_pattern TEXT;
BEGIN
  -- Önceki dönem hesapla (trend karşılaştırma)
  v_day_span := p_end_date - p_start_date;
  v_prev_end := p_start_date - 1;
  v_prev_start := v_prev_end - v_day_span;

  -- Search pattern
  IF p_search IS NOT NULL AND p_search != '' THEN
    v_search_pattern := '%' || p_search || '%';
  END IF;

  -- ===== CURRENT PERIOD SUMMARY =====
  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0),
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
      description ILIKE v_search_pattern
      OR category ILIKE v_search_pattern
      OR notes ILIKE v_search_pattern
    ));

  -- ===== PREVIOUS PERIOD SUMMARY =====
  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0),
    COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0),
    COALESCE(SUM(kdv_amount), 0),
    COUNT(*) FILTER (WHERE payment_status = 'pending'),
    COALESCE(SUM(total_amount) FILTER (WHERE payment_status = 'pending'), 0),
    COUNT(*)
  INTO v_prev_income, v_prev_expense, v_prev_kdv, v_prev_pending_count, v_prev_pending_amount, v_prev_entry_count
  FROM finance_entries
  WHERE created_at::date BETWEEN v_prev_start AND v_prev_end
    AND (p_type IS NULL OR entry_type = p_type)
    AND (p_source IS NULL OR source_type = p_source)
    AND (p_category IS NULL OR category = p_category)
    AND (p_payment_status IS NULL OR payment_status = p_payment_status)
    AND (v_search_pattern IS NULL OR (
      description ILIKE v_search_pattern
      OR category ILIKE v_search_pattern
      OR notes ILIKE v_search_pattern
    ));

  RETURN json_build_object(
    'summary', json_build_object(
      'total_income', ROUND(v_total_income, 2),
      'total_expense', ROUND(v_total_expense, 2),
      'net_balance', ROUND(v_total_income - v_total_expense, 2),
      'total_kdv', ROUND(v_total_kdv, 2),
      'pending_count', v_pending_count,
      'pending_amount', ROUND(v_pending_amount, 2),
      'entry_count', v_entry_count
    ),
    'prev_summary', json_build_object(
      'total_income', ROUND(v_prev_income, 2),
      'total_expense', ROUND(v_prev_expense, 2),
      'net_balance', ROUND(v_prev_income - v_prev_expense, 2),
      'total_kdv', ROUND(v_prev_kdv, 2),
      'pending_count', v_prev_pending_count,
      'pending_amount', ROUND(v_prev_pending_amount, 2),
      'entry_count', v_prev_entry_count
    ),
    'time_series', (
      SELECT COALESCE(json_agg(json_build_object(
        'date', d,
        'income', COALESCE(t.inc, 0),
        'expense', COALESCE(t.exp, 0)
      ) ORDER BY d), '[]'::json)
      FROM generate_series(
        p_start_date::timestamp,
        p_end_date::timestamp,
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
          ROUND(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END)::NUMERIC, 2) AS inc,
          ROUND(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END)::NUMERIC, 2) AS exp
        FROM finance_entries
        WHERE created_at::date BETWEEN p_start_date AND p_end_date
          AND (p_type IS NULL OR entry_type = p_type)
          AND (p_source IS NULL OR source_type = p_source)
          AND (p_category IS NULL OR category = p_category)
          AND (p_payment_status IS NULL OR payment_status = p_payment_status)
          AND (v_search_pattern IS NULL OR (
            description ILIKE v_search_pattern
            OR category ILIKE v_search_pattern
            OR notes ILIKE v_search_pattern
          ))
        GROUP BY period
      ) t ON t.period = d::date
    ),
    'category_breakdown', (
      SELECT COALESCE(json_agg(json_build_object(
        'category', sub.category,
        'total', sub.total,
        'count', sub.cnt
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
            description ILIKE v_search_pattern
            OR category ILIKE v_search_pattern
            OR notes ILIKE v_search_pattern
          ))
        GROUP BY category
      ) sub
    ),
    'source_breakdown', (
      SELECT COALESCE(json_agg(json_build_object(
        'source_type', sub.source_type,
        'total', sub.total,
        'count', sub.cnt
      ) ORDER BY sub.total DESC), '[]'::json)
      FROM (
        SELECT source_type, ROUND(SUM(total_amount)::NUMERIC, 2) AS total, COUNT(*) AS cnt
        FROM finance_entries
        WHERE entry_type = 'income'
          AND created_at::date BETWEEN p_start_date AND p_end_date
          AND (p_type IS NULL OR entry_type = p_type)
          AND (p_source IS NULL OR source_type = p_source)
          AND (p_category IS NULL OR category = p_category)
          AND (p_payment_status IS NULL OR payment_status = p_payment_status)
          AND (v_search_pattern IS NULL OR (
            description ILIKE v_search_pattern
            OR category ILIKE v_search_pattern
            OR notes ILIKE v_search_pattern
          ))
        GROUP BY source_type
      ) sub
    ),
    'budget_alerts', (
      SELECT COALESCE(json_agg(json_build_object(
        'category', bt.category,
        'target', bt.target_amount,
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
-- 6. RPC: execute_recurring_entries
-- ============================================================
CREATE OR REPLACE FUNCTION execute_recurring_entries()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rec RECORD;
  v_count INT := 0;
  v_total NUMERIC := 0;
  v_entries JSON := '[]'::json;
  v_entry_id UUID;
  v_kdv_amount NUMERIC;
  v_total_amount NUMERIC;
  v_results JSON[] := '{}';
BEGIN
  FOR v_rec IN
    SELECT * FROM recurring_entries
    WHERE is_active = TRUE AND next_run_date <= CURRENT_DATE
  LOOP
    -- KDV hesapla
    v_kdv_amount := ROUND(v_rec.amount * v_rec.kdv_rate / 100, 2);
    v_total_amount := v_rec.amount + v_kdv_amount;

    -- finance_entries'e kayıt ekle
    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount,
      kdv_rate, kdv_amount, total_amount, source_type,
      payment_method, tax_deductible, recurring_entry_id,
      payment_status, created_by
    ) VALUES (
      v_rec.entry_type, v_rec.category, v_rec.subcategory, v_rec.description, v_rec.amount,
      v_rec.kdv_rate, v_kdv_amount, v_total_amount, v_rec.source_type,
      v_rec.payment_method, v_rec.tax_deductible, v_rec.id,
      'pending', v_rec.created_by
    ) RETURNING id INTO v_entry_id;

    -- recurring_entries güncelle
    UPDATE recurring_entries
    SET
      last_run_date = CURRENT_DATE,
      next_run_date = CASE frequency
        WHEN 'weekly' THEN next_run_date + INTERVAL '7 days'
        WHEN 'monthly' THEN next_run_date + INTERVAL '1 month'
        WHEN 'quarterly' THEN next_run_date + INTERVAL '3 months'
        WHEN 'yearly' THEN next_run_date + INTERVAL '1 year'
      END
    WHERE id = v_rec.id;

    v_count := v_count + 1;
    v_total := v_total + v_total_amount;
    v_results := array_append(v_results, json_build_object(
      'id', v_entry_id,
      'description', v_rec.description,
      'amount', v_total_amount
    ));
  END LOOP;

  RETURN json_build_object(
    'executed_count', v_count,
    'total_amount', ROUND(v_total, 2),
    'entries', to_json(v_results)
  );
END;
$$;

-- ============================================================
-- 7. RPC: get_expense_categories_tree
-- ============================================================
CREATE OR REPLACE FUNCTION get_expense_categories_tree()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_month_start DATE := date_trunc('month', CURRENT_DATE)::date;
  v_month_end DATE := (date_trunc('month', CURRENT_DATE) + INTERVAL '1 month' - INTERVAL '1 day')::date;
BEGIN
  RETURN (
    WITH monthly_totals AS (
      SELECT category, COALESCE(SUM(total_amount), 0) AS total
      FROM finance_entries
      WHERE entry_type = 'expense'
        AND created_at::date BETWEEN v_month_start AND v_month_end
      GROUP BY category
    ),
    categories_with_totals AS (
      SELECT
        ec.id,
        ec.name,
        ec.parent_id,
        ec.is_tax_deductible,
        ec.sort_order,
        COALESCE(mt.total, 0) AS current_month_total
      FROM expense_categories ec
      LEFT JOIN monthly_totals mt ON mt.category = ec.name
    ),
    children AS (
      SELECT
        c.parent_id,
        json_agg(json_build_object(
          'id', c.id,
          'name', c.name,
          'parent_id', c.parent_id,
          'is_tax_deductible', c.is_tax_deductible,
          'current_month_total', ROUND(c.current_month_total::NUMERIC, 2),
          'children', '[]'::json
        ) ORDER BY c.sort_order) AS child_list
      FROM categories_with_totals c
      WHERE c.parent_id IS NOT NULL
      GROUP BY c.parent_id
    )
    SELECT COALESCE(json_agg(json_build_object(
      'id', p.id,
      'name', p.name,
      'parent_id', p.parent_id,
      'is_tax_deductible', p.is_tax_deductible,
      'current_month_total', ROUND(p.current_month_total::NUMERIC, 2),
      'children', COALESCE(ch.child_list, '[]'::json)
    ) ORDER BY p.sort_order), '[]'::json)
    FROM categories_with_totals p
    LEFT JOIN children ch ON ch.parent_id = p.id
    WHERE p.parent_id IS NULL
  );
END;
$$;

-- ============================================================
-- 8. Grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION get_income_expense_summary(DATE, DATE, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION execute_recurring_entries() TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_expense_categories_tree() TO authenticated, service_role, anon;
