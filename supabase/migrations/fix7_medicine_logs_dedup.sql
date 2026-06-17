-- FIX 7: DB-level deduplication for medicine_logs
-- ================================================================
-- Problem: If both notification action handler AND AlarmScreen button
-- fire within the same second (race condition), two identical log
-- entries would be inserted — and qty decremented twice.
--
-- Solution: Add a UNIQUE constraint so the second INSERT fails
-- gracefully (ignored), while the first succeeds. Combined with
-- the Supabase client's `.insert()` + onConflict: ignore behavior.
-- ================================================================

-- Step 1: Remove any existing duplicate rows first
-- (Run this BEFORE adding the constraint)
DELETE FROM medicine_logs a
USING medicine_logs b
WHERE a.id > b.id
  AND a.medication_id = b.medication_id
  AND a.scheduled_time = b.scheduled_time
  AND a.alarm_slot = b.alarm_slot
  AND a.status = b.status;

-- Step 2: Add the unique constraint
ALTER TABLE medicine_logs
  ADD CONSTRAINT medicine_logs_dedup_key
  UNIQUE (medication_id, scheduled_time, alarm_slot, status);

-- Usage in Dart code (after this migration):
-- Instead of:
--   await supabase.from('medicine_logs').insert({...});
-- Use:
--   await supabase.from('medicine_logs').insert({...},
--     ignoreDuplicates: true);  // or onConflict: 'medication_id,scheduled_time,alarm_slot,status'
