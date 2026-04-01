-- ============================================================
-- Otomatik Aylık Fatura Oluşturma
-- 1. company_settings'e otomatik fatura ayarları
-- 2. generate_monthly_invoices() RPC
-- 3. pg_cron job (her gün 00:01)
-- ============================================================

-- 1. Yeni ayar alanları
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='company_settings' AND column_name='auto_invoice_enabled') THEN
    ALTER TABLE company_settings ADD COLUMN auto_invoice_enabled BOOLEAN NOT NULL DEFAULT false;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='company_settings' AND column_name='auto_invoice_day') THEN
    ALTER TABLE company_settings ADD COLUMN auto_invoice_day INT NOT NULL DEFAULT 1;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='company_settings' AND column_name='last_auto_invoice_date') THEN
    ALTER TABLE company_settings ADD COLUMN last_auto_invoice_date DATE;
  END IF;
END;
$$;

-- 2. Ana fonksiyon
CREATE OR REPLACE FUNCTION generate_monthly_invoices()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_enabled BOOLEAN;
  v_day INT;
  v_last_date DATE;
  v_start_date TIMESTAMPTZ;
  v_end_date TIMESTAMPTZ;
  v_target_month DATE;
  v_period TEXT;
  v_kdv_rate NUMERIC;
  v_company RECORD;
  v_sectors TEXT[] := ARRAY['food', 'store', 'market', 'taxi', 'rental'];
  v_sector TEXT;
  v_previews JSONB;
  v_preview JSONB;
  v_merchant_id TEXT;
  v_merchant_name TEXT;
  v_subtotal NUMERIC;
  v_kdv_amount NUMERIC;
  v_total NUMERIC;
  v_online_total NUMERIC;
  v_cash_total NUMERIC;
  v_inv_number TEXT;
  v_inv_id UUID;
  v_order_details JSONB;
  v_order JSONB;
  v_total_created INT := 0;
  v_total_skipped INT := 0;
  v_total_failed INT := 0;
  v_errors TEXT[] := ARRAY[]::TEXT[];
BEGIN
  -- Advisory lock — concurrent çalışma engeli
  IF NOT pg_try_advisory_lock(987654321) THEN
    RETURN jsonb_build_object('status', 'skipped', 'reason', 'Already running');
  END IF;

  -- Ayarları oku
  SELECT auto_invoice_enabled, auto_invoice_day, last_auto_invoice_date,
         name, address, phone, email, tax_office, tax_number
  INTO v_enabled, v_day, v_last_date,
       v_company.name, v_company.address, v_company.phone, v_company.email,
       v_company.tax_office, v_company.tax_number
  FROM company_settings LIMIT 1;

  -- Otomatik fatura kapalı mı?
  IF NOT v_enabled THEN
    PERFORM pg_advisory_unlock(987654321);
    RETURN jsonb_build_object('status', 'disabled');
  END IF;

  -- Bugün doğru gün mü?
  IF EXTRACT(DAY FROM CURRENT_DATE) != v_day THEN
    PERFORM pg_advisory_unlock(987654321);
    RETURN jsonb_build_object('status', 'not_today', 'today', EXTRACT(DAY FROM CURRENT_DATE), 'target_day', v_day);
  END IF;

  -- Bu ay zaten kesilmiş mi?
  v_target_month := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month')::DATE;
  IF v_last_date IS NOT NULL AND v_last_date >= v_target_month THEN
    PERFORM pg_advisory_unlock(987654321);
    RETURN jsonb_build_object('status', 'already_generated', 'last_date', v_last_date, 'target_month', v_target_month);
  END IF;

  -- Önceki ayın tarih aralığı
  v_start_date := DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month');
  v_end_date := DATE_TRUNC('month', CURRENT_DATE) - INTERVAL '1 second';
  v_period := TO_CHAR(v_start_date, 'DD.MM.YYYY') || ' - ' || TO_CHAR(v_end_date, 'DD.MM.YYYY');

  -- Platform KDV oranı
  v_kdv_rate := get_platform_kdv_rate();

  -- Log başlangıç
  INSERT INTO app_logs (app_name, level, message, source, metadata)
  VALUES ('system', 'info', 'Otomatik fatura oluşturma başladı', 'auto_invoice',
    jsonb_build_object('period', v_period, 'kdv_rate', v_kdv_rate, 'sectors', to_jsonb(v_sectors)));

  -- Her sektörü dolaş
  FOREACH v_sector IN ARRAY v_sectors
  LOOP
    BEGIN
      -- Preview al
      v_previews := get_batch_invoice_preview(v_sector, v_start_date, v_end_date);

      IF v_previews IS NULL OR jsonb_array_length(v_previews) = 0 THEN
        CONTINUE;
      END IF;

      -- Her merchant için fatura oluştur
      FOR v_preview IN SELECT * FROM jsonb_array_elements(v_previews)
      LOOP
        BEGIN
          v_merchant_id := v_preview->>'merchant_id';
          v_merchant_name := v_preview->>'merchant_name';
          v_subtotal := (v_preview->>'subtotal')::NUMERIC;
          v_online_total := COALESCE((v_preview->>'online_total')::NUMERIC, 0);
          v_cash_total := COALESCE((v_preview->>'cash_total')::NUMERIC, 0);

          -- Subtotal 0 veya negatifse atla
          IF v_subtotal <= 0 THEN
            v_total_skipped := v_total_skipped + 1;
            CONTINUE;
          END IF;

          -- Bu merchant + bu dönem için zaten fatura var mı?
          IF EXISTS (
            SELECT 1 FROM invoices
            WHERE (merchant_id::text = v_merchant_id OR source_id = v_merchant_id)
              AND invoice_period = v_period
              AND invoice_type = 'batch_commission'
          ) THEN
            v_total_skipped := v_total_skipped + 1;
            CONTINUE;
          END IF;

          -- KDV hesapla
          v_kdv_amount := ROUND(v_subtotal * v_kdv_rate, 2);
          v_total := ROUND(v_subtotal + v_kdv_amount, 2);

          -- Fatura numarası al
          v_inv_number := get_next_invoice_number();

          -- Merchant bilgilerini çek
          DECLARE
            v_buyer_email TEXT;
            v_buyer_tax TEXT;
            v_buyer_addr TEXT;
            v_buyer_phone TEXT;
          BEGIN
            -- merchants tablosundan dene
            SELECT email, tax_number, address, phone
            INTO v_buyer_email, v_buyer_tax, v_buyer_addr, v_buyer_phone
            FROM merchants WHERE id::text = v_merchant_id;

            -- Bulunamadıysa diğer tablolardan dene
            IF v_buyer_email IS NULL THEN
              SELECT u.email INTO v_buyer_email
              FROM taxi_drivers td JOIN auth.users u ON u.id = td.user_id
              WHERE td.id::text = v_merchant_id;
            END IF;
            IF v_buyer_email IS NULL THEN
              SELECT u.email INTO v_buyer_email
              FROM couriers c JOIN auth.users u ON u.id = c.user_id
              WHERE c.id::text = v_merchant_id;
            END IF;

            -- Fatura oluştur
            INSERT INTO invoices (
              id, invoice_number, invoice_type, source_type, source_id, merchant_id,
              seller_name, seller_tax_number, seller_tax_office, seller_address,
              buyer_name, buyer_email, buyer_tax_number, buyer_address,
              subtotal, kdv_rate, kdv_amount, total,
              status, payment_status, payment_due_date, invoice_period, created_at
            ) VALUES (
              gen_random_uuid(), v_inv_number, 'batch_commission', 'merchant_commission', v_merchant_id,
              CASE WHEN EXISTS (SELECT 1 FROM merchants WHERE id::text = v_merchant_id) THEN v_merchant_id::uuid ELSE NULL END,
              v_company.name, v_company.tax_number, v_company.tax_office, v_company.address,
              v_merchant_name, v_buyer_email, v_buyer_tax, v_buyer_addr,
              v_subtotal, v_kdv_rate * 100, v_kdv_amount, v_total,
              'issued', 'pending',
              (CURRENT_DATE + INTERVAL '30 days')::date,
              v_period, NOW()
            )
            RETURNING id INTO v_inv_id;

            -- Sipariş detaylarını çek ve kalem olarak ekle
            v_order_details := get_batch_invoice_order_details(v_sector, v_merchant_id, v_start_date, v_end_date);

            IF v_order_details IS NOT NULL AND jsonb_array_length(v_order_details) > 0 THEN
              DECLARE
                v_sort INT := 0;
              BEGIN
                FOR v_order IN SELECT * FROM jsonb_array_elements(v_order_details)
                LOOP
                  v_sort := v_sort + 1;
                  INSERT INTO invoice_items (invoice_id, description, quantity, unit_price, kdv_rate, total, sort_order)
                  VALUES (
                    v_inv_id,
                    COALESCE(v_order->>'order_number', 'Sipariş') || ' (' ||
                      CASE
                        WHEN (v_order->>'payment_method') IN ('online','stripe','credit_card_online') THEN 'Online'
                        WHEN (v_order->>'payment_method') = 'cash' THEN 'Nakit'
                        WHEN (v_order->>'payment_method') = 'credit_card_on_delivery' THEN 'Kapıda Kart'
                        ELSE COALESCE(v_order->>'payment_method', '')
                      END || ')',
                    1,
                    COALESCE((v_order->>'total_amount')::NUMERIC, 0),
                    v_kdv_rate * 100,
                    COALESCE((v_order->>'commission_amount')::NUMERIC, 0),
                    v_sort
                  );
                END LOOP;
              END;
            END IF;

            v_total_created := v_total_created + 1;
          END;

        EXCEPTION WHEN OTHERS THEN
          v_total_failed := v_total_failed + 1;
          v_errors := array_append(v_errors, v_sector || '/' || v_merchant_name || ': ' || SQLERRM);
        END;
      END LOOP;

    EXCEPTION WHEN OTHERS THEN
      v_total_failed := v_total_failed + 1;
      v_errors := array_append(v_errors, v_sector || ': ' || SQLERRM);
    END;
  END LOOP;

  -- last_auto_invoice_date güncelle
  IF v_total_created > 0 THEN
    UPDATE company_settings SET last_auto_invoice_date = CURRENT_DATE;
  END IF;

  -- Sonuç logla
  INSERT INTO app_logs (app_name, level, message, source, metadata)
  VALUES ('system',
    CASE WHEN v_total_failed > 0 THEN 'warning' ELSE 'info' END,
    'Otomatik fatura tamamlandı: ' || v_total_created || ' oluşturuldu, ' || v_total_skipped || ' atlandı, ' || v_total_failed || ' hata',
    'auto_invoice',
    jsonb_build_object(
      'created', v_total_created, 'skipped', v_total_skipped, 'failed', v_total_failed,
      'period', v_period, 'errors', to_jsonb(v_errors)
    )
  );

  PERFORM pg_advisory_unlock(987654321);

  RETURN jsonb_build_object(
    'status', 'completed',
    'created', v_total_created,
    'skipped', v_total_skipped,
    'failed', v_total_failed,
    'period', v_period,
    'errors', to_jsonb(v_errors)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION generate_monthly_invoices() TO service_role;

-- 3. pg_cron job — her gün 00:01'de çalışır, fonksiyon gün kontrolü yapar
SELECT cron.schedule('auto-monthly-invoices', '1 0 * * *', 'SELECT generate_monthly_invoices()');
