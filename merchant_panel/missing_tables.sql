-- =====================================================
-- MISSING TABLES FOR APPROVAL FLOW
-- =====================================================

-- 1. MERCHANT DOCUMENTS
CREATE TABLE IF NOT EXISTS merchant_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    merchant_id UUID REFERENCES merchants(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL, -- 'tax_certificate', 'id_card', etc.
    url TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending', -- 'pending', 'approved', 'rejected'
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_merchant_documents_merchant ON merchant_documents(merchant_id);

-- 2. PARTNER APPLICATIONS (For Taxi & Courier)
CREATE TABLE IF NOT EXISTS partner_applications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    application_type VARCHAR(20) NOT NULL, -- 'taxi', 'courier'
    status VARCHAR(20) DEFAULT 'pending',
    full_name VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(255),
    tc_no VARCHAR(11),
    profile_photo_url TEXT,
    vehicle_type VARCHAR(50),
    vehicle_brand VARCHAR(50),
    vehicle_model VARCHAR(50),
    vehicle_year INTEGER,
    vehicle_plate VARCHAR(20),
    vehicle_color VARCHAR(30),
    reviewed_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_partner_applications_user ON partner_applications(user_id);
CREATE INDEX IF NOT EXISTS idx_partner_applications_type ON partner_applications(application_type);

-- 3. PARTNER DOCUMENTS
CREATE TABLE IF NOT EXISTS partner_documents (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    application_id UUID REFERENCES partner_applications(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    url TEXT NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    rejection_reason TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_partner_documents_application ON partner_documents(application_id);

-- 4. PARTNERS (Active Drivers/Couriers)
CREATE TABLE IF NOT EXISTS partners (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id),
    application_id UUID REFERENCES partner_applications(id),
    full_name VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(255),
    tc_no VARCHAR(11),
    profile_photo_url TEXT,
    roles TEXT[] DEFAULT '{}', -- ['taxi'], ['courier']
    active_role VARCHAR(20),
    vehicle_type VARCHAR(50),
    vehicle_brand VARCHAR(50),
    vehicle_model VARCHAR(50),
    vehicle_year INTEGER,
    vehicle_plate VARCHAR(20),
    vehicle_color VARCHAR(30),
    status VARCHAR(20) DEFAULT 'active',
    is_verified BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_partners_user ON partners(user_id);

-- RLS POLICIES

ALTER TABLE merchant_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Merchants can manage own documents" ON merchant_documents
    FOR ALL USING (merchant_id IN (SELECT id FROM merchants WHERE user_id = auth.uid()));

ALTER TABLE partner_applications ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own applications" ON partner_applications
    FOR ALL USING (auth.uid() = user_id);

ALTER TABLE partner_documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage own application documents" ON partner_documents
    FOR ALL USING (application_id IN (SELECT id FROM partner_applications WHERE user_id = auth.uid()));

ALTER TABLE partners ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Partners can view own data" ON partners
    FOR SELECT USING (auth.uid() = user_id);
