-- Taksi yolculuğu tamamlandığında otomatik fatura
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
BEGIN
  -- Sadece 'completed'a geçişte çalış
  IF NEW.status != 'completed' OR OLD.status = 'completed' THEN
    RETURN NEW;
  END IF;
  -- Zaten fatura var mı?
  IF EXISTS (SELECT 1 FROM invoices WHERE source_type='taxi' AND source_id=NEW.id) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_company FROM company_settings LIMIT 1;
  SELECT full_name, email INTO v_user FROM users WHERE id = NEW.passenger_id;

  -- amount alanını taxi_rides'tan al; yoksa payments tablosundan bak
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
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_taxi_invoice
  AFTER UPDATE OF status ON taxi_rides
  FOR EACH ROW EXECUTE FUNCTION create_taxi_invoice_on_complete();

-- Yemek siparişi teslim edildiğinde otomatik fatura
CREATE OR REPLACE FUNCTION create_food_invoice_on_deliver()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_number TEXT;
  v_company RECORD;
  v_user RECORD;
  v_merchant RECORD;
  v_subtotal DECIMAL(15,2);
  v_kdv_amount DECIMAL(15,2);
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
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_food_invoice
  AFTER UPDATE OF status ON orders
  FOR EACH ROW EXECUTE FUNCTION create_food_invoice_on_deliver();
