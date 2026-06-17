-- Migration to add retry_interval column if it doesn't exist

DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'user_slot_preferences' 
        AND column_name = 'retry_interval'
    ) THEN 
        ALTER TABLE user_slot_preferences ADD COLUMN retry_interval INTEGER DEFAULT 30;
    END IF; 
END $$;
