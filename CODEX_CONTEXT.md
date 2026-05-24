# FamCare App — Current State for Codex

## Stack
Flutter + Supabase + alarm v5.2.1

## What's working
- 5 slot cards (Morning/Afternoon/Evening/Night/Custom)
- Slot-based alarm with 8-min retry
- Schedule types: Daily / Every X days / Specific dates
- Family Hub, Vitals, Vault, Appointments

## Known bugs to fix (in order)
1. Settings save: duplicate key error on user_slot_preferences
   → Fix: upsert with onConflict: 'user_id'

2. Custom slot: only first custom time schedules, others ignored
   → Fix: separate loop per custom time in meds_screen.dart

3. Custom slot: Due Soon panel never shows custom medicines
   → Fix: _getDueSoonMeds() handle customTimes array separately

4. Time format shows "08:00:00" with seconds
   → Fix: parse and format with TimeOfDay.format()

5. "Display over other apps" denied — better error message needed
   → Fix: show manual steps dialog in alarm_setup_screen.dart

## Database
- Supabase project: famcare_app
- Key tables: medications, medicine_logs, 
  user_slot_preferences, appointments, family_members

## Files most relevant to bugs
- lib/services/slot_preferences_service.dart (Bug 1)
- lib/meds_screen.dart (Bug 2, 4)
- lib/main_app_shell.dart (Bug 3)
- lib/screens/alarm_setup_screen.dart (Bug 5)
