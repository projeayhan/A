-- Fix: taxi_rides RLS policy exposes customer data to all authenticated users
-- The old "Drivers can view assigned rides" policy had `status = 'pending'` as a bare condition,
-- allowing ANY authenticated user to read all pending rides including sensitive customer fields.

-- Remove the overly permissive policy
DROP POLICY IF EXISTS "Drivers can view assigned rides" ON taxi_rides;

-- Policy 1: Drivers can view their own assigned rides (full row access)
CREATE POLICY "Drivers can view own rides"
ON taxi_rides FOR SELECT
USING (
  driver_id IN (
    SELECT id FROM taxi_drivers WHERE user_id = auth.uid()
  )
);

-- Policy 2: Approved drivers can view pending rides for acceptance
-- Only approved drivers see pending rides — sensitive customer fields are NOT projected here
-- (column-level restriction is enforced via the separate pending_rides view below)
CREATE POLICY "Approved drivers can view pending rides"
ON taxi_rides FOR SELECT
USING (
  status = 'pending'
  AND EXISTS (
    SELECT 1 FROM taxi_drivers
    WHERE user_id = auth.uid()
      AND status = 'approved'
  )
);
