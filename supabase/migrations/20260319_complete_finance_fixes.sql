-- ============================================================
-- COMPLETE FINANCE MODULE FIXES
-- Fixes: balance sheet cash/bank, monthly_profits, get_finance_stats,
--        get_recent_transactions, auto-sync triggers
-- ============================================================

-- ============================================================
-- 1. get_balance_sheet - Fix cash/bank split
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
  v_capital           NUMERIC := 0;
  v_reserves          NUMERIC := 0;
  v_profit_reserves   NUMERIC := 0;
  v_prev_year_profit  NUMERIC := 0;
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

  -- 100: Kasa/Nakit = only cash/nakit payments
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_cash
  FROM finance_entries
  WHERE payment_status = 'paid'
    AND payment_method IN ('cash', 'nakit')
    AND created_at::date <= p_date;

  -- 102: Banka = all paid except cash (online, card, bank_transfer, credit_card_on_delivery, etc.)
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_bank
  FROM finance_entries
  WHERE payment_status = 'paid'
    AND (payment_method IS NULL OR payment_method NOT IN ('cash', 'nakit'))
    AND created_at::date <= p_date;

  -- 120: Ticari Alacaklar
  SELECT COALESCE(SUM(total_amount), 0) INTO v_receivables
  FROM finance_entries
  WHERE entry_type = 'income'
    AND payment_status IN ('pending', 'overdue')
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

  v_receivables := v_receivables - v_lt_receivables;

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

  -- 360: Ödenecek Vergi
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

  -- Previous period
  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' AND payment_status = 'paid' AND payment_method IN ('cash', 'nakit') THEN total_amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN entry_type = 'expense' AND payment_status = 'paid' AND payment_method IN ('cash', 'nakit') THEN total_amount ELSE 0 END), 0)
  INTO v_prev_cash
  FROM finance_entries
  WHERE created_at::date <= v_prev_date AND payment_status = 'paid';

  SELECT
    COALESCE(SUM(CASE WHEN entry_type = 'income' AND payment_status = 'paid' AND (payment_method IS NULL OR payment_method NOT IN ('cash', 'nakit')) THEN total_amount ELSE 0 END), 0) -
    COALESCE(SUM(CASE WHEN entry_type = 'expense' AND payment_status = 'paid' AND (payment_method IS NULL OR payment_method NOT IN ('cash', 'nakit')) THEN total_amount ELSE 0 END), 0)
  INTO v_prev_bank
  FROM finance_entries
  WHERE created_at::date <= v_prev_date AND payment_status = 'paid';

  SELECT COALESCE(SUM(total_amount), 0) INTO v_prev_recv
  FROM finance_entries
  WHERE entry_type = 'income' AND payment_status IN ('pending', 'overdue') AND created_at::date <= v_prev_date;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_prev_trade_pay
  FROM finance_entries
  WHERE entry_type = 'expense' AND payment_status IN ('pending', 'overdue') AND created_at::date <= v_prev_date;

  v_prev_total_assets := GREATEST(v_prev_cash, 0) + GREATEST(v_prev_bank, 0) + v_prev_recv;
  v_prev_total_liab := v_prev_trade_pay;
  v_prev_equity := v_prev_total_assets - v_prev_total_liab;

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
      jsonb_build_object('category', 'Kasa / Nakit', 'amount', ROUND(GREATEST(v_cash, 0), 2), 'prev_amount', ROUND(GREATEST(v_prev_cash, 0), 2), 'group', 'current', 'code', '100'),
      jsonb_build_object('category', 'Banka Hesapları', 'amount', ROUND(GREATEST(v_bank, 0), 2), 'prev_amount', ROUND(GREATEST(v_prev_bank, 0), 2), 'group', 'current', 'code', '102'),
      jsonb_build_object('category', 'Ticari Alacaklar', 'amount', ROUND(v_receivables, 2), 'prev_amount', ROUND(v_prev_recv, 2), 'group', 'current', 'code', '120'),
      jsonb_build_object('category', 'Diğer Alacaklar', 'amount', ROUND(v_other_receivables, 2), 'prev_amount', 0, 'group', 'current', 'code', '136'),
      jsonb_build_object('category', 'Stoklar', 'amount', ROUND(v_inventory, 2), 'prev_amount', 0, 'group', 'current', 'code', '150'),
      jsonb_build_object('category', 'Peşin Ödenmiş Giderler', 'amount', ROUND(v_prepaid, 2), 'prev_amount', 0, 'group', 'current', 'code', '180'),
      jsonb_build_object('category', 'Maddi Duran Varlıklar', 'amount', ROUND(v_tangible, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '250'),
      jsonb_build_object('category', 'Maddi Olmayan Duran Varlıklar', 'amount', ROUND(v_intangible, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '260'),
      jsonb_build_object('category', 'Mali Duran Varlıklar', 'amount', ROUND(v_financial, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '240'),
      jsonb_build_object('category', 'Uzun Vadeli Alacaklar', 'amount', ROUND(v_lt_receivables, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '220')
    ),
    'liabilities', jsonb_build_array(
      jsonb_build_object('category', 'Ticari Borçlar', 'amount', ROUND(v_trade_payables, 2), 'prev_amount', ROUND(v_prev_trade_pay, 2), 'group', 'current', 'code', '320'),
      jsonb_build_object('category', 'Ödenecek Vergi ve Fonlar', 'amount', ROUND(v_taxes_payable, 2), 'prev_amount', 0, 'group', 'current', 'code', '360'),
      jsonb_build_object('category', 'Diğer Borçlar', 'amount', ROUND(v_other_payables, 2), 'prev_amount', 0, 'group', 'current', 'code', '336'),
      jsonb_build_object('category', 'Alınan Avanslar', 'amount', ROUND(v_advances, 2), 'prev_amount', 0, 'group', 'current', 'code', '340'),
      jsonb_build_object('category', 'Borç ve Gider Karşılıkları', 'amount', ROUND(v_provisions, 2), 'prev_amount', 0, 'group', 'current', 'code', '370'),
      jsonb_build_object('category', 'Banka Kredileri', 'amount', ROUND(v_bank_loans, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '400'),
      jsonb_build_object('category', 'Uzun Vadeli Ticari Borçlar', 'amount', ROUND(v_lt_trade_payables, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '420'),
      jsonb_build_object('category', 'Diğer Uzun Vadeli Borçlar', 'amount', ROUND(v_lt_other_payables, 2), 'prev_amount', 0, 'group', 'noncurrent', 'code', '436')
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
-- 2. get_profit_loss - Fix monthly_profits empty array
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
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_revenue
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date >= p_start AND created_at::date <= p_end;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_expenses
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND created_at::date >= p_start AND created_at::date <= p_end;

  -- Sector revenues
  SELECT COALESCE(jsonb_agg(row_to_json(s)::jsonb), '[]'::jsonb)
  INTO v_sectors
  FROM (
    SELECT
      source_type AS sector,
      ROUND(SUM(total_amount)::NUMERIC, 2) AS revenue,
      ROUND(SUM(kdv_amount)::NUMERIC, 2) AS commission
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at::date >= p_start AND created_at::date <= p_end
      AND source_type IS NOT NULL
    GROUP BY source_type
  ) s;

  -- Expense categories
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

  -- Monthly profits (fixed: use explicit variable and row_to_json)
  SELECT COALESCE(jsonb_agg(row_to_json(m)::jsonb ORDER BY m.month), '[]'::jsonb)
  INTO v_monthly
  FROM (
    SELECT
      TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') AS month,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0)::NUMERIC, 2) AS revenue,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)::NUMERIC, 2) AS expenses,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0)::NUMERIC
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
-- 3. get_kdv_summary - Keep existing, ensure all sectors shown
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

  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_collected
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date >= v_start AND created_at::date < v_end;

  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_paid
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND created_at::date >= v_start AND created_at::date < v_end;

  SELECT COALESCE(jsonb_agg(row_to_json(sk)::jsonb), '[]'::jsonb)
  INTO v_sectors
  FROM (
    SELECT
      source_type AS sector,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income' THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2) AS kdv_collected,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'expense' AND tax_deductible = TRUE THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2) AS kdv_paid,
      ROUND(AVG(kdv_rate)::NUMERIC, 0) AS kdv_rate
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
-- 4. get_finance_stats(p_days INT) - NEW
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
  v_total_revenue NUMERIC := 0;
  v_prev_total_revenue NUMERIC := 0;
  v_commission_revenue NUMERIC := 0;
  v_prev_commission_revenue NUMERIC := 0;
  v_partner_payments NUMERIC := 0;
  v_prev_partner_payments NUMERIC := 0;
  v_pending_payments NUMERIC := 0;
  v_food_revenue NUMERIC := 0;
  v_store_revenue NUMERIC := 0;
  v_taxi_revenue NUMERIC := 0;
  v_rental_revenue NUMERIC := 0;
  v_monthly JSONB;
  v_daily JSONB;
BEGIN
  v_start := CURRENT_DATE - (p_days || ' days')::INTERVAL;
  v_prev_end := v_start - INTERVAL '1 day';
  v_prev_start := v_prev_end - (p_days || ' days')::INTERVAL;

  -- Current period totals
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_revenue
  FROM finance_entries WHERE entry_type = 'income' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_prev_total_revenue
  FROM finance_entries WHERE entry_type = 'income' AND created_at::date BETWEEN v_prev_start AND v_prev_end;

  -- Commission = income - expense (net profit per transaction)
  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_commission_revenue
  FROM finance_entries WHERE created_at::date >= v_start;

  SELECT COALESCE(SUM(CASE WHEN entry_type = 'income' THEN total_amount ELSE 0 END), 0) -
         COALESCE(SUM(CASE WHEN entry_type = 'expense' THEN total_amount ELSE 0 END), 0)
  INTO v_prev_commission_revenue
  FROM finance_entries WHERE created_at::date BETWEEN v_prev_start AND v_prev_end;

  -- Partner payments (expenses)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_partner_payments
  FROM finance_entries WHERE entry_type = 'expense' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_prev_partner_payments
  FROM finance_entries WHERE entry_type = 'expense' AND created_at::date BETWEEN v_prev_start AND v_prev_end;

  -- Pending
  SELECT COALESCE(SUM(total_amount), 0) INTO v_pending_payments
  FROM finance_entries WHERE payment_status IN ('pending', 'overdue') AND entry_type = 'income';

  -- Revenue by sector
  SELECT COALESCE(SUM(total_amount), 0) INTO v_food_revenue
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'food' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_store_revenue
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'store' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_taxi_revenue
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'taxi' AND created_at::date >= v_start;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_rental_revenue
  FROM finance_entries WHERE entry_type = 'income' AND source_type = 'rental' AND created_at::date >= v_start;

  -- Monthly revenue (last 12 months)
  SELECT COALESCE(jsonb_agg(row_to_json(mr)::jsonb ORDER BY mr.month_num), '[]'::jsonb)
  INTO v_monthly
  FROM (
    SELECT
      EXTRACT(MONTH FROM DATE_TRUNC('month', created_at))::INT AS month_num,
      TO_CHAR(DATE_TRUNC('month', created_at), 'TMmon') AS month_name,
      ROUND(SUM(total_amount)::NUMERIC, 2) AS revenue,
      ROUND(SUM(kdv_amount)::NUMERIC, 2) AS commission
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at >= (CURRENT_DATE - INTERVAL '12 months')
    GROUP BY DATE_TRUNC('month', created_at)
  ) mr;

  -- Daily revenue (last 7 days)
  SELECT COALESCE(jsonb_agg(row_to_json(dr)::jsonb ORDER BY dr.day_num), '[]'::jsonb)
  INTO v_daily
  FROM (
    SELECT
      EXTRACT(DOW FROM created_at::date)::INT AS day_num,
      TO_CHAR(created_at::date, 'TMdy') AS day_name,
      ROUND(SUM(total_amount)::NUMERIC, 2) AS revenue
    FROM finance_entries
    WHERE entry_type = 'income'
      AND created_at::date >= (CURRENT_DATE - INTERVAL '7 days')
    GROUP BY created_at::date
  ) dr;

  RETURN jsonb_build_object(
    'summary', jsonb_build_object(
      'total_revenue', ROUND(v_total_revenue, 2),
      'prev_total_revenue', ROUND(v_prev_total_revenue, 2),
      'commission_revenue', ROUND(v_commission_revenue, 2),
      'prev_commission_revenue', ROUND(v_prev_commission_revenue, 2),
      'partner_payments', ROUND(v_partner_payments, 2),
      'prev_partner_payments', ROUND(v_prev_partner_payments, 2),
      'pending_payments', ROUND(v_pending_payments, 2)
    ),
    'revenue_distribution', jsonb_build_object(
      'food_revenue', ROUND(v_food_revenue, 2),
      'store_revenue', ROUND(v_store_revenue, 2),
      'taxi_revenue', ROUND(v_taxi_revenue, 2),
      'rental_revenue', ROUND(v_rental_revenue, 2)
    ),
    'monthly_revenue', v_monthly,
    'daily_revenue', v_daily
  );
END;
$$;

-- ============================================================
-- 5. get_recent_transactions(p_limit INT, p_source TEXT) - NEW
-- ============================================================
CREATE OR REPLACE FUNCTION get_recent_transactions(p_limit INT DEFAULT 10, p_source TEXT DEFAULT NULL)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN COALESCE((
    SELECT jsonb_agg(row_to_json(t)::jsonb)
    FROM (
      SELECT
        id::TEXT AS transaction_id,
        entry_type AS type,
        COALESCE(description, category) AS description,
        ROUND(total_amount::NUMERIC, 2) AS amount,
        TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS') AS date,
        COALESCE(source_type, 'other') AS source
      FROM finance_entries
      WHERE (p_source IS NULL OR source_type = p_source)
      ORDER BY created_at DESC
      LIMIT p_limit
    ) t
  ), '[]'::jsonb);
END;
$$;

-- ============================================================
-- 6. Trigger functions for auto-sync
-- ============================================================

-- Order delivered → create finance entries
CREATE OR REPLACE FUNCTION trg_order_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, merchant_id, payment_status, payment_method, paid_at, created_at, due_date
    ) VALUES (
      'income', 'siparis_geliri',
      CASE WHEN NEW.delivery_fee > 0 THEN 'delivery' ELSE 'pickup' END,
      'Sipariş #' || COALESCE(NEW.order_number, LEFT(NEW.id::text, 8)),
      ROUND(NEW.total_amount / 1.10, 2), 10.00,
      ROUND(NEW.total_amount - (NEW.total_amount / 1.10), 2), NEW.total_amount,
      'food', NEW.id, NEW.merchant_id,
      CASE WHEN NEW.payment_status = 'paid' THEN 'paid' ELSE 'pending' END,
      NEW.payment_method,
      CASE WHEN NEW.payment_status = 'paid' THEN NOW() ELSE NULL END,
      NEW.created_at,
      CASE WHEN NEW.payment_status != 'paid' THEN (NEW.created_at + INTERVAL '30 days')::date ELSE NULL END
    ) ON CONFLICT DO NOTHING;

    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, merchant_id, payment_status, payment_method, created_at, due_date, tax_deductible
    ) VALUES (
      'expense', 'merchant_odeme', 'komisyon_sonrasi',
      'Merchant ödeme - Sipariş #' || COALESCE(NEW.order_number, LEFT(NEW.id::text, 8)),
      ROUND(NEW.total_amount * (1 - COALESCE(NEW.commission_rate, 15) / 100) / 1.10, 2), 10.00,
      ROUND((NEW.total_amount * (1 - COALESCE(NEW.commission_rate, 15) / 100)) - (NEW.total_amount * (1 - COALESCE(NEW.commission_rate, 15) / 100) / 1.10), 2),
      ROUND(NEW.total_amount * (1 - COALESCE(NEW.commission_rate, 15) / 100), 2),
      'food', NEW.id, NEW.merchant_id,
      'pending', 'bank_transfer', NEW.created_at,
      (NEW.created_at + INTERVAL '30 days')::date, TRUE
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

-- Taxi ride completed → create finance entries
CREATE OR REPLACE FUNCTION trg_taxi_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, payment_status, payment_method, paid_at, created_at
    ) VALUES (
      'income', 'taksi_geliri', 'platform_komisyon',
      'Taksi sürüşü #' || COALESCE(NEW.ride_number, LEFT(NEW.id::text, 8)),
      ROUND(NEW.fare / 1.20, 2), 20.00,
      ROUND(NEW.fare - (NEW.fare / 1.20), 2), NEW.fare,
      'taxi', NEW.id, 'paid', 'online', NOW(), NEW.created_at
    ) ON CONFLICT DO NOTHING;

    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, payment_status, payment_method, paid_at, created_at, tax_deductible
    ) VALUES (
      'expense', 'surucu_odeme', 'taksi_paylasim',
      'Sürücü ödeme - Sürüş #' || COALESCE(NEW.ride_number, LEFT(NEW.id::text, 8)),
      ROUND(NEW.fare * 0.80 / 1.20, 2), 20.00,
      ROUND((NEW.fare * 0.80) - (NEW.fare * 0.80 / 1.20), 2), ROUND(NEW.fare * 0.80, 2),
      'taxi', NEW.id, 'paid', 'bank_transfer', NOW(), NEW.created_at, TRUE
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

-- Rental booking completed/confirmed → create finance entries
CREATE OR REPLACE FUNCTION trg_rental_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status IN ('completed', 'confirmed') AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'confirmed')) THEN
    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, payment_status, payment_method, paid_at, created_at, due_date
    ) VALUES (
      'income', 'kiralama_geliri', 'arac_kiralama',
      'Kiralama #' || COALESCE(NEW.booking_number, LEFT(NEW.id::text, 8)),
      ROUND(NEW.total_amount / 1.20, 2), 20.00,
      ROUND(NEW.total_amount - (NEW.total_amount / 1.20), 2), NEW.total_amount,
      'rental', NEW.id,
      CASE WHEN NEW.payment_status = 'paid' THEN 'paid' ELSE 'pending' END,
      NEW.payment_method,
      CASE WHEN NEW.payment_status = 'paid' THEN NOW() ELSE NULL END,
      NEW.created_at,
      CASE WHEN NEW.payment_status != 'paid' THEN (NEW.created_at + INTERVAL '30 days')::date ELSE NULL END
    ) ON CONFLICT DO NOTHING;

    INSERT INTO finance_entries (
      entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
      source_type, source_id, payment_status, payment_method, created_at, due_date, tax_deductible
    ) VALUES (
      'expense', 'sirket_odeme', 'kiralama_paylasim',
      'Firma ödeme - Kiralama #' || COALESCE(NEW.booking_number, LEFT(NEW.id::text, 8)),
      ROUND(COALESCE(NEW.net_amount, NEW.total_amount * 0.85) / 1.20, 2), 20.00,
      ROUND(COALESCE(NEW.net_amount, NEW.total_amount * 0.85) - COALESCE(NEW.net_amount, NEW.total_amount * 0.85) / 1.20, 2),
      COALESCE(NEW.net_amount, ROUND(NEW.total_amount * 0.85, 2)),
      'rental', NEW.id,
      'pending', 'bank_transfer', NEW.created_at,
      (NEW.created_at + INTERVAL '30 days')::date, TRUE
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
-- 7. Grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION get_balance_sheet(DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_aging_report() TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_profit_loss(DATE, DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_kdv_summary(INT, INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_finance_stats(INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_recent_transactions(INT, TEXT) TO authenticated, service_role, anon;
