-- ============================================================
-- Sync existing orders, taxi_rides, rental_bookings into finance_entries
-- Also create triggers for future auto-sync
-- ============================================================

-- ============================================================
-- 1. Sync function: populates finance_entries from all sources
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
  v_commission_rate NUMERIC;
  v_platform_commission_rate NUMERIC := 20.00; -- Default taxi commission
  v_kdv_rate NUMERIC;
BEGIN
  -- ── ORDERS (food/store) ──
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, merchant_id, payment_status, payment_method, paid_at, created_at, due_date
  )
  SELECT
    'income',
    'siparis_geliri',
    CASE WHEN o.delivery_fee > 0 THEN 'delivery' ELSE 'pickup' END,
    'Sipariş #' || COALESCE(o.order_number, LEFT(o.id::text, 8)),
    ROUND(o.total_amount / 1.10, 2), -- amount before KDV (food: %10 KDV)
    10.00,
    ROUND(o.total_amount - (o.total_amount / 1.10), 2),
    o.total_amount,
    'food',
    o.id,
    o.merchant_id,
    CASE WHEN o.payment_status = 'paid' THEN 'paid' ELSE 'pending' END,
    o.payment_method,
    CASE WHEN o.payment_status = 'paid' THEN COALESCE(o.delivered_at, o.created_at) ELSE NULL END,
    o.created_at,
    CASE WHEN o.payment_status != 'paid' THEN (o.created_at + INTERVAL '30 days')::date ELSE NULL END
  FROM orders o
  WHERE o.status = 'delivered'
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = o.id AND fe.source_type = 'food'
    );
  GET DIAGNOSTICS v_orders_synced = ROW_COUNT;

  -- Commission expense entries for orders (platform pays merchant)
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, merchant_id, payment_status, payment_method, paid_at, created_at, due_date, tax_deductible
  )
  SELECT
    'expense',
    'merchant_odeme',
    'komisyon_sonrasi',
    'Merchant ödeme - Sipariş #' || COALESCE(o.order_number, LEFT(o.id::text, 8)),
    ROUND(o.total_amount * (1 - COALESCE(o.commission_rate, 15) / 100) / 1.10, 2),
    10.00,
    ROUND((o.total_amount * (1 - COALESCE(o.commission_rate, 15) / 100)) - (o.total_amount * (1 - COALESCE(o.commission_rate, 15) / 100) / 1.10), 2),
    ROUND(o.total_amount * (1 - COALESCE(o.commission_rate, 15) / 100), 2),
    'food',
    o.id,
    o.merchant_id,
    CASE WHEN o.payment_status = 'paid' THEN 'paid' ELSE 'pending' END,
    'bank_transfer',
    CASE WHEN o.payment_status = 'paid' THEN COALESCE(o.delivered_at, o.created_at) ELSE NULL END,
    o.created_at,
    CASE WHEN o.payment_status != 'paid' THEN (o.created_at + INTERVAL '30 days')::date ELSE NULL END,
    TRUE
  FROM orders o
  WHERE o.status = 'delivered'
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = o.id AND fe.source_type = 'food' AND fe.entry_type = 'expense'
    );

  -- ── TAXI RIDES ──
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at
  )
  SELECT
    'income',
    'taksi_geliri',
    'platform_komisyon',
    'Taksi sürüşü #' || COALESCE(t.ride_number, LEFT(t.id::text, 8)),
    ROUND(t.fare / 1.20, 2), -- KDV %20
    20.00,
    ROUND(t.fare - (t.fare / 1.20), 2),
    t.fare,
    'taxi',
    t.id,
    'paid',
    'online',
    COALESCE(t.completed_at, t.created_at),
    t.created_at
  FROM taxi_rides t
  WHERE t.status = 'completed'
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = t.id AND fe.source_type = 'taxi'
    );
  GET DIAGNOSTICS v_taxi_synced = ROW_COUNT;

  -- Taxi driver payment (expense)
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at, tax_deductible
  )
  SELECT
    'expense',
    'surucu_odeme',
    'taksi_paylasim',
    'Sürücü ödeme - Sürüş #' || COALESCE(t.ride_number, LEFT(t.id::text, 8)),
    ROUND(t.fare * 0.80 / 1.20, 2), -- Driver gets 80%, minus KDV
    20.00,
    ROUND((t.fare * 0.80) - (t.fare * 0.80 / 1.20), 2),
    ROUND(t.fare * 0.80, 2), -- Driver gets 80%
    'taxi',
    t.id,
    'paid',
    'bank_transfer',
    COALESCE(t.completed_at, t.created_at),
    t.created_at,
    TRUE
  FROM taxi_rides t
  WHERE t.status = 'completed'
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = t.id AND fe.source_type = 'taxi' AND fe.entry_type = 'expense'
    );

  -- ── RENTAL BOOKINGS ──
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at, due_date
  )
  SELECT
    'income',
    'kiralama_geliri',
    'arac_kiralama',
    'Kiralama #' || COALESCE(rb.booking_number, LEFT(rb.id::text, 8)),
    ROUND(rb.total_amount / 1.20, 2),
    20.00,
    ROUND(rb.total_amount - (rb.total_amount / 1.20), 2),
    rb.total_amount,
    'rental',
    rb.id,
    CASE WHEN rb.payment_status = 'paid' THEN 'paid' ELSE 'pending' END,
    rb.payment_method,
    CASE WHEN rb.payment_status = 'paid' THEN rb.confirmed_at ELSE NULL END,
    rb.created_at,
    CASE WHEN rb.payment_status != 'paid' THEN (rb.created_at + INTERVAL '30 days')::date ELSE NULL END
  FROM rental_bookings rb
  WHERE rb.status IN ('completed', 'confirmed', 'active')
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = rb.id AND fe.source_type = 'rental'
    );
  GET DIAGNOSTICS v_rental_synced = ROW_COUNT;

  -- Rental company payment (expense)
  INSERT INTO finance_entries (
    entry_type, category, subcategory, description, amount, kdv_rate, kdv_amount, total_amount,
    source_type, source_id, payment_status, payment_method, paid_at, created_at, due_date, tax_deductible
  )
  SELECT
    'expense',
    'sirket_odeme',
    'kiralama_paylasim',
    'Firma ödeme - Kiralama #' || COALESCE(rb.booking_number, LEFT(rb.id::text, 8)),
    ROUND(COALESCE(rb.net_amount, rb.total_amount * 0.85) / 1.20, 2),
    20.00,
    ROUND(COALESCE(rb.net_amount, rb.total_amount * 0.85) - COALESCE(rb.net_amount, rb.total_amount * 0.85) / 1.20, 2),
    COALESCE(rb.net_amount, ROUND(rb.total_amount * 0.85, 2)),
    'rental',
    rb.id,
    CASE WHEN rb.payment_status = 'paid' THEN 'paid' ELSE 'pending' END,
    'bank_transfer',
    CASE WHEN rb.payment_status = 'paid' THEN rb.confirmed_at ELSE NULL END,
    rb.created_at,
    CASE WHEN rb.payment_status != 'paid' THEN (rb.created_at + INTERVAL '30 days')::date ELSE NULL END,
    TRUE
  FROM rental_bookings rb
  WHERE rb.status IN ('completed', 'confirmed', 'active')
    AND NOT EXISTS (
      SELECT 1 FROM finance_entries fe WHERE fe.source_id = rb.id AND fe.source_type = 'rental' AND fe.entry_type = 'expense'
    );

  RETURN jsonb_build_object(
    'orders_synced', v_orders_synced,
    'taxi_synced', v_taxi_synced,
    'rental_synced', v_rental_synced,
    'total_synced', v_orders_synced + v_taxi_synced + v_rental_synced
  );
END;
$$;

GRANT EXECUTE ON FUNCTION sync_all_finance_entries() TO authenticated, service_role;

-- ============================================================
-- 2. Trigger functions for auto-sync
-- ============================================================

-- Order delivered → create finance entry
CREATE OR REPLACE FUNCTION trg_order_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'delivered' AND (OLD.status IS NULL OR OLD.status != 'delivered') THEN
    -- Income
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

    -- Expense (merchant payment)
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

-- Taxi ride completed → create finance entry
CREATE OR REPLACE FUNCTION trg_taxi_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'completed' AND (OLD.status IS NULL OR OLD.status != 'completed') THEN
    -- Income
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

    -- Expense (driver payment 80%)
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

-- Rental booking completed → create finance entry
CREATE OR REPLACE FUNCTION trg_rental_finance_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status IN ('completed', 'confirmed') AND (OLD.status IS NULL OR OLD.status NOT IN ('completed', 'confirmed')) THEN
    -- Income
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

    -- Expense (company payment)
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
-- 3. Run the sync now to populate existing data
-- ============================================================
SELECT sync_all_finance_entries();
