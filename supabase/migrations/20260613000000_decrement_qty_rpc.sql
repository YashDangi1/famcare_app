-- Migration to create an RPC function for atomic quantity decrements.
-- This prevents race conditions and ensures qty never drops below 0.

CREATE OR REPLACE FUNCTION decrement_medicine_qty(med_id UUID)
RETURNS integer
LANGUAGE plpgsql
AS $$
DECLARE
    current_qty integer;
    new_qty integer;
BEGIN
    -- Lock the row for update to prevent concurrent modifications
    SELECT qty INTO current_qty
    FROM medications
    WHERE id = med_id
    FOR UPDATE;

    IF current_qty IS NULL THEN
        RAISE EXCEPTION 'Medication not found';
    END IF;

    -- Decrement, but clamp to 0
    new_qty := GREATEST(current_qty - 1, 0);

    -- Update the table
    UPDATE medications
    SET 
        qty = new_qty,
        is_active = CASE WHEN new_qty = 0 THEN false ELSE is_active END
    WHERE id = med_id;

    RETURN new_qty;
END;
$$;
