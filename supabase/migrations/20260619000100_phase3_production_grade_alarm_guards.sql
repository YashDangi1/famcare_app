-- Phase 3 production-grade alarm guards
-- 1. Enforce one logical dose row per user + medication + scheduled_time.
-- 2. Provide take_amount-aware atomic quantity decrement RPC.

-- Remove older status-based uniqueness if it exists.
ALTER TABLE medicine_logs
  DROP CONSTRAINT IF EXISTS medicine_logs_dedup_key;

-- Collapse duplicate logical-dose rows while preserving the most useful status.
WITH ranked AS (
  SELECT
    id,
    ROW_NUMBER() OVER (
      PARTITION BY user_id, medication_id, scheduled_time
      ORDER BY
        CASE status
          WHEN 'taken' THEN 1
          WHEN 'skipped' THEN 2
          WHEN 'missed' THEN 3
          WHEN 'snoozed' THEN 4
          ELSE 5
        END,
        created_at DESC,
        id DESC
    ) AS rn
  FROM medicine_logs
)
DELETE FROM medicine_logs m
USING ranked r
WHERE m.id = r.id
  AND r.rn > 1;

-- Enforce one row per logical dose.
CREATE UNIQUE INDEX IF NOT EXISTS medicine_logs_logical_dose_key
  ON medicine_logs (user_id, medication_id, scheduled_time);

CREATE OR REPLACE FUNCTION decrement_medicine_qty_v2(
  p_med_id uuid,
  p_user_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  current_qty integer;
  take_amount_raw text;
  take_amount_int integer;
  new_qty integer;
BEGIN
  SELECT
    qty,
    COALESCE(take_amount, '1')
  INTO current_qty, take_amount_raw
  FROM medications
  WHERE id = p_med_id
    AND user_id = p_user_id
  FOR UPDATE;

  IF current_qty IS NULL THEN
    RAISE EXCEPTION 'Medication not found';
  END IF;

  take_amount_int := GREATEST(COALESCE(NULLIF(take_amount_raw, '')::integer, 1), 1);
  new_qty := GREATEST(current_qty - take_amount_int, 0);

  UPDATE medications
  SET
    qty = new_qty,
    is_active = CASE WHEN new_qty = 0 THEN false ELSE is_active END
  WHERE id = p_med_id
    AND user_id = p_user_id;

  RETURN new_qty;
END;
$$;
