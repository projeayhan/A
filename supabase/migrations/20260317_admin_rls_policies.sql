-- Admin panel RLS policies
-- Admin kullanıcılarına tüm tablolarda SELECT, UPDATE, DELETE yetkisi verir

DO $$
DECLARE
  tbl TEXT;
  read_tables TEXT[] := ARRAY[
    'orders', 'taxi_rides', 'reviews', 'couriers', 'products',
    'menu_items', 'menu_categories', 'product_categories',
    'conversations', 'messages', 'job_applications', 'job_listings',
    'car_listings', 'rental_bookings', 'rental_cars', 'rental_locations',
    'rental_packages', 'rental_services', 'properties',
    'taxi_drivers', 'car_dealers', 'companies', 'rental_companies', 'invoices'
  ];
  update_tables TEXT[] := ARRAY[
    'orders', 'taxi_rides', 'reviews', 'couriers', 'products',
    'menu_items', 'menu_categories', 'product_categories',
    'job_applications', 'job_listings', 'car_listings',
    'rental_bookings', 'rental_cars', 'rental_locations',
    'rental_packages', 'rental_services', 'properties',
    'taxi_drivers', 'car_dealers', 'companies', 'rental_companies', 'invoices'
  ];
  delete_tables TEXT[] := ARRAY['reviews', 'orders', 'invoices'];
BEGIN
  -- SELECT policies
  FOREACH tbl IN ARRAY read_tables LOOP
    EXECUTE format(
      'CREATE POLICY "Admin full read %s" ON %I FOR SELECT TO authenticated USING (EXISTS (SELECT 1 FROM admin_users WHERE admin_users.user_id = auth.uid()))',
      tbl, tbl
    );
  END LOOP;

  -- UPDATE policies
  FOREACH tbl IN ARRAY update_tables LOOP
    EXECUTE format(
      'CREATE POLICY "Admin full update %s" ON %I FOR UPDATE TO authenticated USING (EXISTS (SELECT 1 FROM admin_users WHERE admin_users.user_id = auth.uid()))',
      tbl, tbl
    );
  END LOOP;

  -- DELETE policies
  FOREACH tbl IN ARRAY delete_tables LOOP
    EXECUTE format(
      'CREATE POLICY "Admin full delete %s" ON %I FOR DELETE TO authenticated USING (EXISTS (SELECT 1 FROM admin_users WHERE admin_users.user_id = auth.uid()))',
      tbl, tbl
    );
  END LOOP;
END $$;
