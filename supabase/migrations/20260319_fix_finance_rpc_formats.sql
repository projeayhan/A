-- ============================================================
-- Fix all finance RPC functions to match frontend JSON format
-- Replaces: get_balance_sheet, get_aging_report, get_profit_loss, get_kdv_summary
-- ============================================================

-- ============================================================
-- 1. get_balance_sheet(p_date DATE) → JSONB
--    Frontend expects:
--      total_assets, total_liabilities, equity (numbers)
--      assets: [{category, amount, prev_amount, group, code}]
--      liabilities: [{category, amount, prev_amount, group, code}]
--      equity_breakdown: {capital, reserves, profit_reserves, prev_year_profit, current_profit}
--      subtotals: {current_assets, noncurrent_assets, current_liabilities, noncurrent_liabilities}
--      prev_period: {total_assets, total_liabilities, equity}
--      ratios: {current_ratio, quick_ratio, debt_to_equity, equity_ratio, debt_ratio, working_capital}
-- ============================================================
CREATE OR REPLACE FUNCTION get_balance_sheet(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  -- Current period values
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
  -- Totals
  v_current_assets    NUMERIC := 0;
  v_noncurrent_assets NUMERIC := 0;
  v_total_assets      NUMERIC := 0;
  v_current_liab      NUMERIC := 0;
  v_noncurrent_liab   NUMERIC := 0;
  v_total_liab        NUMERIC := 0;
  v_equity            NUMERIC := 0;
  -- Equity breakdown
  v_capital           NUMERIC := 0;
  v_reserves          NUMERIC := 0;
  v_profit_reserves   NUMERIC := 0;
  v_prev_year_profit  NUMERIC := 0;
  v_current_profit    NUMERIC := 0;
  -- Previous period
  v_prev_date         DATE;
  v_prev_total_assets NUMERIC := 0;
  v_prev_total_liab   NUMERIC := 0;
  v_prev_equity       NUMERIC := 0;
  -- Ratios
  v_current_ratio     NUMERIC := 0;
  v_quick_ratio       NUMERIC := 0;
  v_debt_to_equity    NUMERIC := 0;
  v_equity_ratio      NUMERIC := 0;
  v_debt_ratio        NUMERIC := 0;
  v_working_capital   NUMERIC := 0;
  -- Previous period item amounts
  v_prev_cash         NUMERIC := 0;
  v_prev_bank         NUMERIC := 0;
  v_prev_recv         NUMERIC := 0;
  v_prev_other_recv   NUMERIC := 0;
  v_prev_inventory    NUMERIC := 0;
  v_prev_prepaid      NUMERIC := 0;
  v_prev_lt_recv      NUMERIC := 0;
  v_prev_tangible     NUMERIC := 0;
  v_prev_intangible   NUMERIC := 0;
  v_prev_financial    NUMERIC := 0;
  v_prev_trade_pay    NUMERIC := 0;
  v_prev_other_pay    NUMERIC := 0;
  v_prev_advances     NUMERIC := 0;
  v_prev_taxes        NUMERIC := 0;
  v_prev_provisions   NUMERIC := 0;
  v_prev_bank_loans   NUMERIC := 0;
  v_prev_lt_trade_pay NUMERIC := 0;
  v_prev_lt_other_pay NUMERIC := 0;
BEGIN
  -- Previous period = one month earlier
  v_prev_date := p_date - INTERVAL '1 month';

  -- ========== CURRENT PERIOD ==========

  -- 100: Kasa/Nakit = paid income - paid expense (cash only)
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_cash
  FROM finance_entries
  WHERE payment_status = 'paid'
    AND payment_method IN ('cash', 'nakit')
    AND created_at::date <= p_date;

  -- 102: Banka Hesapları = all paid except cash (including online, card, bank_transfer, etc.)
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_bank
  FROM finance_entries
  WHERE payment_status = 'paid'
    AND (payment_method IS NULL OR payment_method NOT IN ('cash', 'nakit'))
    AND created_at::date <= p_date;

  -- 120: Ticari Alacaklar = pending/overdue income
  SELECT COALESCE(SUM(total_amount), 0) INTO v_receivables
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status IN ('pending', 'overdue')
    AND created_at::date <= p_date;

  -- 136: Diğer Alacaklar (from tax deductible income that's pending)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_other_receivables
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND payment_status = 'paid'
    AND created_at::date <= p_date;

  -- 150: Stoklar = 0 (no inventory tracking in current system)
  v_inventory := 0;

  -- 180: Peşin Ödenmiş Giderler = paid expenses with due_date in future
  SELECT COALESCE(SUM(total_amount), 0) INTO v_prepaid
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status = 'paid'
    AND due_date IS NOT NULL
    AND due_date > p_date
    AND created_at::date <= p_date;

  -- 220: Uzun Vadeli Alacaklar = income receivables with due_date > 1 year
  SELECT COALESCE(SUM(total_amount), 0) INTO v_lt_receivables
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status IN ('pending', 'overdue')
    AND due_date IS NOT NULL
    AND due_date > (p_date + INTERVAL '1 year')
    AND created_at::date <= p_date;

  -- Subtract long-term from short-term receivables
  v_receivables := v_receivables - v_lt_receivables;

  -- Non-current assets (250, 260, 240) - approximate from large paid expenses
  -- categorized as 'equipment', 'software', 'investment' etc.
  SELECT COALESCE(SUM(total_amount), 0) INTO v_tangible
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status = 'paid'
    AND category IN ('equipment', 'ekipman', 'demirbaş', 'araç', 'vehicle', 'furniture', 'mobilya')
    AND created_at::date <= p_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_intangible
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status = 'paid'
    AND category IN ('software', 'yazılım', 'lisans', 'license', 'patent', 'marka')
    AND created_at::date <= p_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_financial
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status = 'paid'
    AND category IN ('investment', 'yatırım', 'hisse', 'securities')
    AND created_at::date <= p_date;

  -- 320: Ticari Borçlar = pending/overdue expense (short-term)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_trade_payables
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status IN ('pending', 'overdue')
    AND (due_date IS NULL OR due_date <= (p_date + INTERVAL '1 year'))
    AND created_at::date <= p_date;

  -- 360: Ödenecek Vergi = KDV from paid income
  SELECT COALESCE(SUM(kdv_amount), 0) - COALESCE(
    (SELECT SUM(kdv_amount) FROM finance_entries WHERE entry_type = 'expense' AND tax_deductible = TRUE AND payment_status = 'paid' AND created_at::date <= p_date), 0)
  INTO v_taxes_payable
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status = 'paid'
    AND created_at::date <= p_date;

  IF v_taxes_payable < 0 THEN v_taxes_payable := 0; END IF;

  -- 336: Diğer Borçlar
  v_other_payables := 0;

  -- 340: Alınan Avanslar = paid income with future service date
  v_advances := 0;

  -- 370: Borç ve Gider Karşılıkları
  v_provisions := 0;

  -- 400: Banka Kredileri (long-term)
  v_bank_loans := 0;

  -- 420: Uzun Vadeli Ticari Borçlar
  SELECT COALESCE(SUM(total_amount), 0) INTO v_lt_trade_payables
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status IN ('pending', 'overdue')
    AND due_date IS NOT NULL
    AND due_date > (p_date + INTERVAL '1 year')
    AND created_at::date <= p_date;

  -- Subtract long-term from short-term payables
  v_trade_payables := v_trade_payables - v_lt_trade_payables;

  v_lt_other_payables := 0;

  -- ========== COMPUTE TOTALS ==========
  v_current_assets := GREATEST(v_cash, 0) + GREATEST(v_bank, 0) + v_receivables + v_other_receivables + v_inventory + v_prepaid;
  v_noncurrent_assets := v_lt_receivables + v_tangible + v_intangible + v_financial;
  v_total_assets := v_current_assets + v_noncurrent_assets;

  v_current_liab := v_trade_payables + v_other_payables + v_advances + v_taxes_payable + v_provisions;
  v_noncurrent_liab := v_bank_loans + v_lt_trade_payables + v_lt_other_payables;
  v_total_liab := v_current_liab + v_noncurrent_liab;

  v_equity := v_total_assets - v_total_liab;

  -- Equity breakdown
  v_current_profit := v_equity; -- Simplified: all equity = current period result
  -- For a real system we'd track capital contributions separately

  -- ========== PREVIOUS PERIOD ==========
  -- Simplified: compute totals for prev_date
  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' AND payment_status = 'paid' THEN total_amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN entry_type = 'expense' AND payment_status = 'paid' THEN total_amount ELSE 0 END), 0)
  INTO v_prev_cash
  FROM finance_entries
  WHERE created_at::date <= v_prev_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_prev_recv
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status IN ('pending', 'overdue')
    AND created_at::date <= v_prev_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_prev_trade_pay
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND payment_status IN ('pending', 'overdue')
    AND created_at::date <= v_prev_date;

  v_prev_total_assets := GREATEST(v_prev_cash, 0) + v_prev_recv;
  v_prev_total_liab := v_prev_trade_pay;
  v_prev_equity := v_prev_total_assets - v_prev_total_liab;

  -- Previous item amounts (simplified)
  v_prev_bank := v_prev_cash;
  v_prev_cash := 0;

  -- ========== RATIOS ==========
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

  -- ========== BUILD RESULT ==========
  RETURN jsonb_build_object(
    'total_assets', ROUND(v_total_assets, 2),
    'total_liabilities', ROUND(v_total_liab, 2),
    'equity', ROUND(v_equity, 2),
    'assets', jsonb_build_array(
      jsonb_build_object('category', 'Kasa / Nakit',                'amount', ROUND(GREATEST(v_cash, 0), 2),  'prev_amount', ROUND(GREATEST(v_prev_cash, 0), 2),  'group', 'current', 'code', '100'),
      jsonb_build_object('category', 'Banka Hesapları',             'amount', ROUND(GREATEST(v_bank, 0), 2),  'prev_amount', ROUND(GREATEST(v_prev_bank, 0), 2),  'group', 'current', 'code', '102'),
      jsonb_build_object('category', 'Ticari Alacaklar',            'amount', ROUND(v_receivables, 2),         'prev_amount', ROUND(v_prev_recv, 2),               'group', 'current', 'code', '120'),
      jsonb_build_object('category', 'Diğer Alacaklar',             'amount', ROUND(v_other_receivables, 2),   'prev_amount', 0,                                   'group', 'current', 'code', '136'),
      jsonb_build_object('category', 'Stoklar',                     'amount', ROUND(v_inventory, 2),           'prev_amount', 0,                                   'group', 'current', 'code', '150'),
      jsonb_build_object('category', 'Peşin Ödenmiş Giderler',      'amount', ROUND(v_prepaid, 2),             'prev_amount', 0,                                   'group', 'current', 'code', '180'),
      jsonb_build_object('category', 'Maddi Duran Varlıklar',       'amount', ROUND(v_tangible, 2),            'prev_amount', 0,                                   'group', 'noncurrent', 'code', '250'),
      jsonb_build_object('category', 'Maddi Olmayan Duran Varlıklar','amount', ROUND(v_intangible, 2),         'prev_amount', 0,                                   'group', 'noncurrent', 'code', '260'),
      jsonb_build_object('category', 'Mali Duran Varlıklar',        'amount', ROUND(v_financial, 2),           'prev_amount', 0,                                   'group', 'noncurrent', 'code', '240'),
      jsonb_build_object('category', 'Uzun Vadeli Alacaklar',       'amount', ROUND(v_lt_receivables, 2),      'prev_amount', 0,                                   'group', 'noncurrent', 'code', '220')
    ),
    'liabilities', jsonb_build_array(
      jsonb_build_object('category', 'Ticari Borçlar',              'amount', ROUND(v_trade_payables, 2),      'prev_amount', ROUND(v_prev_trade_pay, 2),          'group', 'current', 'code', '320'),
      jsonb_build_object('category', 'Ödenecek Vergi ve Fonlar',    'amount', ROUND(v_taxes_payable, 2),       'prev_amount', 0,                                   'group', 'current', 'code', '360'),
      jsonb_build_object('category', 'Diğer Borçlar',               'amount', ROUND(v_other_payables, 2),      'prev_amount', 0,                                   'group', 'current', 'code', '336'),
      jsonb_build_object('category', 'Alınan Avanslar',             'amount', ROUND(v_advances, 2),            'prev_amount', 0,                                   'group', 'current', 'code', '340'),
      jsonb_build_object('category', 'Borç ve Gider Karşılıkları',  'amount', ROUND(v_provisions, 2),          'prev_amount', 0,                                   'group', 'current', 'code', '370'),
      jsonb_build_object('category', 'Banka Kredileri',             'amount', ROUND(v_bank_loans, 2),          'prev_amount', 0,                                   'group', 'noncurrent', 'code', '400'),
      jsonb_build_object('category', 'Uzun Vadeli Ticari Borçlar',  'amount', ROUND(v_lt_trade_payables, 2),   'prev_amount', 0,                                   'group', 'noncurrent', 'code', '420'),
      jsonb_build_object('category', 'Diğer Uzun Vadeli Borçlar',   'amount', ROUND(v_lt_other_payables, 2),   'prev_amount', 0,                                   'group', 'noncurrent', 'code', '436')
    ),
    'equity_breakdown', jsonb_build_object(
      'capital', ROUND(v_capital, 2),
      'reserves', ROUND(v_reserves, 2),
      'profit_reserves', ROUND(v_profit_reserves, 2),
      'prev_year_profit', ROUND(v_prev_year_profit, 2),
      'current_profit', ROUND(v_current_profit, 2)
    ),
    'subtotals', jsonb_build_object(
      'current_assets', ROUND(v_current_assets, 2),
      'noncurrent_assets', ROUND(v_noncurrent_assets, 2),
      'current_liabilities', ROUND(v_current_liab, 2),
      'noncurrent_liabilities', ROUND(v_noncurrent_liab, 2)
    ),
    'prev_period', jsonb_build_object(
      'total_assets', ROUND(v_prev_total_assets, 2),
      'total_liabilities', ROUND(v_prev_total_liab, 2),
      'equity', ROUND(v_prev_equity, 2)
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
-- 2. get_aging_report() → JSONB
--    Frontend expects:
--      current, days_30, days_60, days_90, days_90_plus (numbers)
--      items: [{id, entity_name, amount, status, due_date, days_overdue}]
-- ============================================================
CREATE OR REPLACE FUNCTION get_aging_report()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_current    NUMERIC := 0;
  v_days30     NUMERIC := 0;
  v_days60     NUMERIC := 0;
  v_days90     NUMERIC := 0;
  v_days90plus NUMERIC := 0;
BEGIN
  -- Current (not yet due)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_current
  FROM finance_entries
  WHERE payment_status IN ('pending', 'overdue')
    AND entry_type = 'income'
    AND (due_date IS NULL OR due_date >= CURRENT_DATE);

  -- 1-30 days overdue
  SELECT COALESCE(SUM(total_amount), 0) INTO v_days30
  FROM finance_entries
  WHERE payment_status IN ('pending', 'overdue')
    AND entry_type = 'income'
    AND due_date IS NOT NULL
    AND due_date < CURRENT_DATE
    AND due_date >= CURRENT_DATE - INTERVAL '30 days';

  -- 31-60 days overdue
  SELECT COALESCE(SUM(total_amount), 0) INTO v_days60
  FROM finance_entries
  WHERE payment_status IN ('pending', 'overdue')
    AND entry_type = 'income'
    AND due_date IS NOT NULL
    AND due_date < CURRENT_DATE - INTERVAL '30 days'
    AND due_date >= CURRENT_DATE - INTERVAL '60 days';

  -- 61-90 days overdue
  SELECT COALESCE(SUM(total_amount), 0) INTO v_days90
  FROM finance_entries
  WHERE payment_status IN ('pending', 'overdue')
    AND entry_type = 'income'
    AND due_date IS NOT NULL
    AND due_date < CURRENT_DATE - INTERVAL '60 days'
    AND due_date >= CURRENT_DATE - INTERVAL '90 days';

  -- 90+ days overdue
  SELECT COALESCE(SUM(total_amount), 0) INTO v_days90plus
  FROM finance_entries
  WHERE payment_status IN ('pending', 'overdue')
    AND entry_type = 'income'
    AND due_date IS NOT NULL
    AND due_date < CURRENT_DATE - INTERVAL '90 days';

  RETURN jsonb_build_object(
    'current', ROUND(v_current, 2),
    'days_30', ROUND(v_days30, 2),
    'days_60', ROUND(v_days60, 2),
    'days_90', ROUND(v_days90, 2),
    'days_90_plus', ROUND(v_days90plus, 2),
    'items', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', fe.id,
        'entity_name', COALESCE(fe.description, fe.category),
        'amount', ROUND(fe.total_amount::NUMERIC, 2),
        'status', fe.payment_status,
        'due_date', fe.due_date,
        'days_overdue', GREATEST(CURRENT_DATE - fe.due_date, 0)
      ) ORDER BY fe.due_date ASC)
      FROM finance_entries fe
      WHERE fe.payment_status IN ('pending', 'overdue')
        AND fe.entry_type = 'income'
        AND fe.due_date IS NOT NULL
        AND fe.due_date < CURRENT_DATE
    ), '[]'::jsonb)
  );
END;
$$;

-- ============================================================
-- 3. get_profit_loss(p_start DATE, p_end DATE) → JSONB
--    Frontend expects:
--      total_revenue, total_expenses, net_profit (numbers)
--      sector_revenues: [{sector, revenue, commission}]
--      expense_categories: [{category, amount}]
--      monthly_profits: [{month, revenue, expenses, profit}]
-- ============================================================
CREATE OR REPLACE FUNCTION get_profit_loss(p_start DATE, p_end DATE)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_revenue  NUMERIC := 0;
  v_total_expenses NUMERIC := 0;
BEGIN
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_revenue
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date BETWEEN p_start AND p_end;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_expenses
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND created_at::date BETWEEN p_start AND p_end;

  RETURN jsonb_build_object(
    'total_revenue', ROUND(v_total_revenue, 2),
    'total_expenses', ROUND(v_total_expenses, 2),
    'net_profit', ROUND(v_total_revenue - v_total_expenses, 2),
    'sector_revenues', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'sector', source_type,
        'revenue', ROUND(SUM(total_amount)::NUMERIC, 2),
        'commission', ROUND(SUM(kdv_amount)::NUMERIC, 2)
      ))
      FROM finance_entries
      WHERE entry_type = 'income'
        AND created_at::date BETWEEN p_start AND p_end
        AND source_type IS NOT NULL
      GROUP BY source_type
    ), '[]'::jsonb),
    'expense_categories', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'category', category,
        'amount', ROUND(SUM(total_amount)::NUMERIC, 2)
      ))
      FROM finance_entries
      WHERE entry_type = 'expense'
        AND created_at::date BETWEEN p_start AND p_end
      GROUP BY category
    ), '[]'::jsonb),
    'monthly_profits', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'month', TO_CHAR(month_start, 'YYYY-MM'),
        'revenue', ROUND(income_total::NUMERIC, 2),
        'expenses', ROUND(expense_total::NUMERIC, 2),
        'profit', ROUND((income_total - expense_total)::NUMERIC, 2)
      ) ORDER BY month_start)
      FROM (
        SELECT
          DATE_TRUNC('month', created_at)::date AS month_start,
          COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) AS income_total,
          COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0) AS expense_total
        FROM finance_entries
        WHERE created_at::date BETWEEN p_start AND p_end
        GROUP BY DATE_TRUNC('month', created_at)
      ) monthly
    ), '[]'::jsonb)
  );
END;
$$;

-- ============================================================
-- 4. get_kdv_summary(p_year INT, p_month INT) → JSONB
--    Frontend expects:
--      total_kdv_collected, total_kdv_paid, net_kdv (numbers)
--      sector_kdv: [{sector, kdv_collected, kdv_paid, kdv_rate}]
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
BEGIN
  v_start := make_date(p_year, p_month, 1);
  v_end := (v_start + INTERVAL '1 month')::date;

  -- KDV collected from income
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_collected
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date >= v_start
    AND created_at::date < v_end;

  -- KDV paid on expenses (deductible)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_paid
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND created_at::date >= v_start
    AND created_at::date < v_end;

  RETURN jsonb_build_object(
    'total_kdv_collected', ROUND(v_collected, 2),
    'total_kdv_paid', ROUND(v_paid, 2),
    'net_kdv', ROUND(v_collected - v_paid, 2),
    'sector_kdv', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'sector', source_type,
        'kdv_collected', ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2),
        'kdv_paid', ROUND(COALESCE(SUM(CASE WHEN entry_type = 'expense' AND tax_deductible = TRUE THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2),
        'kdv_rate', ROUND(AVG(kdv_rate)::NUMERIC, 2)
      ))
      FROM finance_entries
      WHERE created_at::date >= v_start
        AND created_at::date < v_end
        AND source_type IS NOT NULL
      GROUP BY source_type
    ), '[]'::jsonb)
  );
END;
$$;

-- ============================================================
-- 5. Re-grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION get_balance_sheet(DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_aging_report() TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_profit_loss(DATE, DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_kdv_summary(INT, INT) TO authenticated, service_role, anon;
