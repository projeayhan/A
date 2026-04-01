-- Centralized logging table for all apps
CREATE TABLE IF NOT EXISTS public.app_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_name text NOT NULL,
  level text NOT NULL CHECK (level IN ('error', 'warn', 'info', 'debug')),
  message text NOT NULL,
  source text,
  error_detail text,
  user_id uuid REFERENCES auth.users(id),
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_app_logs_app_name ON public.app_logs(app_name);
CREATE INDEX IF NOT EXISTS idx_app_logs_level ON public.app_logs(level);
CREATE INDEX IF NOT EXISTS idx_app_logs_created_at ON public.app_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_logs_app_level_date ON public.app_logs(app_name, level, created_at DESC);

-- RLS
ALTER TABLE public.app_logs ENABLE ROW LEVEL SECURITY;

-- All authenticated users can INSERT logs
DROP POLICY IF EXISTS "authenticated_insert_logs" ON public.app_logs;
CREATE POLICY "authenticated_insert_logs" ON public.app_logs
  FOR INSERT TO authenticated
  WITH CHECK (true);

-- Only admin_users can SELECT logs
DROP POLICY IF EXISTS "admin_select_logs" ON public.app_logs;
CREATE POLICY "admin_select_logs" ON public.app_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.admin_users au
      WHERE au.user_id = auth.uid()
    )
  );

-- Anon can INSERT (for edge functions without auth context)
DROP POLICY IF EXISTS "anon_insert_logs" ON public.app_logs;
CREATE POLICY "anon_insert_logs" ON public.app_logs
  FOR INSERT TO anon
  WITH CHECK (true);

-- Auto-cleanup: delete logs older than 30 days (run daily at 3 AM)
SELECT cron.schedule(
  'cleanup-old-app-logs',
  '0 3 * * *',
  $$DELETE FROM public.app_logs WHERE created_at < now() - interval '30 days'$$
);
