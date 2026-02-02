-- =====================================================
-- SECURE COMMUNICATION SYSTEM FOR TAXI APP
-- Güvenli İletişim Sistemi - Sürücü/Müşteri Koruma
-- =====================================================

-- =====================================================
-- 1. RIDE COMMUNICATIONS - Yolculuk İçi Mesajlaşma
-- =====================================================
CREATE TABLE IF NOT EXISTS ride_communications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES taxi_rides(id) ON DELETE CASCADE,
    sender_type VARCHAR(20) NOT NULL CHECK (sender_type IN ('driver', 'customer')),
    sender_id UUID NOT NULL REFERENCES auth.users(id),
    message_type VARCHAR(20) NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'location', 'quick_message', 'system')),
    content TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_ride_communications_ride_id ON ride_communications(ride_id);
CREATE INDEX IF NOT EXISTS idx_ride_communications_created_at ON ride_communications(created_at);

-- =====================================================
-- 2. RIDE CALLS - Proxy Arama Kayıtları
-- =====================================================
CREATE TABLE IF NOT EXISTS ride_calls (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES taxi_rides(id) ON DELETE CASCADE,
    caller_type VARCHAR(20) NOT NULL CHECK (caller_type IN ('driver', 'customer')),
    caller_id UUID NOT NULL REFERENCES auth.users(id),
    call_status VARCHAR(20) NOT NULL DEFAULT 'initiated' CHECK (call_status IN ('initiated', 'connected', 'completed', 'missed', 'rejected')),
    duration_seconds INTEGER DEFAULT 0,
    proxy_number VARCHAR(20), -- Geçici proxy numara (eğer kullanılıyorsa)
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_ride_calls_ride_id ON ride_calls(ride_id);

-- =====================================================
-- 3. EMERGENCY ALERTS - Acil Durum Uyarıları
-- =====================================================
CREATE TABLE IF NOT EXISTS emergency_alerts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID REFERENCES taxi_rides(id) ON DELETE SET NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('driver', 'customer')),
    alert_type VARCHAR(30) NOT NULL CHECK (alert_type IN ('sos', 'accident', 'threat', 'medical', 'other')),
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'responded', 'resolved', 'false_alarm')),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    description TEXT,
    responder_notes TEXT,
    responded_by UUID REFERENCES auth.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    responded_at TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_emergency_alerts_status ON emergency_alerts(status);
CREATE INDEX IF NOT EXISTS idx_emergency_alerts_created_at ON emergency_alerts(created_at);

-- =====================================================
-- 4. RIDE SHARE LINKS - Yolculuk Paylaşım Linkleri
-- =====================================================
CREATE TABLE IF NOT EXISTS ride_share_links (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES taxi_rides(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    share_token VARCHAR(64) NOT NULL UNIQUE,
    recipient_name VARCHAR(100),
    recipient_phone VARCHAR(20),
    is_active BOOLEAN DEFAULT TRUE,
    view_count INTEGER DEFAULT 0,
    last_viewed_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB DEFAULT '{}'
);

CREATE INDEX IF NOT EXISTS idx_ride_share_links_token ON ride_share_links(share_token);
CREATE INDEX IF NOT EXISTS idx_ride_share_links_ride_id ON ride_share_links(ride_id);

-- =====================================================
-- 5. MASKED CONTACT INFO - Maskelenmiş İletişim
-- =====================================================
CREATE TABLE IF NOT EXISTS masked_contacts (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID NOT NULL REFERENCES taxi_rides(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id),
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('driver', 'customer')),
    masked_phone VARCHAR(20), -- Örn: +90 5** *** *789
    display_name VARCHAR(100), -- Maskelenmiş veya sadece isim
    is_phone_visible BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(ride_id, user_type)
);

CREATE INDEX IF NOT EXISTS idx_masked_contacts_ride_id ON masked_contacts(ride_id);

-- =====================================================
-- 6. COMMUNICATION PREFERENCES - İletişim Tercihleri
-- =====================================================
CREATE TABLE IF NOT EXISTS communication_preferences (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    allow_calls BOOLEAN DEFAULT TRUE,
    allow_messages BOOLEAN DEFAULT TRUE,
    share_phone_with_driver BOOLEAN DEFAULT FALSE,
    share_phone_with_customer BOOLEAN DEFAULT FALSE,
    auto_share_ride_enabled BOOLEAN DEFAULT FALSE,
    emergency_contacts JSONB DEFAULT '[]', -- [{name, phone, relationship}]
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- =====================================================
-- 7. COMMUNICATION LOG - Tüm İletişim Kayıtları (Audit)
-- =====================================================
CREATE TABLE IF NOT EXISTS communication_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    ride_id UUID REFERENCES taxi_rides(id) ON DELETE SET NULL,
    action_type VARCHAR(30) NOT NULL, -- 'call_initiated', 'message_sent', 'emergency_triggered', etc.
    actor_id UUID NOT NULL REFERENCES auth.users(id),
    actor_type VARCHAR(20) NOT NULL CHECK (actor_type IN ('driver', 'customer', 'system', 'admin')),
    details JSONB DEFAULT '{}',
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_communication_logs_ride_id ON communication_logs(ride_id);
CREATE INDEX IF NOT EXISTS idx_communication_logs_created_at ON communication_logs(created_at);

-- =====================================================
-- ROW LEVEL SECURITY POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE ride_communications ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_calls ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ride_share_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE masked_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE communication_logs ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RIDE_COMMUNICATIONS RLS
-- =====================================================

-- Kullanıcılar sadece kendi yolculuklarındaki mesajları görebilir
DROP POLICY IF EXISTS "Users can view messages in their rides" ON ride_communications;
CREATE POLICY "Users can view messages in their rides" ON ride_communications
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = ride_communications.ride_id
            AND (r.user_id = auth.uid() OR r.driver_id IN (
                SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
            ))
        )
    );

-- Kullanıcılar kendi yolculuklarına mesaj gönderebilir
DROP POLICY IF EXISTS "Users can send messages in their rides" ON ride_communications;
CREATE POLICY "Users can send messages in their rides" ON ride_communications
    FOR INSERT WITH CHECK (
        sender_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = ride_communications.ride_id
            AND r.status IN ('accepted', 'arrived', 'in_progress')
            AND (r.user_id = auth.uid() OR r.driver_id IN (
                SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
            ))
        )
    );

-- =====================================================
-- RIDE_CALLS RLS
-- =====================================================

DROP POLICY IF EXISTS "Users can view calls in their rides" ON ride_calls;
CREATE POLICY "Users can view calls in their rides" ON ride_calls
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = ride_calls.ride_id
            AND (r.user_id = auth.uid() OR r.driver_id IN (
                SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
            ))
        )
    );

DROP POLICY IF EXISTS "Users can initiate calls in their rides" ON ride_calls;
CREATE POLICY "Users can initiate calls in their rides" ON ride_calls
    FOR INSERT WITH CHECK (
        caller_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = ride_calls.ride_id
            AND r.status IN ('accepted', 'arrived', 'in_progress')
            AND (r.user_id = auth.uid() OR r.driver_id IN (
                SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
            ))
        )
    );

-- =====================================================
-- EMERGENCY_ALERTS RLS
-- =====================================================

DROP POLICY IF EXISTS "Users can view their own alerts" ON emergency_alerts;
CREATE POLICY "Users can view their own alerts" ON emergency_alerts
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create emergency alerts" ON emergency_alerts;
CREATE POLICY "Users can create emergency alerts" ON emergency_alerts
    FOR INSERT WITH CHECK (user_id = auth.uid());

-- =====================================================
-- RIDE_SHARE_LINKS RLS
-- =====================================================

DROP POLICY IF EXISTS "Users can view their own share links" ON ride_share_links;
CREATE POLICY "Users can view their own share links" ON ride_share_links
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create share links for their rides" ON ride_share_links;
CREATE POLICY "Users can create share links for their rides" ON ride_share_links
    FOR INSERT WITH CHECK (
        user_id = auth.uid() AND
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = ride_share_links.ride_id
            AND r.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Users can update their own share links" ON ride_share_links;
CREATE POLICY "Users can update their own share links" ON ride_share_links
    FOR UPDATE USING (user_id = auth.uid());

-- =====================================================
-- MASKED_CONTACTS RLS
-- =====================================================

DROP POLICY IF EXISTS "Users can view masked contacts in their rides" ON masked_contacts;
CREATE POLICY "Users can view masked contacts in their rides" ON masked_contacts
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = masked_contacts.ride_id
            AND (r.user_id = auth.uid() OR r.driver_id IN (
                SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
            ))
        )
    );

-- =====================================================
-- COMMUNICATION_PREFERENCES RLS
-- =====================================================

DROP POLICY IF EXISTS "Users can view own preferences" ON communication_preferences;
CREATE POLICY "Users can view own preferences" ON communication_preferences
    FOR SELECT USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert own preferences" ON communication_preferences;
CREATE POLICY "Users can insert own preferences" ON communication_preferences
    FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own preferences" ON communication_preferences;
CREATE POLICY "Users can update own preferences" ON communication_preferences
    FOR UPDATE USING (user_id = auth.uid());

-- =====================================================
-- COMMUNICATION_LOGS RLS (Read-only for users)
-- =====================================================

DROP POLICY IF EXISTS "Users can view their own logs" ON communication_logs;
CREATE POLICY "Users can view their own logs" ON communication_logs
    FOR SELECT USING (actor_id = auth.uid() OR
        EXISTS (
            SELECT 1 FROM taxi_rides r
            WHERE r.id = communication_logs.ride_id
            AND (r.user_id = auth.uid() OR r.driver_id IN (
                SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
            ))
        )
    );

-- =====================================================
-- SERVICE ROLE POLICIES (for Edge Functions)
-- =====================================================

DROP POLICY IF EXISTS "Service role full access ride_communications" ON ride_communications;
CREATE POLICY "Service role full access ride_communications" ON ride_communications
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access ride_calls" ON ride_calls;
CREATE POLICY "Service role full access ride_calls" ON ride_calls
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access emergency_alerts" ON emergency_alerts;
CREATE POLICY "Service role full access emergency_alerts" ON emergency_alerts
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access ride_share_links" ON ride_share_links;
CREATE POLICY "Service role full access ride_share_links" ON ride_share_links
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access masked_contacts" ON masked_contacts;
CREATE POLICY "Service role full access masked_contacts" ON masked_contacts
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access communication_preferences" ON communication_preferences;
CREATE POLICY "Service role full access communication_preferences" ON communication_preferences
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access communication_logs" ON communication_logs;
CREATE POLICY "Service role full access communication_logs" ON communication_logs
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- =====================================================
-- FUNCTIONS
-- =====================================================

-- Telefon numarası maskeleme fonksiyonu
CREATE OR REPLACE FUNCTION mask_phone_number(phone TEXT)
RETURNS TEXT AS $$
BEGIN
    IF phone IS NULL OR LENGTH(phone) < 4 THEN
        RETURN '***';
    END IF;
    -- Son 3 hane görünür: +90 5** *** *789
    RETURN SUBSTRING(phone FROM 1 FOR 3) || ' ' ||
           REPEAT('*', GREATEST(LENGTH(phone) - 6, 3)) || ' ' ||
           RIGHT(phone, 3);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Güvenli müşteri bilgisi getirme (sürücü için)
CREATE OR REPLACE FUNCTION get_secure_customer_info(p_ride_id UUID, p_driver_user_id UUID)
RETURNS TABLE (
    customer_name VARCHAR,
    masked_phone VARCHAR,
    can_call BOOLEAN,
    can_message BOOLEAN
) AS $$
DECLARE
    v_ride RECORD;
    v_prefs RECORD;
BEGIN
    -- Yolculuğu kontrol et
    SELECT r.*, d.id as driver_id INTO v_ride
    FROM taxi_rides r
    JOIN taxi_drivers d ON d.id = r.driver_id
    WHERE r.id = p_ride_id
    AND d.user_id = p_driver_user_id
    AND r.status IN ('accepted', 'arrived', 'in_progress');

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Müşteri tercihlerini al
    SELECT * INTO v_prefs
    FROM communication_preferences
    WHERE user_id = v_ride.user_id;

    RETURN QUERY SELECT
        v_ride.customer_name::VARCHAR,
        mask_phone_number(v_ride.customer_phone)::VARCHAR,
        COALESCE(v_prefs.allow_calls, TRUE),
        COALESCE(v_prefs.allow_messages, TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Güvenli sürücü bilgisi getirme (müşteri için)
CREATE OR REPLACE FUNCTION get_secure_driver_info(p_ride_id UUID, p_customer_user_id UUID)
RETURNS TABLE (
    driver_name VARCHAR,
    masked_phone VARCHAR,
    vehicle_plate VARCHAR,
    vehicle_brand VARCHAR,
    vehicle_model VARCHAR,
    vehicle_color VARCHAR,
    rating DOUBLE PRECISION,
    can_call BOOLEAN,
    can_message BOOLEAN
) AS $$
DECLARE
    v_ride RECORD;
    v_driver RECORD;
    v_prefs RECORD;
BEGIN
    -- Yolculuğu kontrol et
    SELECT * INTO v_ride
    FROM taxi_rides
    WHERE id = p_ride_id
    AND user_id = p_customer_user_id
    AND status IN ('accepted', 'arrived', 'in_progress');

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Sürücü bilgisini al
    SELECT * INTO v_driver
    FROM taxi_drivers
    WHERE id = v_ride.driver_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Sürücü tercihlerini al
    SELECT * INTO v_prefs
    FROM communication_preferences
    WHERE user_id = v_driver.user_id;

    RETURN QUERY SELECT
        v_driver.full_name::VARCHAR,
        mask_phone_number(v_driver.phone)::VARCHAR,
        v_driver.vehicle_plate::VARCHAR,
        v_driver.vehicle_brand::VARCHAR,
        v_driver.vehicle_model::VARCHAR,
        v_driver.vehicle_color::VARCHAR,
        v_driver.rating,
        COALESCE(v_prefs.allow_calls, TRUE),
        COALESCE(v_prefs.allow_messages, TRUE);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Yolculuk paylaşım linki oluştur
CREATE OR REPLACE FUNCTION create_ride_share_link(
    p_ride_id UUID,
    p_recipient_name VARCHAR DEFAULT NULL,
    p_recipient_phone VARCHAR DEFAULT NULL,
    p_hours_valid INTEGER DEFAULT 24
)
RETURNS TABLE (
    share_token VARCHAR,
    share_url VARCHAR,
    expires_at TIMESTAMPTZ
) AS $$
DECLARE
    v_token VARCHAR;
    v_expires TIMESTAMPTZ;
    v_ride RECORD;
BEGIN
    -- Yolculuk kontrolü
    SELECT * INTO v_ride
    FROM taxi_rides
    WHERE id = p_ride_id AND user_id = auth.uid();

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride not found or unauthorized';
    END IF;

    -- Token oluştur
    v_token := encode(gen_random_bytes(32), 'hex');
    v_expires := NOW() + (p_hours_valid || ' hours')::INTERVAL;

    -- Kaydet
    INSERT INTO ride_share_links (ride_id, user_id, share_token, recipient_name, recipient_phone, expires_at)
    VALUES (p_ride_id, auth.uid(), v_token, p_recipient_name, p_recipient_phone, v_expires);

    RETURN QUERY SELECT
        v_token,
        ('https://app.example.com/track/' || v_token)::VARCHAR,
        v_expires;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Acil durum uyarısı oluştur
CREATE OR REPLACE FUNCTION create_emergency_alert(
    p_ride_id UUID,
    p_alert_type VARCHAR,
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_description TEXT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_alert_id UUID;
    v_user_type VARCHAR;
BEGIN
    -- Kullanıcı tipini belirle
    IF EXISTS (SELECT 1 FROM taxi_drivers WHERE user_id = auth.uid()) THEN
        v_user_type := 'driver';
    ELSE
        v_user_type := 'customer';
    END IF;

    -- Alert oluştur
    INSERT INTO emergency_alerts (ride_id, user_id, user_type, alert_type, latitude, longitude, description)
    VALUES (p_ride_id, auth.uid(), v_user_type, p_alert_type, p_latitude, p_longitude, p_description)
    RETURNING id INTO v_alert_id;

    -- Log kaydet
    INSERT INTO communication_logs (ride_id, action_type, actor_id, actor_type, details)
    VALUES (p_ride_id, 'emergency_triggered', auth.uid(), v_user_type,
            jsonb_build_object('alert_type', p_alert_type, 'alert_id', v_alert_id));

    RETURN v_alert_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Mesaj gönder
CREATE OR REPLACE FUNCTION send_ride_message(
    p_ride_id UUID,
    p_content TEXT,
    p_message_type VARCHAR DEFAULT 'text'
)
RETURNS UUID AS $$
DECLARE
    v_message_id UUID;
    v_sender_type VARCHAR;
    v_ride RECORD;
BEGIN
    -- Yolculuk ve yetki kontrolü
    SELECT r.*,
           CASE WHEN d.user_id = auth.uid() THEN 'driver' ELSE 'customer' END as sender_type
    INTO v_ride
    FROM taxi_rides r
    LEFT JOIN taxi_drivers d ON d.id = r.driver_id
    WHERE r.id = p_ride_id
    AND r.status IN ('accepted', 'arrived', 'in_progress')
    AND (r.user_id = auth.uid() OR d.user_id = auth.uid());

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride not found or not active';
    END IF;

    v_sender_type := v_ride.sender_type;

    -- Mesaj kaydet
    INSERT INTO ride_communications (ride_id, sender_type, sender_id, message_type, content)
    VALUES (p_ride_id, v_sender_type, auth.uid(), p_message_type, p_content)
    RETURNING id INTO v_message_id;

    -- Log kaydet
    INSERT INTO communication_logs (ride_id, action_type, actor_id, actor_type, details)
    VALUES (p_ride_id, 'message_sent', auth.uid(), v_sender_type,
            jsonb_build_object('message_type', p_message_type));

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Arama başlat kaydı
CREATE OR REPLACE FUNCTION initiate_ride_call(p_ride_id UUID)
RETURNS UUID AS $$
DECLARE
    v_call_id UUID;
    v_caller_type VARCHAR;
    v_ride RECORD;
BEGIN
    -- Yolculuk ve yetki kontrolü
    SELECT r.*,
           CASE WHEN d.user_id = auth.uid() THEN 'driver' ELSE 'customer' END as caller_type
    INTO v_ride
    FROM taxi_rides r
    LEFT JOIN taxi_drivers d ON d.id = r.driver_id
    WHERE r.id = p_ride_id
    AND r.status IN ('accepted', 'arrived', 'in_progress')
    AND (r.user_id = auth.uid() OR d.user_id = auth.uid());

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Ride not found or not active';
    END IF;

    v_caller_type := v_ride.caller_type;

    -- Arama kaydı oluştur
    INSERT INTO ride_calls (ride_id, caller_type, caller_id)
    VALUES (p_ride_id, v_caller_type, auth.uid())
    RETURNING id INTO v_call_id;

    -- Log kaydet
    INSERT INTO communication_logs (ride_id, action_type, actor_id, actor_type, details)
    VALUES (p_ride_id, 'call_initiated', auth.uid(), v_caller_type,
            jsonb_build_object('call_id', v_call_id));

    RETURN v_call_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Paylaşım linki ile yolculuk bilgisi getir (public - auth gerektirmez)
CREATE OR REPLACE FUNCTION get_shared_ride_info(p_share_token VARCHAR)
RETURNS TABLE (
    ride_id UUID,
    status VARCHAR,
    driver_name VARCHAR,
    vehicle_info VARCHAR,
    vehicle_plate VARCHAR,
    driver_rating DOUBLE PRECISION,
    pickup_address VARCHAR,
    dropoff_address VARCHAR,
    driver_latitude DOUBLE PRECISION,
    driver_longitude DOUBLE PRECISION,
    estimated_arrival VARCHAR
) AS $$
DECLARE
    v_link RECORD;
    v_ride RECORD;
    v_driver RECORD;
BEGIN
    -- Link kontrolü
    SELECT * INTO v_link
    FROM ride_share_links
    WHERE share_token = p_share_token
    AND is_active = TRUE
    AND expires_at > NOW();

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- View count güncelle
    UPDATE ride_share_links
    SET view_count = view_count + 1, last_viewed_at = NOW()
    WHERE id = v_link.id;

    -- Yolculuk bilgisi
    SELECT * INTO v_ride
    FROM taxi_rides
    WHERE id = v_link.ride_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Sürücü bilgisi
    SELECT * INTO v_driver
    FROM taxi_drivers
    WHERE id = v_ride.driver_id;

    RETURN QUERY SELECT
        v_ride.id,
        v_ride.status::VARCHAR,
        v_driver.full_name::VARCHAR,
        (COALESCE(v_driver.vehicle_brand, '') || ' ' || COALESCE(v_driver.vehicle_model, ''))::VARCHAR,
        v_driver.vehicle_plate::VARCHAR,
        v_driver.rating,
        v_ride.pickup_address::VARCHAR,
        v_ride.dropoff_address::VARCHAR,
        v_driver.current_latitude,
        v_driver.current_longitude,
        NULL::VARCHAR; -- estimated_arrival hesaplanabilir
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Updated at trigger for communication_preferences
CREATE OR REPLACE FUNCTION update_communication_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_communication_preferences_updated_at ON communication_preferences;
CREATE TRIGGER trigger_update_communication_preferences_updated_at
    BEFORE UPDATE ON communication_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_communication_preferences_updated_at();

-- =====================================================
-- REALTIME SUBSCRIPTIONS
-- =====================================================

-- Enable realtime for ride_communications
ALTER PUBLICATION supabase_realtime ADD TABLE ride_communications;

-- =====================================================
-- QUICK MESSAGES (Hazır Mesajlar)
-- =====================================================
CREATE TABLE IF NOT EXISTS quick_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_type VARCHAR(20) NOT NULL CHECK (user_type IN ('driver', 'customer', 'both')),
    message_tr TEXT NOT NULL,
    message_en TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Hazır mesajları ekle
INSERT INTO quick_messages (user_type, message_tr, message_en, sort_order) VALUES
('driver', 'Yoldayım, birazdan orada olacağım', 'On my way, will be there soon', 1),
('driver', 'Geldim, sizi bekliyorum', 'I have arrived, waiting for you', 2),
('driver', 'Tam olarak neredesiniz?', 'Where exactly are you?', 3),
('driver', 'Trafik yoğun, biraz gecikebilirim', 'Heavy traffic, might be delayed', 4),
('driver', 'Arabam ... rengi ... plakalı', 'My car is ... colored with plate ...', 5),
('customer', 'Birazdan çıkıyorum', 'Coming out soon', 1),
('customer', 'Tam konumumu paylaşıyorum', 'Sharing my exact location', 2),
('customer', '5 dakika bekler misiniz?', 'Can you wait 5 minutes?', 3),
('customer', 'Kapının önündeyim', 'I am at the door', 4),
('customer', 'Sizi göremiyorum, neredesiniz?', 'I cannot see you, where are you?', 5)
ON CONFLICT DO NOTHING;

-- RLS for quick_messages (public read)
ALTER TABLE quick_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read quick messages" ON quick_messages;
CREATE POLICY "Anyone can read quick messages" ON quick_messages
    FOR SELECT USING (is_active = TRUE);
