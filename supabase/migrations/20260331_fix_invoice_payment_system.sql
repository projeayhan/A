-- ============================================================
-- Fatura Ödeme Sistemi — Güvenilirlik Düzeltmeleri
-- 1. mark_invoice_paid RPC (RLS-safe, sahiplik kontrollü)
-- 2. Invoice payment → finance_entries sync trigger
-- 3. payment_reference unique index
-- ============================================================

-- ============================================================
-- 1. mark_invoice_paid RPC
-- Kullanıcılar kendi faturalarını "ödendi" olarak işaretleyebilir.
-- Sadece ödeme alanları güncellenir (tutar/durum değiştirilemez).
-- İdempotent: zaten ödenmişse hata vermez.
-- ============================================================
CREATE OR REPLACE FUNCTION mark_invoice_paid(
  p_invoice_id UUID,
  p_payment_method TEXT DEFAULT 'card',
  p_payment_note TEXT DEFAULT NULL,
  p_payment_reference TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invoice RECORD;
  v_user_id UUID := auth.uid();
  v_user_email TEXT;
  v_owns BOOLEAN := FALSE;
BEGIN
  -- Faturayı bul
  SELECT * INTO v_invoice FROM invoices WHERE id = p_invoice_id;
  IF v_invoice IS NULL THEN
    RAISE EXCEPTION 'Fatura bulunamadı';
  END IF;

  -- Zaten ödenmişse idempotent dön
  IF v_invoice.payment_status = 'paid' THEN
    RETURN TRUE;
  END IF;

  -- Sahiplik kontrolü (çoklu yol):

  -- 1. buyer_email eşleşmesi
  SELECT email INTO v_user_email FROM users WHERE id = v_user_id;
  IF v_invoice.buyer_email IS NOT NULL AND v_invoice.buyer_email = v_user_email THEN
    v_owns := TRUE;
  END IF;

  -- 2. merchant_id eşleşmesi (işletme sahibi)
  IF NOT v_owns AND v_invoice.merchant_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM merchants WHERE id = v_invoice.merchant_id AND user_id = v_user_id) THEN
      v_owns := TRUE;
    END IF;
  END IF;

  -- 3. source_id eşleşmesi (taxi sürücü veya kurye)
  IF NOT v_owns AND v_invoice.source_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM taxi_drivers WHERE id::text = v_invoice.source_id AND user_id = v_user_id) THEN
      v_owns := TRUE;
    END IF;
    IF NOT v_owns AND EXISTS (SELECT 1 FROM couriers WHERE id::text = v_invoice.source_id AND user_id = v_user_id) THEN
      v_owns := TRUE;
    END IF;
  END IF;

  -- 4. Admin ise her zaman yetki var
  IF NOT v_owns THEN
    IF EXISTS (SELECT 1 FROM admin_users WHERE user_id = v_user_id) THEN
      v_owns := TRUE;
    END IF;
  END IF;

  -- 5. Service role (webhook) her zaman geçer — auth.uid() NULL olur
  IF v_user_id IS NULL THEN
    v_owns := TRUE;
  END IF;

  IF NOT v_owns THEN
    RAISE EXCEPTION 'Bu faturayı ödeme yetkiniz yok';
  END IF;

  -- Sadece ödeme alanlarını güncelle
  UPDATE invoices SET
    payment_status = 'paid',
    paid_at = NOW(),
    paid_amount = v_invoice.total,
    payment_method = p_payment_method,
    payment_note = p_payment_note,
    payment_reference = COALESCE(p_payment_reference, payment_reference)
  WHERE id = p_invoice_id
    AND payment_status != 'paid';  -- idempotency guard

  RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION mark_invoice_paid(UUID, TEXT, TEXT, TEXT) TO authenticated, service_role, anon;

-- ============================================================
-- 2. Invoice payment_status → finance_entries sync trigger
-- Fatura ödendiğinde ilgili finance_entries kaydı da güncellenir.
-- ============================================================
CREATE OR REPLACE FUNCTION sync_invoice_payment_to_finance()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.payment_status = 'paid' AND (OLD.payment_status IS DISTINCT FROM 'paid') THEN
    UPDATE finance_entries SET
      payment_status = 'paid',
      paid_at = COALESCE(NEW.paid_at, NOW()),
      payment_method = COALESCE(NEW.payment_method, payment_method)
    WHERE invoice_id = NEW.id
      AND payment_status != 'paid';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_invoice_payment ON invoices;
CREATE TRIGGER trg_sync_invoice_payment
  AFTER UPDATE OF payment_status ON invoices
  FOR EACH ROW
  EXECUTE FUNCTION sync_invoice_payment_to_finance();

-- ============================================================
-- 3. payment_reference unique index (duplike ödeme engeli)
-- ============================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_invoices_payment_ref_unique
  ON invoices (payment_reference)
  WHERE payment_reference IS NOT NULL;

-- ============================================================
-- 4. payment_reference sütunu yoksa ekle
-- ============================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invoices' AND column_name = 'payment_reference'
  ) THEN
    ALTER TABLE invoices ADD COLUMN payment_reference VARCHAR(100);
  END IF;
END;
$$;
