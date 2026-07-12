-- Migration to add Advanced Medication fields to medicine_logs

ALTER TABLE medicine_logs 
ADD COLUMN IF NOT EXISTS actual_dose FLOAT,
ADD COLUMN IF NOT EXISTS is_prn BOOLEAN DEFAULT FALSE;

-- Also add snooze tracking to support snoozing alarms
ALTER TABLE medicine_logs
ADD COLUMN IF NOT EXISTS snoozed_until TIMESTAMP WITH TIME ZONE;
