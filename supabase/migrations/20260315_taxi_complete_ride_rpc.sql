-- Atomic taxi ride completion with driver statistics update
-- Eliminates race condition between status update and stats update

-- RPC: Increment driver earnings atomically (used by fallback path too)
CREATE OR REPLACE FUNCTION increment_driver_earnings(
  p_driver_id UUID,
  p_amount DECIMAL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE taxi_drivers
  SET
    total_earnings = total_earnings + p_amount,
    updated_at = NOW()
  WHERE id = p_driver_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver not found: %', p_driver_id;
  END IF;
END;
$$;

-- RPC: Complete a ride and atomically update driver statistics in a single transaction
CREATE OR REPLACE FUNCTION complete_ride_and_update_stats(
  p_ride_id UUID,
  p_driver_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fare DECIMAL;
BEGIN
  -- Update ride status to completed and capture the fare
  UPDATE taxi_rides
  SET
    status = 'completed',
    completed_at = NOW(),
    updated_at = NOW()
  WHERE id = p_ride_id
    AND driver_id = p_driver_id
    AND status = 'in_progress'
  RETURNING fare INTO v_fare;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ride not found, not in progress, or driver mismatch: ride_id=%, driver_id=%', p_ride_id, p_driver_id;
  END IF;

  -- Atomically update driver statistics (total_rides and total_earnings in one UPDATE)
  UPDATE taxi_drivers
  SET
    total_rides    = total_rides + 1,
    total_earnings = total_earnings + COALESCE(v_fare, 0),
    updated_at     = NOW()
  WHERE id = p_driver_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Driver not found: %', p_driver_id;
  END IF;
END;
$$;
