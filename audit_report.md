# FamCare Exhaustive QA Audit Report

As requested, I have conducted a deep, file-by-file audit of the FamCare app (`lib/` directory, ~120 files). I reviewed the codebase from the perspective of an elderly user and a frustrated caregiver, looking specifically for offline edge cases, synchronization faults, and UI friction.

Below is the structured, unfiltered truth about the app.

---

## MODULE: 1. Onboarding & Auth
**Files involved:** `login_screen.dart`, `profile_setup_screen.dart`, `splash_screen.dart`
**Working (A):**
- Standard Supabase authentication flows (email/password).
- Profile creation and routing to `MainAppShell`.
**Broken (B):**
- None found in the happy path.
**Partial (C):**
- If the token expires while the user is strictly offline, there is no offline-mode fallback for authentication, locking the user out of their Isar local data until they reconnect.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- No clear "Loading..." states during the initial token refresh on `splash_screen`, leaving users wondering if the app froze.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Caregiver invite code entry directly at signup (prevents a 65-year-old from having to navigate the complex Family Hub later).

---

## MODULE: 2. Medicines
**Files involved:** `add_medicine_wizard.dart`, `medicine_model.dart`, `medicine_entity.dart`
**Working (A):**
- The wizard successfully calculates total quantities based on durations, frequencies, and taper steps.
- PRN (as-needed) correctly bypasses alarm scheduling.
**Broken (B):**
- Adding or editing a medication while strictly offline fails or is dropped; `OfflineSyncService` only queues logs and quantity updates, not full medication creations.
**Partial (C):**
- Tapered doses and "Every X days" schedules exist in the UI but the math for quantity calculation (`recalcQty()`) breaks if the user manually overrides the quantity text field afterwards, causing UI state to fight user input.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- **5-step wizard is exhausting.** A senior citizen adding 8 medications will hate this app. 
- "Tapered Dose" and "Slot-based" paradigms are too complex. They just want to say "1 pill in the morning".
**Conflicts with old code (F):**
- Parallel existence of `medicine_model.dart` (Supabase) and `medicine_entity.dart` (Isar) creates mapping friction and potential sync mismatches.
**Missing for real patient (G):**
- Drug-drug interaction warnings.
- Expiration date tracking.

---

## MODULE: 3. Alarm System
**Files involved:** `alarm_service.dart`, `alarm_action_engine.dart`, `alarm_context_resolver.dart`, `alarm_recovery_manager.dart`
**Working (A):**
- `AlarmRecoveryManager` correctly checks `SharedPreferences` for `auto_stop_expiry` on app startup to recover alarms if the OS killed the app.
- Snoozing and group alarms (batch taking) function correctly via native alarm intents.
**Broken (B):**
- **Offline dose logging is completely broken.** `AlarmActionEngine` (lines 418-490) attempts a direct `_supabase.from('medicine_logs').insert()` wrapped in a try/catch. If offline, it throws a `SocketException`, catches it, and returns `success: false`. **It NEVER calls `OfflineSyncService.enqueueAction`!** The dose is lost forever.
**Partial (C):**
- Group alarms can fail partially if one of the medications in the group fails to log, leaving the UI in a hung state where the alarm keeps ringing.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- No "Skip All for Today" button. If a patient goes to the hospital, their phone will scream at them all day.
**Conflicts with old code (F):**
- `notification_service.dart` and `alarm_service.dart` overlap. Some alerts use local notifications, while meds use fullscreen alarms.
**Missing for real patient (G):**
- Auto-escalation to caregiver (via SMS/WhatsApp) if an alarm is missed after 30 minutes.

---

## MODULE: 4. Home Dashboard
**Files involved:** `main_app_shell.dart`, `health_dashboard_screen.dart`
**Working (A):**
- Routing, basic stats display, UI rendering.
**Broken (B):**
- None.
**Partial (C):**
- Pull-to-refresh triggers Supabase queries but doesn't force a robust Isar-to-Supabase conflict resolution sync.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- The dashboard is incredibly cluttered with Streaks, Gamification, and Tasks. A 75-year-old user will be overwhelmed.
**Conflicts with old code (F):**
- `main_app_shell.dart.stash` is left over in the codebase, indicating messy git resolution.
**Missing for real patient (G):**
- A "Senior Mode" toggle that strips away everything except a giant "Meds Due Now" button.

---

## MODULE: 5. Gamification
**Files involved:** `gamification_service.dart`, `achievements_screen.dart`
**Working (A):**
- UI displays achievements correctly.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- **Security / Sanity:** `GamificationService.unlockAchievement()` writes to local `SharedPreferences` first, then syncs to Supabase. Furthermore, `getUnlockedAchievements()` merges remote data WITH local data and pushes local data to remote. Any user can edit their SharedPreferences to unlock all achievements, and the app will permanently save it to the server.
**User friction (E):**
- Treating medication adherence for chronic illnesses like a video game can feel patronizing to older adults.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Gamification should reward the *caregiver* (e.g., peace of mind), not just give the patient a digital badge.

---

## MODULE: 6. Vitals
**Files involved:** `vitals_screen.dart`, `vitals_input_sheet.dart`, `vitals_service.dart`
**Working (A):**
- Saving BP, HR, Weight to DB.
**Broken (B):**
- Offline saving for vitals does not use the `OfflineSyncService`.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- Manual entry of Blood Pressure via small text fields is difficult for users with arthritis or poor vision.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Bluetooth syncing with common Omron BP cuffs or Apple Health/Google Fit.

---

## MODULE: 7. Vault / Health Records
**Files involved:** `vault_screen.dart`, `records_screen.dart`, `record_upload_sheet.dart`
**Working (A):**
- PDF/Image uploading to Supabase Storage and generating signed URLs for viewing.
**Broken (B):**
- **Security Flaw:** `member_permissions_screen.dart` sets a `can_view_records` flag. `health_hub_screen.dart` checks this flag to hide the "Records" tab. However, `records_screen.dart` itself **does not check the permission at all**. If a user is deep-linked or navigates to the screen directly, they can view all records regardless of permission.
**Partial (C):**
- `FullScreenImageViewer` will fail if the 3600-second signed URL expires while the user is viewing it.
**Fake/UI-only (D):**
- Permission enforcement is UI-only tab hiding.
**User friction (E):**
- Complete confusion between what goes in the "Vault" vs "Records".
**Conflicts with old code (F):**
- **Massive duplicate:** `vault_screen.dart` and `records_screen.dart` do the exact same thing.
**Missing for real patient (G):**
- Automatic categorization (e.g., tagging a document as "Lab Result" automatically via OCR).

---

## MODULE: 8. Health Hub
**Files involved:** `health_hub_screen.dart`, `health_overview_tab.dart`
**Working (A):**
- Tab routing and segment controls.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- Placeholders for empty tabs.
**User friction (E):**
- Horizontal scrolling tabs (Overview, Vitals, Symptoms, Appointments, Records, Reports) are notoriously difficult for elderly users to discover.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- A unified chronological timeline of all health events instead of siloed tabs.

---

## MODULE: 9. Symptoms tracking
**Files involved:** `symptoms_screen.dart`, `symptom_entry_sheet.dart`
**Working (A):**
- DB insertion of symptoms.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- 1-10 slider for severity is highly subjective and hard to tap accurately on small screens.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- A visual body map to tap where the pain is.

---

## MODULE: 10. Appointments
**Files involved:** `appointment_screen.dart`, `appointment_detail_screen.dart`, `appointment_prep_report_screen.dart`
**Working (A):**
- Listing appointments and notes.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- **Fake Report:** The "Prep Report" feature in `appointment_prep_report_screen.dart` is literally just a `StringBuffer` that creates a long block of text and triggers the native OS Share sheet. It does not generate an official PDF or document.
**User friction (E):**
- Text dump looks unprofessional if emailed to a doctor.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- "Add to Device Calendar" button.

---

## MODULE: 11. Reports
**Files involved:** `reports_screen.dart`, `report_preview_screen.dart`, `reports_service.dart`, `reports_provider.dart`
**Working (A):**
- Actually pulls real data from DB (meds, vitals, symptoms) and generates a legitimate PDF using the `pdf` package.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- None.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Direct secure fax/email to provider.

---

## MODULE: 12. Family Hub v2
**Files involved:** `family_hub_v2_screen.dart`, `family_members_screen.dart`, `family_tasks_screen.dart`, `family_updates_screen.dart`, etc.
**Working (A):**
- Realtime alerts via Supabase channels. Quick actions.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- Cognitive overload. The dashboard features Tasks, Updates, Alerts, Events, and Pending Approvals all at once. For a caregiver, it's confusing to know if "Give Mom Medicine" should be a Task, an Event, or an Alarm.
**Conflicts with old code (F):**
- **Parallel Universes:** `family_hub_screen.dart` (old) and `family_hub_v2_screen.dart` (new) both exist in the codebase.
**Missing for real patient (G):**
- A simple "I'm OK" check-in button for the patient.

---

## MODULE: 13. Safety Center
**Files involved:** `emergency_center_screen.dart`, `medical_id_screen.dart`
**Working (A):**
- Form saves and displays critical data.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- None.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Lock screen widget. If the phone is locked during a medical emergency, EMTs cannot see this screen.

---

## MODULE: 14. Prescription Scanner
**Files involved:** `prescription_screen.dart`, `ocr_service.dart`, `prescription_service.dart`
**Working (A):**
- End-to-end integration of Google MLKit (OCR) and Gemini 1.5 Flash (AI Parsing) works seamlessly.
**Broken (B):**
- Fails catastrophically if the Gemini API key is missing from `.env` or rate limits are hit.
**Partial (C):**
- Relies on Gemini adhering perfectly to a JSON schema. If the LLM hallucinates markdown, the `jsonDecode` will throw.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- No manual review screen. Users should review the AI's output before it gets injected directly into the Add Medicine wizard.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Barcode/QR code scanning for exact NDC (National Drug Code) matching.

---

## MODULE: 15. Notification Inbox
**Files involved:** `notification_inbox_screen.dart`
**Working (A):**
- Displays standard notifications.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- Completely separate from the Alarms system. A missed alarm does not show up here logically, creating two places to check.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Actionable buttons inside the inbox (e.g., "Take Med" directly from the notification list).

---

## MODULE: 16. Settings
**Files involved:** `settings_screen.dart`, `family_notifications_screen.dart`
**Working (A):**
- Standard UI toggles.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- None.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- A global "Text Size" accessibility multiplier.

---

## MODULE: 17. Support
**Files involved:** `help_center_screen.dart`, `legal_content_screen.dart`
**Working (A):**
- Static text displays.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- None.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- Video tutorials for elderly users.

---

## MODULE: 18. Offline Sync Service & Isar
**Files involved:** `offline_sync_service.dart`, `isar_provider.dart`
**Working (A):**
- Connectivity listener correctly triggers sync for queued items.
**Broken (B):**
- **Catastrophic Failure:** `alarm_action_engine.dart` NEVER calls `enqueueAction()`. Doses taken offline are completely lost. Medication additions offline are not queued.
**Partial (C):**
- **Data Loss on Sync:** For quantity updates, `OfflineSyncService` blindly executes `update({'qty': payload_qty})`. If Caregiver A adds 30 pills online, and Patient B takes 1 pill offline, when Patient B comes online, the database quantity is overwritten back to the offline cached state, deleting the caregiver's refill!
**Fake/UI-only (D):**
- None.
**User friction (E):**
- "Why did my meds disappear?" - Data loss due to blind overwrites.
**Conflicts with old code (F):**
- None.
**Missing for real patient (G):**
- True conflict resolution (e.g., `db_qty = db_qty - amount_taken`).

---

## MODULE: 19. Activity Feed
**Files involved:** `activity_feed_screen.dart`, `activity_service.dart`
**Working (A):**
- UI renders events.
**Broken (B):**
- None.
**Partial (C):**
- None.
**Fake/UI-only (D):**
- None.
**User friction (E):**
- Causes severe confusion. Users do not know the difference between "Activity Feed" and "Family Updates".
**Conflicts with old code (F):**
- Completely redundant parallel feature.
**Missing for real patient (G):**
- None.

---

## TOP 10 THINGS TO FIX FIRST
*(Ranked by user pain × frequency of use)*

1. **Offline Dose Logging is Broken (Critical Data Loss)**
   - **What's broken:** `alarm_action_engine.dart` tries to hit Supabase directly when a user taps "Take", catches the offline exception, and silently drops the log. `OfflineSyncService` is completely ignored.
   - **Why it matters:** An elderly user will tap "Take" while on a walk with no cellular service. The alarm will stop, but the dose will never be recorded. Caregivers will panic thinking meds were missed.
   - **Effort:** 3 hours (Refactor `AlarmActionEngine` to route all inserts through `OfflineSyncService`).

2. **Offline Quantity Sync Causes Data Loss (Silent Overwrites)**
   - **What's broken:** `OfflineSyncService` uses literal integer overwrites (`update {'qty': 14}`) instead of decrementing. 
   - **Why it matters:** If a caregiver refills meds (+30) online, but the patient's offline phone syncs a cached quantity of 14, the refill is erased. 
   - **Effort:** 2 hours (Use RPC `decrement_medicine_qty` instead of direct updates).

3. **Fake Permission Enforcement (Security Risk)**
   - **What's broken:** `member_permissions_screen.dart` sets `can_view_records`, but `records_screen.dart` never checks it. It only hides the UI tab.
   - **Why it matters:** A tech-savvy teenager or malicious actor could bypass the UI and view highly sensitive medical records.
   - **Effort:** 1 hour (Add auth check directly in `_fetchRecords`).

4. **Gamification Can Be Faked Client-Side**
   - **What's broken:** `GamificationService` writes to `SharedPreferences` unconditionally, and the app trusts local storage as the source of truth, pushing it to Supabase.
   - **Why it matters:** A user can edit their local storage to fake a 100-day streak, deceiving their caregiver.
   - **Effort:** 2 hours (Move achievement unlocking logic to a secure Supabase Edge Function or Database Trigger).

5. **5-Step Medicine Wizard is Exhausting**
   - **What's broken:** UI/UX friction. 5 pages just to add a daily aspirin.
   - **Why it matters:** A 65-year-old will abandon the app on day one.
   - **Effort:** 6 hours (Condense to a single page for 90% of use cases, hiding "Tapered" and "Specific Dates" behind an "Advanced" toggle).

6. **Missing "Skip All for Today" on Alarms**
   - **What's broken:** No easy way to pause alarms for a day.
   - **Why it matters:** If a patient is hospitalized, their phone will ring 8 times a day, deeply annoying them and the nursing staff.
   - **Effort:** 2 hours.

7. **"Prep Report" is a Fake Feature**
   - **What's broken:** `appointment_prep_report_screen.dart` just dumps text into a native Share sheet instead of creating a PDF like the real Reports module.
   - **Why it matters:** Looks incredibly unprofessional if handed to a doctor.
   - **Effort:** 3 hours (Wire it up to `reports_service.dart`'s PDF generator).

8. **Horizontal Scroll Tabs in Health Hub**
   - **What's broken:** UI/UX. Older adults often do not realize horizontal scrolling exists.
   - **Why it matters:** They will never find the "Records" or "Reports" tabs.
   - **Effort:** 1 hour (Switch to a vertical list or a wrap layout).

9. **Missing Caregiver Escalation**
   - **What's broken:** If an alarm is ignored, it just stops. 
   - **Why it matters:** The whole point of a "Family Care" app is to notify the family when something is wrong.
   - **Effort:** 4 hours (Add a cron job or delayed background task to alert caregivers if dose remains unlogged).

10. **Duplicate Data Models (`medicine_model.dart` vs `medicine_entity.dart`)**
    - **What's broken:** Architectural tech debt.
    - **Why it matters:** Every time you add a field (like "requires_food"), you have to update two models, the Isar schema, the Supabase schema, and the mapping logic.
    - **Effort:** 8 hours (Unify models).

---

## TOP 5 FEATURES TO REMOVE OR MERGE
*(Be brutal. Less is more.)*

1. **Vault / Health Records**
   - **Action:** REMOVE `vault_screen.dart`.
   - **Why:** It does the exact same thing as `records_screen.dart`. Having both creates massive confusion for users trying to find their uploaded lab results.

2. **Activity Feed vs Family Updates**
   - **Action:** MERGE into one single "Timeline".
   - **Why:** They are redundant. A single timeline should show "Mom took Aspirin" (Activity) AND "Dad left a comment: Great job!" (Update).

3. **Family Hub vs Family Hub v2**
   - **Action:** DELETE the old `family_hub_screen.dart`.
   - **Why:** It's technical debt. Having parallel screens means old navigation paths might accidentally trap users in deprecated UI.

4. **"Tapered Dose" & "Every X Days" Schedules**
   - **Action:** HIDE or REMOVE for now.
   - **Why:** They add immense complexity to the `add_medicine_wizard.dart` and `recalcQty()` logic for < 1% of use cases. Keep it to Daily, Custom, or PRN.

5. **Gamification (For Patients)**
   - **Action:** REMOVE from patient view.
   - **Why:** A 70-year-old taking heart medication does not want a digital badge. It infantilizes the user. Instead, reframe it as "Caregiver Peace of Mind" metrics.
