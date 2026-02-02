-- =====================================================
-- MERCHANT PANEL - SUPABASE TABLOLARI
-- =====================================================
-- Bu scripti Supabase SQL Editor'de calistirin
-- =====================================================

-- =====================================================
-- 1. MERCHANTS (Isletmeler) TABLOSU
-- =====================================================
CREATE TABLE IF NOT EXISTS merchants (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('restaurant', 'store')),
    business_id VARCHAR(50),
    business_name VARCHAR(255) NOT NULL,
    logo_url TEXT,
    cover_url TEXT,
    phone VARCHAR(20),
    email VARCHAR(255),
    address TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    rating DECIMAL(2, 1) DEFAULT 0,
    total_orders INTEGER DEFAULT 0,
    total_reviews INTEGER DEFAULT 0,
    is_open BOOLEAN DEFAULT true,
    is_approved BOOLEAN DEFAULT false,
    commission_rate DECIMAL(5, 2) DEFAULT 15.00,
    min_order_amount DECIMAL(10, 2) DEFAULT 0,
    delivery_fee DECIMAL(10, 2) DEFAULT 0,
    free_delivery_threshold DECIMAL(10, 2),
    avg_preparation_time INTEGER DEFAULT 30,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_merchants_user_id ON merchants(user_id);
CREATE INDEX idx_merchants_type ON merchants(type);
CREATE INDEX idx_merchants_is_approved ON merchants(is_approved);

-- =====================================================
-- 2. MERCHANT_WORKING_HOURS (Calisma Saatleri)
-- =====================================================
CREATE TABLE IF NOT EXISTS merchant_working_hours (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    day_of_week INTEGER NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    is_open BOOLEAN DEFAULT true,
    open_time TIME,
    close_time TIME,
    UNIQUE(merchant_id, day_of_week)
);

-- =====================================================
-- 3. MENU_CATEGORIES (Menu Kategorileri - Restaurant)
-- =====================================================
CREATE TABLE IF NOT EXISTS menu_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    image_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_menu_categories_merchant ON menu_categories(merchant_id);

-- =====================================================
-- 4. MENU_ITEMS (Menu Urunleri - Restaurant)
-- =====================================================
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    category_id UUID REFERENCES menu_categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    discounted_price DECIMAL(10, 2),
    image_url TEXT,
    preparation_time INTEGER DEFAULT 15,
    is_available BOOLEAN DEFAULT true,
    is_popular BOOLEAN DEFAULT false,
    options JSONB,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_menu_items_merchant ON menu_items(merchant_id);
CREATE INDEX idx_menu_items_category ON menu_items(category_id);

-- =====================================================
-- 5. STORE_CATEGORIES (Magaza Kategorileri)
-- =====================================================
CREATE TABLE IF NOT EXISTS store_categories (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    image_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_store_categories_merchant ON store_categories(merchant_id);

-- =====================================================
-- 6. STORE_PRODUCTS (Magaza Urunleri)
-- =====================================================
CREATE TABLE IF NOT EXISTS store_products (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    category_id UUID REFERENCES store_categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    original_price DECIMAL(10, 2),
    image_url TEXT,
    images JSONB,
    sku VARCHAR(50),
    stock INTEGER DEFAULT 0,
    low_stock_threshold INTEGER DEFAULT 5,
    sold_count INTEGER DEFAULT 0,
    rating DECIMAL(2, 1) DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    is_available BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    variants JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_store_products_merchant ON store_products(merchant_id);
CREATE INDEX idx_store_products_category ON store_products(category_id);
CREATE INDEX idx_store_products_sku ON store_products(sku);

-- =====================================================
-- 7. ORDERS (Siparisler)
-- =====================================================
CREATE TABLE IF NOT EXISTS orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_number VARCHAR(20) UNIQUE NOT NULL,
    user_id UUID REFERENCES auth.users(id),
    merchant_id UUID REFERENCES merchants(id),
    courier_id UUID,
    items JSONB NOT NULL DEFAULT '[]',
    subtotal DECIMAL(10, 2) NOT NULL DEFAULT 0,
    delivery_fee DECIMAL(10, 2) DEFAULT 0,
    service_fee DECIMAL(10, 2) DEFAULT 0,
    discount_amount DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(10, 2) NOT NULL DEFAULT 0,
    delivery_address TEXT NOT NULL,
    delivery_latitude DECIMAL(10, 8),
    delivery_longitude DECIMAL(11, 8),
    delivery_instructions TEXT,
    payment_method VARCHAR(20) DEFAULT 'card',
    payment_status VARCHAR(20) DEFAULT 'pending',
    status VARCHAR(20) DEFAULT 'pending',
    estimated_delivery_time TIMESTAMP WITH TIME ZONE,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    prepared_at TIMESTAMP WITH TIME ZONE,
    picked_up_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    cancellation_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_orders_merchant ON orders(merchant_id);
CREATE INDEX idx_orders_user ON orders(user_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);

-- =====================================================
-- 8. REVIEWS (Degerlendirmeler)
-- =====================================================
CREATE TABLE IF NOT EXISTS reviews (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID REFERENCES orders(id) ON DELETE CASCADE,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id),
    rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    merchant_reply TEXT,
    replied_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_reviews_merchant ON reviews(merchant_id);
CREATE INDEX idx_reviews_user ON reviews(user_id);

-- =====================================================
-- 9. MERCHANT_TRANSACTIONS (Finansal Islemler)
-- =====================================================
CREATE TABLE IF NOT EXISTS merchant_transactions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    order_id UUID REFERENCES orders(id),
    type VARCHAR(20) NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    commission_amount DECIMAL(10, 2) DEFAULT 0,
    net_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'completed',
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_merchant_transactions_merchant ON merchant_transactions(merchant_id);
CREATE INDEX idx_merchant_transactions_created_at ON merchant_transactions(created_at DESC);

-- =====================================================
-- 10. MERCHANT_PAYOUTS (Odeme Transferleri)
-- =====================================================
CREATE TABLE IF NOT EXISTS merchant_payouts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    bank_name VARCHAR(100),
    iban VARCHAR(50),
    reference_number VARCHAR(50),
    processed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_merchant_payouts_merchant ON merchant_payouts(merchant_id);

-- =====================================================
-- 11. STOCK_MOVEMENTS (Stok Hareketleri - Store)
-- =====================================================
CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    product_id UUID REFERENCES store_products(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('in', 'out', 'adjustment')),
    quantity INTEGER NOT NULL,
    previous_stock INTEGER,
    new_stock INTEGER,
    reference_type VARCHAR(50),
    reference_id UUID,
    note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_stock_movements_merchant ON stock_movements(merchant_id);
CREATE INDEX idx_stock_movements_product ON stock_movements(product_id);

-- =====================================================
-- 12. MERCHANT_NOTIFICATIONS (Bildirimler)
-- =====================================================
CREATE TABLE IF NOT EXISTS merchant_notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_merchant_notifications_merchant ON merchant_notifications(merchant_id);
CREATE INDEX idx_merchant_notifications_is_read ON merchant_notifications(is_read);

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLITIKALARI
-- =====================================================

-- Merchants RLS
ALTER TABLE merchants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert own merchant" ON merchants
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Merchants can view own data" ON merchants
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Merchants can update own data" ON merchants
    FOR UPDATE USING (auth.uid() = user_id);

-- Orders RLS
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Merchants can view own orders" ON orders
    FOR SELECT USING (
        merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
    );

CREATE POLICY "Merchants can update own orders" ON orders
    FOR UPDATE USING (
        merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
    );

-- Menu Items RLS
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Merchants can manage own menu" ON menu_items
    FOR ALL USING (
        merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
    );

-- Store Products RLS
ALTER TABLE store_products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Merchants can manage own products" ON store_products
    FOR ALL USING (
        merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
    );

-- Reviews RLS
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Merchants can view own reviews" ON reviews
    FOR SELECT USING (
        merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
    );

CREATE POLICY "Merchants can reply to reviews" ON reviews
    FOR UPDATE USING (
        merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid())
    );

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Updated At Trigger Function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply to tables
CREATE TRIGGER update_merchants_updated_at
    BEFORE UPDATE ON merchants
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_store_products_updated_at
    BEFORE UPDATE ON store_products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =====================================================
-- ORNEK VERI (Test icin - istege bagli)
-- =====================================================
/*
-- Ornek Restaurant
INSERT INTO merchants (user_id, type, business_name, phone, address, is_approved, is_open)
VALUES (
    '00000000-0000-0000-0000-000000000001',
    'restaurant',
    'Lezzet Duragi',
    '+90 532 123 4567',
    'Ataturk Cad. No:123, Kadikoy, Istanbul',
    true,
    true
);

-- Ornek Store
INSERT INTO merchants (user_id, type, business_name, phone, address, is_approved, is_open)
VALUES (
    '00000000-0000-0000-0000-000000000002',
    'store',
    'Tech Store',
    '+90 533 987 6543',
    'Istiklal Cad. No:456, Beyoglu, Istanbul',
    true,
    true
);
*/
