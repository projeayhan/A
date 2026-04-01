-- ============================================================
-- BANNER LIFECYCLE MIGRATION
-- Date: 2026-03-18
-- Kapsar:
--   1. Süresi dolan aktif banner'ları otomatik expired yapan
--      pg_cron job (saatlik)
--   2. 2 saatten eski pending_payment "zombi" banner'ları
--      temizleyen pg_cron job (saatlik, :30 dakikada)
--   3. Banner reddedilince ilgili finance_entry'yi 'cancelled'
--      yapan AFTER UPDATE trigger
-- ============================================================

-- pg_cron Supabase Pro/Team planlarında varsayılan olarak aktiftir.
-- Free plan kullanıyorsanız pg_cron satırlarını yorum satırı yapıp
-- expire/cleanup fonksiyonlarını Supabase Scheduled Edge Function
-- ile saatlik çağırabilirsiniz.
CREATE EXTENSION IF NOT EXISTS pg_cron SCHEMA cron;

-- ============================================================
-- 1. EXPIRE: ends_at geçmiş aktif banner'ları expired yap
-- ============================================================

CREATE OR REPLACE FUNCTION expire_active_banners()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE banners
  SET
    status     = 'expired',
    is_active  = false,
    updated_at = now()
  WHERE status = 'active'
    AND ends_at IS NOT NULL
    AND ends_at < now();
END;
$$;

-- Her saat başı (örn: 00:00, 01:00, ...)
SELECT cron.schedule(
  'expire-banners-hourly',
  '0 * * * *',
  'SELECT expire_active_banners()'
);

-- ============================================================
-- 2. CLEANUP: 2 saatten eski pending_payment zombi banner'lar
-- ============================================================

CREATE OR REPLACE FUNCTION cleanup_zombie_banners()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  DELETE FROM banners
  WHERE status = 'pending_payment'
    AND created_at < now() - INTERVAL '2 hours';
END;
$$;

-- Her saat :30'da (expire job'dan 30 dk sonra)
SELECT cron.schedule(
  'cleanup-zombie-banners',
  '30 * * * *',
  'SELECT cleanup_zombie_banners()'
);

-- ============================================================
-- 3. FINANCE ENTRY CANCEL: Banner reddedilince entry'yi iptal et
--    (silmek yerine 'cancelled' yap — audit trail korunur)
-- ============================================================

CREATE OR REPLACE FUNCTION handle_banner_rejection()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'rejected'
     AND (OLD.status IS DISTINCT FROM 'rejected') THEN

    UPDATE finance_entries
    SET
      payment_status = 'cancelled',
      notes = COALESCE(notes || ' ', '') ||
              '[Banner reddedildi' ||
              CASE
                WHEN NEW.rejection_reason IS NOT NULL AND NEW.rejection_reason <> ''
                THEN ': ' || NEW.rejection_reason
                ELSE ''
              END || ']',
      updated_at = now()
    WHERE source_type = 'banner'
      AND source_id    = NEW.id
      AND payment_status <> 'cancelled';

  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS banner_rejection_trigger ON banners;
CREATE TRIGGER banner_rejection_trigger
  AFTER UPDATE OF status ON banners
  FOR EACH ROW
  EXECUTE FUNCTION handle_banner_rejection();
