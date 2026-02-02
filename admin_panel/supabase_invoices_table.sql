-- Invoices tablosu olusturma scripti
-- Bu scripti Supabase SQL Editor'de calistirin

CREATE TABLE IF NOT EXISTS invoices (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    customer_name VARCHAR(255) NOT NULL,
    customer_tax_number VARCHAR(50),
    customer_address TEXT,
    items JSONB NOT NULL DEFAULT '[]',
    subtotal DECIMAL(12, 2) NOT NULL DEFAULT 0,
    kdv_rate DECIMAL(5, 2) NOT NULL DEFAULT 20,
    kdv_amount DECIMAL(12, 2) NOT NULL DEFAULT 0,
    total DECIMAL(12, 2) NOT NULL DEFAULT 0,
    status VARCHAR(20) DEFAULT 'active',
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index olustur
CREATE INDEX IF NOT EXISTS idx_invoices_invoice_number ON invoices(invoice_number);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_name ON invoices(customer_name);
CREATE INDEX IF NOT EXISTS idx_invoices_created_at ON invoices(created_at DESC);

-- RLS politikasi (Row Level Security)
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;

-- Admin kullanicilari icin tam erisim
CREATE POLICY "Admin full access to invoices" ON invoices
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- Updated at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Ornek veri (istege bagli)
-- INSERT INTO invoices (invoice_number, customer_name, customer_tax_number, items, subtotal, kdv_rate, kdv_amount, total)
-- VALUES ('MNL202501-001', 'Test Musteri', '12345678901', '[{"description": "Test Hizmeti", "quantity": 1, "unit_price": 100, "total": 100}]', 100, 20, 20, 120);
