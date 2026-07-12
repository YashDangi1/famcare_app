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
- **Medicine Logs & Insights:** Comprehensive analytics dashboard displaying a 7-day adherence score, weekly bar charts (`fl_chart`), chronological activity tracking, and a 1-click shareable adherence report for doctors via native OS share sheet (`share_plus`) (`medicine_log_screen.dart`).
- **Slot Scheduling:** Morning, afternoon, evening, night, and custom time slots.
- **Alarm System:** Exact alarms, full-screen alarm UI, notification-only mode, snooze, retries, auto-stop, boot restore, group slot alarms, and **Custom Ringtones** (`main.dart`, `alarm_screen.dart`, `alarm_service.dart`).
- **Alarm Action Engine:** Advanced duplicate protection and locking mechanism to prevent double-logging and double-deductions during rapid tap events.
- **Refill Center:** Dedicated UI for inventory management with low-stock sorting, dynamic days-left estimation, and 1-tap quick-add buttons (+10, +30).
- **Low Stock Safety Alerts:** Background watchdog tracking quantity deductions; triggers local push notifications and caregiver WhatsApp alerts when stock drops below threshold.
- **Prescription Intake:** AI scan, OCR extraction, manual add, review list, and background DB save (`prescription_screen.dart`, `ocr_service.dart`, `prescription_service.dart`).
- **UI Polish & Empty States:** Animated shimmer skeleton loaders, staggered micro-animations for list rendering, and contextual animated empty states (True Empty vs Filter Empty) via `flutter_animate`.

## 5. Health
- **Health Hub (New Architecture):** Centralized dashboard utilizing `IndexedStack` and a modern bottom navigation bar for quick access to Overview, Symptoms, Records, and Reports (`health_hub_screen.dart`).
- **Overview Dashboard:** Active meds snapshot, next appointment, and latest vitals summary (`overview_screen.dart`).
- **Symptoms Tracking:** Securely log pain levels, triggers, duration, and rich notes. Tracks severity out of 5 with dynamic color coding (`symptoms_screen.dart`, `symptom_entry_sheet.dart`).
- **Medical Records Vault:** Categorized document vault (Prescriptions, Lab Reports, Imaging, etc.) hooked directly to Supabase Storage with secure signed URLs and full-screen image viewing (`records_screen.dart`).
- **Appointments Pro:** Dynamic upcoming/past tabs, detailed visit notes, specialty tracking, and "Mark as Completed" workflow with local alarm cancellations (`appointment_screen.dart`, `appointment_detail_screen.dart`).
- **Health Reports Engine:** Generates comprehensive PDF summaries combining active medications, recent vitals, and symptoms. Includes live HTML preview and native share/print capabilities via `pdf` and `printing` packages (`reports_screen.dart`, `report_preview_screen.dart`).
- **Vitals Tracking:** Add readings (BP, HR, SpO2, Weight, Temp), latest summary, history, and interactive heart-rate trend chart (`vitals_screen.dart`, `vitals_input_sheet.dart`, `vitals_service.dart`).

## 6. Family & Care Coordination
- **Family Groups:** Create family, join by invite code, manage members (`family_hub_screen.dart`).
- **Granular Permissions & RLS:** Deep Row Level Security (RLS) enforcement ensuring family members can only read health data (Vitals, Records, Appointments, Symptoms) if explicitly approved by the owner (`family_hub_foundation.sql`, `health_family_rls_policies.sql`).
- **Read-Only Shared UI:** Automatically hides floating action buttons, edit features, and swipe-to-delete gestures when viewing another family member's health profiles (`isViewingOther` logic across all health screens).
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
