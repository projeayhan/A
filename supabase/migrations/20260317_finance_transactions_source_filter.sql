-- Update get_recent_transactions to support optional source filter
DROP FUNCTION IF EXISTS get_recent_transactions(INT);
DROP FUNCTION IF EXISTS get_recent_transactions(INT, TEXT);

CREATE FUNCTION get_recent_transactions(
  p_limit INT,
  p_source TEXT DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN (
    SELECT json_agg(t)
    FROM (
      SELECT
        id::TEXT                     AS transaction_id,
        'income'::TEXT               AS type,
        CASE source_type
          WHEN 'taxi'   THEN 'Taksi Siparişi #'  || id::TEXT
          WHEN 'food'   THEN 'Yemek Siparişi #'  || id::TEXT
          WHEN 'store'  THEN 'Market Siparişi #' || id::TEXT
          WHEN 'rental' THEN 'Kiralama #'         || id::TEXT
          ELSE               'Sipariş #'          || id::TEXT
        END                          AS description,
        COALESCE(total, 0)::NUMERIC  AS amount,
        created_at::TEXT             AS date,
        source_type                  AS source
      FROM invoices
      WHERE (p_source IS NULL OR source_type = p_source)
      ORDER BY created_at DESC
      LIMIT p_limit
    ) t
  );
END;
$$;

GRANT EXECUTE ON FUNCTION get_recent_transactions(INT, TEXT) TO authenticated, service_role, anon;
