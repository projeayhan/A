-- Categorization Rules Table
CREATE TABLE IF NOT EXISTS categorization_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pattern TEXT NOT NULL,
  match_type VARCHAR(20) DEFAULT 'contains' CHECK (match_type IN ('contains', 'starts_with', 'regex', 'exact')),
  target_category VARCHAR(100) NOT NULL,
  target_subcategory VARCHAR(100),
  target_entry_type VARCHAR(10) CHECK (target_entry_type IN ('income', 'expense')),
  target_source VARCHAR(20),
  priority INT DEFAULT 0,
  is_active BOOLEAN DEFAULT TRUE,
  created_by UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_categorization_rules_active ON categorization_rules(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_categorization_rules_priority ON categorization_rules(priority DESC);

-- RLS
ALTER TABLE categorization_rules ENABLE ROW LEVEL SECURITY;

-- Admin full access
CREATE POLICY "admin_categorization_rules_all" ON categorization_rules
  FOR ALL TO authenticated USING (
    EXISTS (SELECT 1 FROM admin_users WHERE admin_users.user_id = auth.uid())
  );
