-- Support Chat Sessions Table
CREATE TABLE IF NOT EXISTS support_chat_sessions (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    app_source VARCHAR(50) NOT NULL DEFAULT 'super_app',
    user_type VARCHAR(50) NOT NULL DEFAULT 'customer',
    status VARCHAR(50) NOT NULL DEFAULT 'active',
    subject VARCHAR(255),
    category VARCHAR(100),
    priority VARCHAR(20) DEFAULT 'normal',
    satisfaction_rating INTEGER CHECK (satisfaction_rating >= 1 AND satisfaction_rating <= 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    closed_at TIMESTAMPTZ,
    escalated_at TIMESTAMPTZ,
    escalated_to UUID REFERENCES auth.users(id),
    escalation_reason TEXT,
    metadata JSONB DEFAULT '{}'
);

-- Support Chat Messages Table
CREATE TABLE IF NOT EXISTS support_chat_messages (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES support_chat_sessions(id) ON DELETE CASCADE,
    role VARCHAR(20) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    tokens_used INTEGER,
    is_helpful BOOLEAN,
    metadata JSONB DEFAULT '{}'
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_support_chat_sessions_user_id ON support_chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_support_chat_sessions_status ON support_chat_sessions(status);
CREATE INDEX IF NOT EXISTS idx_support_chat_sessions_app_source ON support_chat_sessions(app_source);
CREATE INDEX IF NOT EXISTS idx_support_chat_messages_session_id ON support_chat_messages(session_id);
CREATE INDEX IF NOT EXISTS idx_support_chat_messages_created_at ON support_chat_messages(created_at);

-- RLS Policies
ALTER TABLE support_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_chat_messages ENABLE ROW LEVEL SECURITY;

-- Users can see their own sessions
DROP POLICY IF EXISTS "Users can view own sessions" ON support_chat_sessions;
CREATE POLICY "Users can view own sessions" ON support_chat_sessions
    FOR SELECT USING (auth.uid() = user_id);

-- Users can create their own sessions
DROP POLICY IF EXISTS "Users can create own sessions" ON support_chat_sessions;
CREATE POLICY "Users can create own sessions" ON support_chat_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own sessions (for rating, etc.)
DROP POLICY IF EXISTS "Users can update own sessions" ON support_chat_sessions;
CREATE POLICY "Users can update own sessions" ON support_chat_sessions
    FOR UPDATE USING (auth.uid() = user_id);

-- Users can view messages in their sessions
DROP POLICY IF EXISTS "Users can view messages in own sessions" ON support_chat_messages;
CREATE POLICY "Users can view messages in own sessions" ON support_chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM support_chat_sessions
            WHERE support_chat_sessions.id = support_chat_messages.session_id
            AND support_chat_sessions.user_id = auth.uid()
        )
    );

-- Users can insert messages in their sessions
DROP POLICY IF EXISTS "Users can insert messages in own sessions" ON support_chat_messages;
CREATE POLICY "Users can insert messages in own sessions" ON support_chat_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM support_chat_sessions
            WHERE support_chat_sessions.id = support_chat_messages.session_id
            AND support_chat_sessions.user_id = auth.uid()
        )
    );

-- Service role can do everything (for Edge Functions)
DROP POLICY IF EXISTS "Service role full access sessions" ON support_chat_sessions;
CREATE POLICY "Service role full access sessions" ON support_chat_sessions
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

DROP POLICY IF EXISTS "Service role full access messages" ON support_chat_messages;
CREATE POLICY "Service role full access messages" ON support_chat_messages
    FOR ALL USING (auth.jwt() ->> 'role' = 'service_role');

-- Updated at trigger
CREATE OR REPLACE FUNCTION update_support_chat_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_support_chat_sessions_updated_at ON support_chat_sessions;
CREATE TRIGGER trigger_update_support_chat_sessions_updated_at
    BEFORE UPDATE ON support_chat_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_support_chat_sessions_updated_at();
