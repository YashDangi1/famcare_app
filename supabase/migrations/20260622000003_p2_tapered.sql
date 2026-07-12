-- Migration to add taper_steps to medicines table for Advanced Scheduling

ALTER TABLE medicines 
ADD COLUMN IF NOT EXISTS taper_steps JSONB DEFAULT '[]'::jsonb;

-- New RPC for dynamic dose decrement
CREATE OR REPLACE FUNCTION decrement_medicine_qty_v3(
  p_med_id UUID, 
  p_user_id UUID, 
  p_override_take_amt FLOAT DEFAULT NULL
)
RETURNS void AS $$
DECLARE
  v_current_qty INT;
  v_take_amount FLOAT;
  v_threshold INT;
  v_alerted BOOLEAN;
  v_new_qty INT;
BEGIN
  SELECT qty, take_amount, refill_reminder_threshold, low_stock_alerted 
  INTO v_current_qty, v_take_amount, v_threshold, v_alerted
  FROM medicines
  WHERE id = p_med_id AND user_id = p_user_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_current_qty > 0 THEN
      IF p_override_take_amt IS NOT NULL THEN
        v_new_qty := GREATEST(0, v_current_qty - CAST(p_override_take_amt AS INT));
      ELSE
        v_new_qty := GREATEST(0, v_current_qty - CAST(COALESCE(v_take_amount, 1) AS INT));
      END IF;

      UPDATE medicines
      SET 
        qty = v_new_qty,
        is_active = v_new_qty > 0,
        low_stock_alerted = CASE 
          WHEN v_new_qty <= v_threshold AND NOT v_alerted THEN TRUE 
          ELSE low_stock_alerted 
        END
      WHERE id = p_med_id AND user_id = p_user_id;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
