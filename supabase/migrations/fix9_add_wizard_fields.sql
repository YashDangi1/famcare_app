ALTER TABLE medications
ADD COLUMN form text,
ADD COLUMN color text,
ADD COLUMN strength numeric,
ADD COLUMN strength_unit text,
ADD COLUMN take_amount text,
ADD COLUMN food_instruction text,
ADD COLUMN is_as_needed boolean DEFAULT false,
ADD COLUMN refill_reminder_threshold integer,
ADD COLUMN condition text;
