-- ============================================================
-- FİNANS HATA DÜZELTMELERİ — 2026-03-23
-- ============================================================
-- HATA 1: trg_invoice_to_finance_entry notes'a siparis_tutari yazmıyor
--          → get_finance_stats total_order_volume = 0 dönüyor
-- HATA 2: get_kdv_summary total_kdv_collected payment_status='paid' filtreliyor
--          ama sektör sorgusu filtresiz → toplam:0 sektör:16 tutarsızlığı
-- HATA 3: Mevcut 1000 TL siparişin finance_entry notes'u yanlış formatta
-- ============================================================

-- ============================================================
-- DÜZELTME 1: trg_invoice_to_finance_entry
-- Yemek/market/mağaza siparişlerinde notes'a siparis_tutari ekle
-- Taksi için sefer_tutari, kiralama için rezervasyon_tutari
-- ============================================================
CREATE OR REPLACE FUNCTION public.trg_invoice_to_finance_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_subcategory TEXT;
  v_order_amount NUMERIC;
  v_notes TEXT;
BEGIN
  -- Sadece komisyon faturaları için finance entry oluştur
  IF NEW.source_type NOT IN ('food', 'store', 'market', 'taxi', 'rental') THEN
    RETURN NEW;
  END IF;

  -- Sektöre göre subcategory belirle
  CASE NEW.source_type
    WHEN 'food'    THEN v_subcategory := 'yemek_komisyon';
    WHEN 'market'  THEN v_subcategory := 'market_komisyon';
    WHEN 'store'   THEN v_subcategory := 'magaza_komisyon';
    WHEN 'taxi'    THEN v_subcategory := 'taksi_komisyon';
    WHEN 'rental'  THEN v_subcategory := 'kiralama_komisyon';
    ELSE                v_subcategory := 'diger_komisyon';
  END CASE;

  -- Orijinal sipariş/sefer/rezervasyon tutarını bul
  CASE NEW.source_type
    WHEN 'food', 'store', 'market' THEN
      SELECT total_amount INTO v_order_amount
      FROM orders WHERE id = NEW.source_id LIMIT 1;
      v_notes :=
        'fatura_no:'   || COALESCE(NEW.invoice_number, '') ||
        '|donem:'      || COALESCE(NEW.invoice_period, '') ||
        '|isletme:'    || COALESCE(NEW.buyer_name, '') ||
        '|siparis_tutari:' || COALESCE(v_order_amount::text, '0') ||
        '|odeme_yontemi:'  || COALESCE(NEW.payment_method, 'bilinmiyor') ||
        '|komisyon_orani:' || COALESCE(
          CASE WHEN v_order_amount > 0
            THEN ROUND((NEW.subtotal / v_order_amount * 100)::NUMERIC, 2)::text
            ELSE '0'
          END, '0');
    WHEN 'taxi' THEN
      SELECT fare INTO v_order_amount
      FROM taxi_rides WHERE id = NEW.source_id LIMIT 1;
      v_notes :=
        'fatura_no:'    || COALESCE(NEW.invoice_number, '') ||
        '|donem:'       || COALESCE(NEW.invoice_period, '') ||
        '|isletme:'     || COALESCE(NEW.buyer_name, '') ||
        '|sefer_tutari:'|| COALESCE(v_order_amount::text, '0') ||
        '|odeme_yontemi:'|| COALESCE(NEW.payment_method, 'bilinmiyor');
    WHEN 'rental' THEN
      SELECT total_amount INTO v_order_amount
      FROM rental_bookings WHERE id = NEW.source_id LIMIT 1;
      v_notes :=
        'fatura_no:'           || COALESCE(NEW.invoice_number, '') ||
        '|donem:'              || COALESCE(NEW.invoice_period, '') ||
        '|isletme:'            || COALESCE(NEW.buyer_name, '') ||
        '|rezervasyon_tutari:' || COALESCE(v_order_amount::text, '0') ||
        '|odeme_yontemi:'      || COALESCE(NEW.payment_method, 'bilinmiyor');
    ELSE
      v_notes :=
        'fatura_no:' || COALESCE(NEW.invoice_number, '') ||
        '|donem:'    || COALESCE(NEW.invoice_period, '') ||
        '|isletme:'  || COALESCE(NEW.buyer_name, '');
  END CASE;

  INSERT INTO finance_entries (
    entry_type, category, subcategory, description,
    amount, kdv_rate, kdv_amount, total_amount, currency,
    source_type, source_id, merchant_id,
    payment_status, payment_method,
    created_at, due_date,
    invoice_id, notes
  ) VALUES (
    'income',
    'komisyon_geliri',
    v_subcategory,
    'Komisyon Faturası #' || COALESCE(NEW.invoice_number, '') ||
      ' - ' || COALESCE(NEW.buyer_name, '') ||
      COALESCE(' (' || NEW.invoice_period || ')', ''),
    NEW.subtotal,
    NEW.kdv_rate,
    NEW.kdv_amount,
    NEW.total,
    COALESCE(NEW.currency, 'TRY'),
    NEW.source_type,
    NEW.id,
    NEW.merchant_id,
    COALESCE(NEW.payment_status, 'pending'),
    NEW.payment_method,
    NEW.created_at,
    NEW.payment_due_date,
    NEW.id,
    v_notes
  ) ON CONFLICT DO NOTHING;

  RETURN NEW;
END;
$$;

-- ============================================================
-- DÜZELTME 2: get_kdv_summary
-- total_kdv_collected tüm income KDV'yi saymalı (accrual basis)
-- Sadece paid değil, tüm düzenlenmiş faturalar
-- Sektör ve toplam filtreleri tutarlı olmalı
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_kdv_summary(p_year integer, p_month integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_collected NUMERIC := 0;
  v_paid_kdv  NUMERIC := 0;
  v_start DATE;
  v_end   DATE;
  v_sectors JSONB;
BEGIN
  v_start := make_date(p_year, p_month, 1);
  v_end   := (v_start + INTERVAL '1 month')::date;

  -- Tahakkuk bazlı: dönemde kesilmiş tüm komisyon faturalarının KDV'si
  -- (paid + pending = toplam vergi yükümlülüğü)
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_collected
  FROM finance_entries
  WHERE entry_type = 'income'
    AND created_at::date >= v_start
    AND created_at::date < v_end;

  -- Gider KDV'si (indirilecek KDV) — sadece ödenmiş giderler
  SELECT COALESCE(SUM(kdv_amount), 0) INTO v_paid_kdv
  FROM finance_entries
  WHERE entry_type = 'expense'
    AND tax_deductible = TRUE
    AND payment_status = 'paid'
    AND created_at::date >= v_start
    AND created_at::date < v_end;

  -- Sektör bazlı dağılım — toplam ile tutarlı (ödeme filtresi yok)
  SELECT COALESCE(jsonb_agg(row_to_json(sk)::jsonb), '[]'::jsonb)
  INTO v_sectors
  FROM (
    SELECT
      source_type AS sector,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'income'
        THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2) AS kdv_collected,
      ROUND(COALESCE(SUM(CASE WHEN entry_type = 'expense' AND tax_deductible = TRUE
        THEN kdv_amount ELSE 0 END), 0)::NUMERIC, 2) AS kdv_paid,
      ROUND(AVG(CASE WHEN entry_type = 'income'
        THEN kdv_rate ELSE NULL END)::NUMERIC, 0) AS kdv_rate
    FROM finance_entries
    WHERE created_at::date >= v_start
      AND created_at::date < v_end
      AND source_type IS NOT NULL
    GROUP BY source_type
  ) sk;

  RETURN jsonb_build_object(
    'total_kdv_collected', ROUND(v_collected, 2),
    'total_kdv_paid',      ROUND(v_paid_kdv, 2),
    'net_kdv',             ROUND(v_collected - v_paid_kdv, 2),
    'sector_kdv',          v_sectors
  );
END;
$$;

-- ============================================================
-- DÜZELTME 3: Mevcut 1000 TL siparişin finance_entry notes'unu güncelle
-- finance_entry.source_id = invoice.id = '8d4fb8a2-4007-47cf-bb52-662c08a3fa30'
-- invoice.source_id = order.id = 'f9a3531e-16c2-484c-bead-ef5abfaf3aa4'
-- order.total_amount = 1000 TL, commission_rate = 10%, odeme = credit_card_on_delivery
-- ============================================================
UPDATE finance_entries
SET notes =
  'fatura_no:AYH202603-000026' ||
  '|donem:' ||
  '|isletme:Ayhan YILDIZ' ||
  '|siparis_tutari:1000.00' ||
  '|odeme_yontemi:credit_card_on_delivery' ||
  '|komisyon_orani:10.00'
WHERE id = '847db320-a06b-434a-bb59-1ce519b34a14';

-- ============================================================
-- İZİNLER
-- ============================================================
GRANT EXECUTE ON FUNCTION get_kdv_summary(integer, integer) TO authenticated, service_role, anon;
