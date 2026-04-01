-- ============================================================
-- FAZ 5A: Finance Module - Tables, Seed Data, RPC Functions
-- Depends on: invoices, invoice_items, company_settings, admin_users
-- Does NOT alter existing tables or RPCs
-- ============================================================

-- ============================================================
-- 1. finance_entries
-- ============================================================
CREATE TABLE finance_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_type VARCHAR(10) NOT NULL CHECK (entry_type IN ('income', 'expense')),
  category VARCHAR(100) NOT NULL,
  subcategory VARCHAR(100),
  description TEXT,
  amount DECIMAL(15,2) NOT NULL,
  kdv_rate DECIMAL(5,2) NOT NULL DEFAULT 20.00,
  kdv_amount DECIMAL(15,2) NOT NULL DEFAULT 0,
  total_amount DECIMAL(15,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'TRY',
  source_type VARCHAR(20) CHECK (source_type IN (
    'food','store','market','taxi','rental','car_sales','real_estate','jobs','manual'
  )),
  source_id UUID,
  merchant_id UUID,
  invoice_id UUID REFERENCES invoices(id),
  payment_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (payment_status IN (
    'pending','paid','overdue','cancelled'
  )),
  payment_method VARCHAR(50),
  due_date DATE,
  paid_at TIMESTAMPTZ,
  tax_deductible BOOLEAN DEFAULT FALSE,
  notes TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_finance_entries_type ON finance_entries(entry_type);
CREATE INDEX idx_finance_entries_source ON finance_entries(source_type, source_id);
CREATE INDEX idx_finance_entries_status ON finance_entries(payment_status);
CREATE INDEX idx_finance_entries_category ON finance_entries(category);
CREATE INDEX idx_finance_entries_created ON finance_entries(created_at DESC);
CREATE INDEX idx_finance_entries_merchant ON finance_entries(merchant_id);
CREATE INDEX idx_finance_entries_invoice ON finance_entries(invoice_id);
CREATE INDEX idx_finance_entries_due_date ON finance_entries(due_date);

ALTER TABLE finance_entries ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage finance_entries" ON finance_entries
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- ============================================================
-- 2. commission_rates
-- ============================================================
CREATE TABLE commission_rates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sector VARCHAR(30) UNIQUE NOT NULL,
  default_rate DECIMAL(5,2) NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE commission_rates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage commission_rates" ON commission_rates
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Seed data
INSERT INTO commission_rates (sector, default_rate, description) VALUES
  ('food',        15.00, 'Yemek siparişleri komisyon oranı'),
  ('store',       15.00, 'Mağaza siparişleri komisyon oranı'),
  ('market',      15.00, 'Market siparişleri komisyon oranı'),
  ('taxi',        20.00, 'Taksi yolculukları komisyon oranı'),
  ('rental',      15.00, 'Araç kiralama komisyon oranı'),
  ('car_sales',   10.00, 'Araç satış komisyon oranı'),
  ('real_estate',  5.00, 'Emlak komisyon oranı'),
  ('jobs',        10.00, 'İş ilanları komisyon oranı')
ON CONFLICT (sector) DO NOTHING;

-- ============================================================
-- 3. merchant_commission_overrides
-- ============================================================
CREATE TABLE merchant_commission_overrides (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id UUID NOT NULL,
  merchant_type VARCHAR(30) NOT NULL,
  custom_rate DECIMAL(5,2) NOT NULL,
  reason TEXT,
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mco_merchant ON merchant_commission_overrides(merchant_id);
CREATE INDEX idx_mco_type ON merchant_commission_overrides(merchant_type);
CREATE INDEX idx_mco_dates ON merchant_commission_overrides(effective_from, effective_to);

ALTER TABLE merchant_commission_overrides ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage merchant_commission_overrides" ON merchant_commission_overrides
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- ============================================================
-- 4. expense_categories
-- ============================================================
CREATE TABLE expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(100) NOT NULL,
  parent_id UUID REFERENCES expense_categories(id),
  description TEXT,
  is_tax_deductible BOOLEAN DEFAULT FALSE,
  sort_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_expense_categories_parent ON expense_categories(parent_id);
CREATE INDEX idx_expense_categories_sort ON expense_categories(sort_order);

ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Admins can manage expense_categories" ON expense_categories
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- Seed data
INSERT INTO expense_categories (name, description, is_tax_deductible, sort_order) VALUES
  ('Personel',          'Maaş, SGK, ikramiye vb.',            TRUE,  1),
  ('Ofis',              'Kira, fatura, ofis malzemeleri',      TRUE,  2),
  ('Pazarlama',         'Reklam, kampanya, sosyal medya',      TRUE,  3),
  ('Teknoloji',         'Sunucu, yazılım, lisans',             TRUE,  4),
  ('Hukuk',             'Avukat, danışmanlık, noter',          TRUE,  5),
  ('Vergi',             'KDV, kurumlar vergisi, damga',        FALSE, 6),
  ('Partner Ödemeleri', 'Merchant ve partner ödemeleri',       FALSE, 7),
  ('Kurye Ödemeleri',   'Kurye ve sürücü ödemeleri',           FALSE, 8),
  ('İade',              'Müşteri iadeleri',                    FALSE, 9),
  ('Diğer',             'Diğer giderler',                      FALSE, 10)
ON CONFLICT DO NOTHING;

-- ============================================================
-- 5. RPC Functions (new, does not touch existing RPCs)
-- ============================================================

-- 5a. get_balance_sheet(p_date DATE) → JSON
CREATE OR REPLACE FUNCTION get_balance_sheet(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_income   NUMERIC := 0;
  v_total_expense  NUMERIC := 0;
  v_receivables    NUMERIC := 0;
  v_payables       NUMERIC := 0;
BEGIN
  -- Toplam gelir (paid)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_income
  FROM finance_entries
  WHERE entry_type = 'income' AND payment_status = 'paid'
    AND created_at::date <= p_date;

  -- Toplam gider (paid)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_expense
  FROM finance_entries
  WHERE entry_type = 'expense' AND payment_status = 'paid'
    AND created_at::date <= p_date;

  -- Alacaklar (pending/overdue income)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_receivables
  FROM finance_entries
  WHERE entry_type = 'income' AND payment_status IN ('pending', 'overdue')
    AND created_at::date <= p_date;

  -- Borçlar (pending/overdue expense)
  SELECT COALESCE(SUM(total_amount), 0) INTO v_payables
  FROM finance_entries
  WHERE entry_type = 'expense' AND payment_status IN ('pending', 'overdue')
    AND created_at::date <= p_date;

  RETURN json_build_object(
    'date', p_date,
    'assets', json_build_object(
      'cash', ROUND(v_total_income - v_total_expense, 2),
      'receivables', ROUND(v_receivables, 2),
      'total_assets', ROUND((v_total_income - v_total_expense) + v_receivables, 2)
    ),
    'liabilities', json_build_object(
      'payables', ROUND(v_payables, 2),
      'total_liabilities', ROUND(v_payables, 2)
    ),
    'equity', json_build_object(
      'retained_earnings', ROUND((v_total_income - v_total_expense) + v_receivables - v_payables, 2)
    )
  );
END;
$$;

-- 5b. get_profit_loss(p_start DATE, p_end DATE) → JSON
CREATE OR REPLACE FUNCTION get_profit_loss(p_start DATE, p_end DATE)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_income  NUMERIC := 0;
  v_total_expense NUMERIC := 0;
BEGIN
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_income
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date BETWEEN p_start AND p_end;

  SELECT COALESCE(SUM(total_amount), 0) INTO v_total_expense
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND created_at::date BETWEEN p_start AND p_end;

  RETURN json_build_object(
    'period', json_build_object('start', p_start, 'end', p_end),
    'income', json_build_object(
      'total', ROUND(v_total_income, 2),
      'by_sector', (
        SELECT COALESCE(json_agg(json_build_object(
          'source_type', source_type,
          'total', ROUND(SUM(total_amount)::NUMERIC, 2)
        )), '[]'::json)
        FROM finance_entries
        WHERE entry_type = 'income'
          AND created_at::date BETWEEN p_start AND p_end
        GROUP BY source_type
      )
    ),
    'expenses', json_build_object(
      'total', ROUND(v_total_expense, 2),
      'by_category', (
        SELECT COALESCE(json_agg(json_build_object(
          'category', category,
          'total', ROUND(SUM(total_amount)::NUMERIC, 2)
        )), '[]'::json)
        FROM finance_entries
        WHERE entry_type = 'expense'
          AND created_at::date BETWEEN p_start AND p_end
        GROUP BY category
      )
    ),
    'net_profit', ROUND(v_total_income - v_total_expense, 2)
  );
END;
$$;

-- 5c. get_kdv_summary(p_year INT, p_month INT) → JSON
CREATE OR REPLACE FUNCTION get_kdv_summary(p_year INT, p_month INT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_collected_kdv   NUMERIC := 0;
  v_deductible_kdv  NUMERIC := 0;
  v_month_start     DATE;
  v_month_end       DATE;
BEGIN
  v_month_start := make_date(p_year, p_month, 1);
  v_month_end   := (v_month_start + INTERVAL '1 month')::date;

  -- Toplanan KDV (gelirlerden)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_collected_kdv
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date >= v_month_start
    AND created_at::date < v_month_end;

  -- İndirilebilir KDV (giderlerden, tax_deductible olanlar)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_deductible_kdv
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND created_at::date >= v_month_start
    AND created_at::date < v_month_end;

  RETURN json_build_object(
    'year', p_year,
    'month', p_month,
    'collected_kdv', ROUND(v_collected_kdv, 2),
    'deductible_kdv', ROUND(v_deductible_kdv, 2),
    'payable_kdv', ROUND(v_collected_kdv - v_deductible_kdv, 2),
    'breakdown', (
      SELECT COALESCE(json_agg(json_build_object(
        'kdv_rate', kdv_rate,
        'entry_type', entry_type,
        'total_kdv', ROUND(SUM(kdv_amount)::NUMERIC, 2),
        'count', COUNT(*)
      )), '[]'::json)
      FROM finance_entries
      WHERE created_at::date >= v_month_start
        AND created_at::date < v_month_end
      GROUP BY kdv_rate, entry_type
    )
  );
END;
$$;

-- 5d. get_aging_report() → JSON
CREATE OR REPLACE FUNCTION get_aging_report()
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN json_build_object(
    'generated_at', NOW(),
    'buckets', (
      SELECT json_agg(bucket ORDER BY bucket_order)
      FROM (
        SELECT
          CASE
            WHEN due_date >= CURRENT_DATE - INTERVAL '30 days' THEN '0-30'
            WHEN due_date >= CURRENT_DATE - INTERVAL '60 days' THEN '31-60'
            WHEN due_date >= CURRENT_DATE - INTERVAL '90 days' THEN '61-90'
            ELSE '90+'
          END AS bucket_label,
          CASE
            WHEN due_date >= CURRENT_DATE - INTERVAL '30 days' THEN 1
            WHEN due_date >= CURRENT_DATE - INTERVAL '60 days' THEN 2
            WHEN due_date >= CURRENT_DATE - INTERVAL '90 days' THEN 3
            ELSE 4
          END AS bucket_order,
          json_build_object(
            'label', CASE
              WHEN due_date >= CURRENT_DATE - INTERVAL '30 days' THEN '0-30 gün'
              WHEN due_date >= CURRENT_DATE - INTERVAL '60 days' THEN '31-60 gün'
              WHEN due_date >= CURRENT_DATE - INTERVAL '90 days' THEN '61-90 gün'
              ELSE '90+ gün'
            END,
            'count', COUNT(*),
            'total_amount', ROUND(SUM(total_amount)::NUMERIC, 2)
          ) AS bucket
        FROM finance_entries
        WHERE payment_status IN ('pending', 'overdue')
          AND due_date IS NOT NULL
        GROUP BY bucket_label, bucket_order
      ) sub
    ),
    'total_overdue', (
      SELECT COALESCE(ROUND(SUM(total_amount)::NUMERIC, 2), 0)
      FROM finance_entries
      WHERE payment_status IN ('pending', 'overdue')
        AND due_date IS NOT NULL
        AND due_date < CURRENT_DATE
    )
  );
END;
$$;

-- 5e. generate_batch_invoices(p_sector, p_start, p_end, p_created_by) → JSON
CREATE OR REPLACE FUNCTION generate_batch_invoices(
  p_sector TEXT,
  p_start DATE,
  p_end DATE,
  p_created_by UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_company      RECORD;
  v_count        INT := 0;
  v_total        NUMERIC := 0;
  v_rec          RECORD;
  v_number       TEXT;
  v_subtotal     NUMERIC;
  v_kdv_rate     NUMERIC;
  v_kdv_amount   NUMERIC;
  v_invoice_id   UUID;
BEGIN
  SELECT * INTO v_company FROM company_settings LIMIT 1;

  -- KDV rate by sector
  v_kdv_rate := CASE p_sector
    WHEN 'food' THEN 10.00
    WHEN 'taxi' THEN 20.00
    ELSE 20.00
  END;

  IF p_sector = 'food' THEN
    -- Food orders without invoice
    FOR v_rec IN
      SELECT o.id, o.total_amount, o.user_id, o.merchant_id,
             u.full_name AS buyer_name, u.email AS buyer_email,
             m.name AS merchant_name
      FROM orders o
      LEFT JOIN users u ON u.id = o.user_id
      LEFT JOIN merchants m ON m.id = o.merchant_id
      WHERE o.status = 'delivered'
        AND o.created_at::date BETWEEN p_start AND p_end
        AND (o.source_type IS NULL OR o.source_type = 'food')
        AND NOT EXISTS (SELECT 1 FROM invoices WHERE source_type = 'food' AND source_id = o.id)
    LOOP
      v_subtotal := ROUND(v_rec.total_amount / (1 + v_kdv_rate / 100), 2);
      v_kdv_amount := v_rec.total_amount - v_subtotal;
      v_number := v_company.invoice_prefix || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

      INSERT INTO invoices (
        invoice_number, invoice_type, source_type, source_id,
        seller_name, seller_tax_number, seller_tax_office, seller_address,
        buyer_name, buyer_email,
        subtotal, kdv_rate, kdv_amount, total, currency, status, created_by
      ) VALUES (
        v_number, 'sale', 'food', v_rec.id,
        COALESCE(v_rec.merchant_name, v_company.name),
        v_company.tax_number, v_company.tax_office, v_company.address,
        COALESCE(v_rec.buyer_name, 'Müşteri'), v_rec.buyer_email,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount, 'TRY', 'issued', p_created_by
      ) RETURNING id INTO v_invoice_id;

      -- Finance entry for this invoice
      INSERT INTO finance_entries (
        entry_type, category, description, amount, kdv_rate, kdv_amount, total_amount,
        source_type, source_id, merchant_id, invoice_id, payment_status, created_by
      ) VALUES (
        'income', 'Sipariş Geliri', 'Yemek siparişi faturası: ' || v_number,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount,
        'food', v_rec.id, v_rec.merchant_id, v_invoice_id, 'paid', p_created_by
      );

      v_count := v_count + 1;
      v_total := v_total + v_rec.total_amount;
    END LOOP;

  ELSIF p_sector = 'store' THEN
    FOR v_rec IN
      SELECT o.id, o.total_amount, o.user_id, o.merchant_id,
             u.full_name AS buyer_name, u.email AS buyer_email,
             m.name AS merchant_name
      FROM orders o
      LEFT JOIN users u ON u.id = o.user_id
      LEFT JOIN merchants m ON m.id = o.merchant_id
      WHERE o.status = 'delivered'
        AND o.created_at::date BETWEEN p_start AND p_end
        AND o.source_type = 'store'
        AND NOT EXISTS (SELECT 1 FROM invoices WHERE source_type = 'store' AND source_id = o.id)
    LOOP
      v_subtotal := ROUND(v_rec.total_amount / (1 + v_kdv_rate / 100), 2);
      v_kdv_amount := v_rec.total_amount - v_subtotal;
      v_number := v_company.invoice_prefix || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

      INSERT INTO invoices (
        invoice_number, invoice_type, source_type, source_id,
        seller_name, seller_tax_number, seller_tax_office, seller_address,
        buyer_name, buyer_email,
        subtotal, kdv_rate, kdv_amount, total, currency, status, created_by
      ) VALUES (
        v_number, 'sale', 'store', v_rec.id,
        COALESCE(v_rec.merchant_name, v_company.name),
        v_company.tax_number, v_company.tax_office, v_company.address,
        COALESCE(v_rec.buyer_name, 'Müşteri'), v_rec.buyer_email,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount, 'TRY', 'issued', p_created_by
      ) RETURNING id INTO v_invoice_id;

      INSERT INTO finance_entries (
        entry_type, category, description, amount, kdv_rate, kdv_amount, total_amount,
        source_type, source_id, merchant_id, invoice_id, payment_status, created_by
      ) VALUES (
        'income', 'Sipariş Geliri', 'Mağaza siparişi faturası: ' || v_number,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount,
        'store', v_rec.id, v_rec.merchant_id, v_invoice_id, 'paid', p_created_by
      );

      v_count := v_count + 1;
      v_total := v_total + v_rec.total_amount;
    END LOOP;

  ELSIF p_sector = 'taxi' THEN
    FOR v_rec IN
      SELECT tr.id, tr.fare AS total_amount, tr.passenger_id,
             u.full_name AS buyer_name, u.email AS buyer_email
      FROM taxi_rides tr
      LEFT JOIN users u ON u.id = tr.passenger_id
      WHERE tr.status = 'completed'
        AND tr.created_at::date BETWEEN p_start AND p_end
        AND NOT EXISTS (SELECT 1 FROM invoices WHERE source_type = 'taxi' AND source_id = tr.id)
    LOOP
      v_subtotal := ROUND(v_rec.total_amount / (1 + v_kdv_rate / 100), 2);
      v_kdv_amount := v_rec.total_amount - v_subtotal;
      v_number := v_company.invoice_prefix || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

      INSERT INTO invoices (
        invoice_number, invoice_type, source_type, source_id,
        seller_name, seller_tax_number, seller_tax_office, seller_address,
        buyer_name, buyer_email,
        subtotal, kdv_rate, kdv_amount, total, currency, status, created_by
      ) VALUES (
        v_number, 'sale', 'taxi', v_rec.id,
        v_company.name, v_company.tax_number, v_company.tax_office, v_company.address,
        COALESCE(v_rec.buyer_name, 'Müşteri'), v_rec.buyer_email,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount, 'TRY', 'issued', p_created_by
      ) RETURNING id INTO v_invoice_id;

      INSERT INTO finance_entries (
        entry_type, category, description, amount, kdv_rate, kdv_amount, total_amount,
        source_type, source_id, invoice_id, payment_status, created_by
      ) VALUES (
        'income', 'Taksi Geliri', 'Taksi yolculuğu faturası: ' || v_number,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount,
        'taxi', v_rec.id, v_invoice_id, 'paid', p_created_by
      );

      v_count := v_count + 1;
      v_total := v_total + v_rec.total_amount;
    END LOOP;

  ELSIF p_sector = 'rental' THEN
    FOR v_rec IN
      SELECT i.id, i.total AS total_amount, i.buyer_name, i.buyer_email
      FROM invoices i
      WHERE i.source_type = 'rental'
        AND i.created_at::date BETWEEN p_start AND p_end
        AND NOT EXISTS (
          SELECT 1 FROM finance_entries fe WHERE fe.source_type = 'rental' AND fe.invoice_id = i.id
        )
    LOOP
      v_subtotal := ROUND(v_rec.total_amount / (1 + v_kdv_rate / 100), 2);
      v_kdv_amount := v_rec.total_amount - v_subtotal;

      INSERT INTO finance_entries (
        entry_type, category, description, amount, kdv_rate, kdv_amount, total_amount,
        source_type, invoice_id, payment_status, created_by
      ) VALUES (
        'income', 'Kiralama Geliri', 'Araç kiralama: ' || v_rec.buyer_name,
        v_subtotal, v_kdv_rate, v_kdv_amount, v_rec.total_amount,
        'rental', v_rec.id, 'paid', p_created_by
      );

      v_count := v_count + 1;
      v_total := v_total + v_rec.total_amount;
    END LOOP;
  END IF;

  RETURN json_build_object(
    'sector', p_sector,
    'period', json_build_object('start', p_start, 'end', p_end),
    'invoices_created', v_count,
    'total_amount', ROUND(v_total, 2)
  );
END;
$$;

-- 5f. get_sector_revenue_detail(p_sector TEXT, p_days INT) → JSON
CREATE OR REPLACE FUNCTION get_sector_revenue_detail(p_sector TEXT, p_days INT DEFAULT 30)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_start TIMESTAMPTZ := NOW() - (p_days * INTERVAL '1 day');
  v_total NUMERIC := 0;
  v_commission_rate NUMERIC := 0;
BEGIN
  -- Get commission rate
  SELECT default_rate INTO v_commission_rate
  FROM commission_rates WHERE sector = p_sector;

  IF v_commission_rate IS NULL THEN
    v_commission_rate := 15.00;
  END IF;

  -- Total revenue from finance_entries
  SELECT COALESCE(SUM(total_amount), 0) INTO v_total
  FROM finance_entries
  WHERE entry_type = 'income'
    AND source_type = p_sector
    AND created_at >= v_start;

  RETURN json_build_object(
    'sector', p_sector,
    'days', p_days,
    'total_revenue', ROUND(v_total, 2),
    'commission_rate', v_commission_rate,
    'commission_amount', ROUND(v_total * v_commission_rate / 100, 2),
    'net_after_commission', ROUND(v_total - (v_total * v_commission_rate / 100), 2),
    'daily_breakdown', (
      SELECT COALESCE(json_agg(json_build_object(
        'date', d::date,
        'revenue', COALESCE(r.rev, 0),
        'count', COALESCE(r.cnt, 0)
      ) ORDER BY d), '[]'::json)
      FROM generate_series(v_start::date, CURRENT_DATE, '1 day') d
      LEFT JOIN (
        SELECT created_at::date AS day, ROUND(SUM(total_amount)::NUMERIC, 2) AS rev, COUNT(*) AS cnt
        FROM finance_entries
        WHERE entry_type = 'income' AND source_type = p_sector AND created_at >= v_start
        GROUP BY created_at::date
      ) r ON r.day = d::date
    ),
    'top_merchants', (
      SELECT COALESCE(json_agg(json_build_object(
        'merchant_id', merchant_id,
        'total', ROUND(SUM(total_amount)::NUMERIC, 2),
        'count', COUNT(*)
      ) ORDER BY SUM(total_amount) DESC), '[]'::json)
      FROM finance_entries
      WHERE entry_type = 'income' AND source_type = p_sector AND created_at >= v_start AND merchant_id IS NOT NULL
      GROUP BY merchant_id
      LIMIT 10
    )
  );
END;
$$;

-- ============================================================
-- 6. Update auto-invoice triggers to also insert finance_entries
-- ============================================================

-- 6a. Updated taxi invoice trigger
CREATE OR REPLACE FUNCTION create_taxi_invoice_on_complete()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_number TEXT;
  v_company RECORD;
  v_user RECORD;
  v_subtotal DECIMAL(15,2);
  v_kdv_rate DECIMAL(5,2) := 20.00;
  v_kdv_amount DECIMAL(15,2);
  v_amount DECIMAL(15,2);
  v_invoice_id UUID;
BEGIN
  IF NEW.status != 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM invoices WHERE source_type='taxi' AND source_id=NEW.id) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_company FROM company_settings LIMIT 1;
  SELECT full_name, email INTO v_user FROM users WHERE id = NEW.passenger_id;

  SELECT COALESCE(NEW.fare, 0) INTO v_amount;
  IF v_amount = 0 THEN
    SELECT COALESCE(amount, 0) INTO v_amount FROM payments WHERE ride_id = NEW.id LIMIT 1;
  END IF;

  v_subtotal := ROUND(v_amount / 1.20, 2);
  v_kdv_amount := v_amount - v_subtotal;
  v_number := v_company.invoice_prefix ||
              TO_CHAR(NOW(), 'YYYYMM') || '-' ||
              LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

  INSERT INTO invoices (
    invoice_number, invoice_type, source_type, source_id,
    seller_name, seller_tax_number, seller_tax_office, seller_address,
    buyer_name, buyer_email,
    subtotal, kdv_rate, kdv_amount, total, currency, status
  ) VALUES (
    v_number, 'sale', 'taxi', NEW.id,
    v_company.name, v_company.tax_number, v_company.tax_office, v_company.address,
    COALESCE(v_user.full_name, 'Müşteri'), v_user.email,
    v_subtotal, v_kdv_rate, v_kdv_amount, v_amount, 'TRY', 'issued'
  ) RETURNING id INTO v_invoice_id;

  -- Finance entry
  INSERT INTO finance_entries (
    entry_type, category, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, invoice_id, payment_status
  ) VALUES (
    'income', 'Taksi Geliri', 'Otomatik taksi faturası: ' || v_number,
    v_subtotal, v_kdv_rate, v_kdv_amount, v_amount,
    'taxi', NEW.id, v_invoice_id, 'paid'
  );

  RETURN NEW;
END;
$$;

-- 6b. Updated food invoice trigger
CREATE OR REPLACE FUNCTION create_food_invoice_on_deliver()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_number TEXT;
  v_company RECORD;
  v_user RECORD;
  v_merchant RECORD;
  v_subtotal DECIMAL(15,2);
  v_kdv_amount DECIMAL(15,2);
  v_invoice_id UUID;
BEGIN
  IF NEW.status != 'delivered' OR OLD.status = 'delivered' THEN
    RETURN NEW;
  END IF;
  IF EXISTS (SELECT 1 FROM invoices WHERE source_type='food' AND source_id=NEW.id) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_company FROM company_settings LIMIT 1;
  SELECT full_name, email INTO v_user FROM users WHERE id = NEW.user_id;
  SELECT name INTO v_merchant FROM merchants WHERE id = NEW.merchant_id;

  v_subtotal := ROUND(NEW.total_amount / 1.10, 2);
  v_kdv_amount := NEW.total_amount - v_subtotal;
  v_number := v_company.invoice_prefix ||
              TO_CHAR(NOW(), 'YYYYMM') || '-' ||
              LPAD(NEXTVAL('invoice_seq')::TEXT, 6, '0');

  INSERT INTO invoices (
    invoice_number, invoice_type, source_type, source_id,
    seller_name, seller_tax_number, seller_tax_office, seller_address,
    buyer_name, buyer_email,
    subtotal, kdv_rate, kdv_amount, total, currency, status
  ) VALUES (
    v_number, 'sale', 'food', NEW.id,
    COALESCE(v_merchant.name, v_company.name),
    v_company.tax_number, v_company.tax_office, v_company.address,
    COALESCE(v_user.full_name, 'Müşteri'), v_user.email,
    v_subtotal, 10.00, v_kdv_amount, NEW.total_amount, 'TRY', 'issued'
  ) RETURNING id INTO v_invoice_id;

  -- Finance entry
  INSERT INTO finance_entries (
    entry_type, category, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, merchant_id, invoice_id, payment_status
  ) VALUES (
    'income', 'Sipariş Geliri', 'Otomatik yemek faturası: ' || v_number,
    v_subtotal, 10.00, v_kdv_amount, NEW.total_amount,
    'food', NEW.id, NEW.merchant_id, v_invoice_id, 'paid'
  );

  RETURN NEW;
END;
$$;

-- ============================================================
-- 7. Grant permissions
-- ============================================================
GRANT EXECUTE ON FUNCTION get_balance_sheet(DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_profit_loss(DATE, DATE) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_kdv_summary(INT, INT) TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION get_aging_report() TO authenticated, service_role, anon;
GRANT EXECUTE ON FUNCTION generate_batch_invoices(TEXT, DATE, DATE, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION get_sector_revenue_detail(TEXT, INT) TO authenticated, service_role, anon;
