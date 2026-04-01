-- Admin kullanıcıları users tablosunu güncelleyebilsin (ban, unban, profil düzenleme)
CREATE POLICY "Admins can update all users"
ON users FOR UPDATE
USING (
  EXISTS (
    SELECT 1 FROM admin_users WHERE user_id = auth.uid()
  )
);

-- Admin kullanıcıları tüm user kayıtlarını görebilsin
CREATE POLICY "Admins can read all users"
ON users FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM admin_users WHERE user_id = auth.uid()
  )
);
