-- Eski invoices tablosunu kaldır (farklı şemada mevcut)
DROP TABLE IF EXISTS invoices CASCADE;

-- Sıralı fatura numarası için sequence
CREATE SEQUENCE IF NOT EXISTS invoice_seq START 1;

-- Şirket/platform ayarları tablosu (hardcoded bilgileri buraya taşı)
CREATE TABLE IF NOT EXISTS company_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(200) NOT NULL,
  address TEXT NOT NULL,
  phone VARCHAR(20),
  email VARCHAR(100),
  tax_office VARCHAR(100) NOT NULL,
  tax_number VARCHAR(50) NOT NULL,
  website VARCHAR(100),
  invoice_prefix VARCHAR(10) DEFAULT 'ODB',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- İlk kayıt — tax_number'ı gerçek vergi numarasıyla doldur
INSERT INTO company_settings (name, address, phone, email, tax_office, tax_number, website, invoice_prefix)
VALUES (
  'SuperCyp Teknoloji A.Ş.',
  'Levent Mah. Büyükdere Cad. No:123, 34394 Şişli/İstanbul',
  '+90 212 555 00 00',
  'fatura@supercyp.com',
  'Beşiktaş Vergi Dairesi',
  'GERÇEK_VERGİ_NUMARASI_GİR',
  'www.supercyp.com',
  'ODB'
) ON CONFLICT DO NOTHING;

-- Sequence'ten numara üreten fonksiyon
CREATE OR REPLACE FUNCTION get_next_invoice_number()
RETURNS TEXT LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_prefix TEXT;
  v_seq BIGINT;
BEGIN
  SELECT invoice_prefix INTO v_prefix FROM company_settings LIMIT 1;
  v_seq := NEXTVAL('invoice_seq');
  RETURN v_prefix || TO_CHAR(NOW(), 'YYYYMM') || '-' || LPAD(v_seq::TEXT, 6, '0');
END;
$$;

-- Ana faturalar tablosu
CREATE TABLE invoices (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_number VARCHAR(30) UNIQUE NOT NULL,
  invoice_type VARCHAR(20) NOT NULL DEFAULT 'sale', -- 'sale' | 'refund' | 'proforma'
  source_type VARCHAR(20) NOT NULL,                 -- 'taxi' | 'food' | 'store' | 'rental'
  source_id UUID,
  parent_invoice_id UUID REFERENCES invoices(id),   -- iade faturalarında orijinal fatura
  seller_name VARCHAR(200) NOT NULL,
  seller_tax_number VARCHAR(50) NOT NULL,
  seller_tax_office VARCHAR(100),
  seller_address TEXT,
  buyer_name VARCHAR(200),
  buyer_tax_number VARCHAR(50),
  buyer_address TEXT,
  buyer_email VARCHAR(100),
  subtotal DECIMAL(15,2) NOT NULL,
  kdv_rate DECIMAL(5,2) NOT NULL,
  kdv_amount DECIMAL(15,2) NOT NULL,
  total DECIMAL(15,2) NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'TRY',
  status VARCHAR(20) NOT NULL DEFAULT 'issued',     -- 'issued' | 'sent' | 'cancelled'
  cancelled_at TIMESTAMPTZ,
  cancel_reason TEXT,
  sent_at TIMESTAMPTZ,
  gib_uuid VARCHAR(50),
  gib_status VARCHAR(20),
  gib_submitted_at TIMESTAMPTZ,
  pdf_url TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invoices_source ON invoices(source_type, source_id);
CREATE INDEX idx_invoices_buyer_email ON invoices(buyer_email);
CREATE INDEX idx_invoices_created_at ON invoices(created_at DESC);
CREATE INDEX idx_invoices_status ON invoices(status);
CREATE INDEX idx_invoices_number ON invoices(invoice_number);

-- Fatura kalemleri
CREATE TABLE invoice_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invoice_id UUID NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  unit_price DECIMAL(15,2) NOT NULL,
  kdv_rate DECIMAL(5,2) NOT NULL DEFAULT 20.00,
  total DECIMAL(15,2) NOT NULL,
  sort_order INTEGER DEFAULT 0
);

CREATE INDEX idx_invoice_items_invoice ON invoice_items(invoice_id);

ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins can manage invoices" ON invoices
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Admins can manage invoice items" ON invoice_items
  FOR ALL USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Users can view own invoices" ON invoices
  FOR SELECT USING (
    buyer_email = (SELECT email FROM users WHERE id = auth.uid())
  );
