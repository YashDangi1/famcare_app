# FamCare App: Features & Properties

This document outlines the core features, modules, and technical properties of the FamCare app, based on its current codebase architecture.

## 1. Authentication & User Management
* **Login & Authentication:** User authentication flow (`login_screen.dart`).
* **Profile Setup:** User profile creation and management (`profile_setup_screen.dart`).
* **Settings & Preferences:** Customizable user settings (`settings_screen.dart`).
* **Theming:** Light and Dark mode support (`theme_provider.dart`).

## 2. Family Hub & Collaboration
* **Family Dashboard:** Centralized view for family members (`family_hub_screen.dart`).
* **Group Alarms:** Shared alarms for family medication/care coordination (`group_alarm_screen.dart`).
* **Activity Feed:** Real-time updates on family members' health activities (`activity_feed_screen.dart`, `activity_service.dart`).

## 3. Medication Management (Core Feature)
* **Medication Inventory:** View and manage current medications (`meds_screen.dart`).
* **Medicine Logging:** Track daily intake and adherence (`medicine_log_screen.dart`).
* **Alarms & Reminders:** Complex scheduling and alarms for medications (`alarm_screen.dart`, `alarm_setup_screen.dart`, `alarm_service.dart`).
* **Prescriptions:** Digital prescription tracking and management (`prescription_screen.dart`, `prescription_service.dart`).
* **Smart OCR:** Optical Character Recognition for automatically parsing and digitizing physical prescriptions (`ocr_service.dart`).
* **Time Slot Preferences:** Customizable slots (morning, afternoon, night) for medicine scheduling (`slot_preferences_service.dart`).

## 4. Health & Vitals Tracking
* **Health Dashboard:** Overview of general health metrics (`health_dashboard_screen.dart`, `health_landing_screen.dart`).
* **Vitals Logging:** Input and track specific health vitals (e.g., BP, sugar) (`vitals_screen.dart`, `vitals_input_sheet.dart`, `vitals_service.dart`).
* **Medical History:** Ongoing tracking of user medical history (`history_service.dart`).
* **Appointments:** Manage doctor appointments and schedules (`appointment_screen.dart`).

## 5. Medical Vault
* **Document Storage:** Secure vault for storing sensitive medical records and documents (`vault_screen.dart`).

## 6. Technical Architecture & App Properties
* **Offline-First Capabilities:** Local data persistence and offline operations (`isar_provider.dart`, `medication_repository.dart`).
* **Background Processing:** Background task execution for reliable alarms and syncing (`background_service.dart`).
* **Offline Syncing:** Synchronization logic to keep local and cloud data consistent (`offline_sync_service.dart`).
* **Push Notifications:** Reminders and alerts powered by notifications (`notification_service.dart`).
* **Cloud Database:** Real-time backend data storage via Supabase (`database_service.dart`).
* **State Management:** Reactive state handling via providers (`medication_provider.dart`).
