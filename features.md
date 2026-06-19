# FamCare App: Current Features

This document reflects the features currently present in the codebase.

## 1. App Entry & Navigation
- **Splash & Auth Routing:** Launches to login or app shell based on session (`splash_screen.dart`).
- **Main Sections:** Home, Meds, Health, Family, More (`main_app_shell.dart`).
- **Deep Linking Inside App:** Home quick actions open Health, Meds, Family, appointments, and records flows.

## 2. Authentication & Profile
- **Email Sign In / Sign Up:** Supabase-based auth (`login_screen.dart`).
- **First-Time Profile Setup:** Name, age, phone, blood group, avatar (`profile_setup_screen.dart`).
- **Account Settings:** Profile editing, avatar update, sign out, alarm style, slot preferences (`settings_screen.dart`, `more_screen.dart`).
- **Theme Support:** App theming via provider (`theme_provider.dart`, `app_theme.dart`).

## 3. Home Dashboard
- **Due Soon Panel:** Shows medicines needing action now with take/skip actions.
- **Today Overview:** Adherence progress, streak, family count, next medication.
- **Health Summaries:** Latest vital, next appointment, missed medicines.
- **Quick Actions:** Log vital, add medicine, open records, open family, book appointment.

## 4. Meds & Reminders
- **Medication Management:** View, filter, group, add, edit, and manage medicines (`meds_screen.dart`, `add_medicine_wizard.dart`).
- **Medicine Logs:** Track taken, skipped, missed, snoozed, and recent activity (`medicine_log_screen.dart`).
- **Slot Scheduling:** Morning, afternoon, evening, night, and custom time slots.
- **Alarm System:** Exact alarms, full-screen alarm UI, notification-only mode, snooze, retries, auto-stop, boot restore, and group slot alarms (`main.dart`, `alarm_screen.dart`, `group_alarm_screen.dart`, `alarm_service.dart`).
- **Low Stock & Refill Awareness:** Qty tracking and low-stock alerts.
- **Prescription Intake:** AI scan, OCR extraction, manual add, review list, and background DB save (`prescription_screen.dart`, `ocr_service.dart`, `prescription_service.dart`).

## 5. Health
- **Health Landing:** Entry point to dashboard, vitals, appointments, and records (`health_landing_screen.dart`).
- **Health Dashboard:** Active meds snapshot, low-stock snapshot, latest vitals (`health_dashboard_screen.dart`).
- **Vitals Tracking:** Add readings, latest summary, history, and heart-rate trend chart (`vitals_screen.dart`, `vitals_input_sheet.dart`, `vitals_service.dart`).
- **Appointments:** Create, list, delete, and optionally remind upcoming doctor visits (`appointment_screen.dart`).
- **Medical Records / Vault:** Upload and view prescription images and reports (`vault_screen.dart`).
- **Medical History Logging:** History entries for key actions (`history_service.dart`).

## 6. Family & Care Coordination
- **Family Groups:** Create family, join by invite code, manage members (`family_hub_screen.dart`).
- **Roles & Access:** Admin/member roles, approvals, promotion, and removal.
- **Shared Monitoring:** Open another member's health dashboard, vitals, appointments, and records.
- **Activity Feed:** Family updates grouped by date (`activity_feed_screen.dart`, `activity_service.dart`).
- **Caregiver Alerts:** WhatsApp alerts for missed doses, slot reminders, and low-stock events (`notification_service.dart`).

## 7. Reminder Setup & Permissions
- **Alarm Onboarding:** First-launch reminder permission flow (`alarm_setup_screen.dart`).
- **Permission Checks:** Notifications, exact alarms, battery optimization, Android 14 overlay/full-screen permissions.
- **Manufacturer Guidance:** OEM-specific background/autostart instructions for brands like Xiaomi, Oppo, Vivo, OnePlus, Huawei.

## 8. Technical Architecture
- **Supabase Backend:** Auth, database, storage, and edge-function based prescription parsing.
- **Offline Support:** Queued offline sync for selected actions (`offline_sync_service.dart`).
- **Local Persistence:** Isar entities/providers plus shared preferences.
- **State Management:** Riverpod/providers for meds, theme, and local app state.
- **Notifications & Background:** Local notifications, alarm callbacks, boot receiver, background execution.
- **Testing:** Unit, repository, widget, and integration tests in `test/` and `integration_test/`.
