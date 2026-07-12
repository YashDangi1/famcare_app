-- supabase/migrations/20260625000006_fix_report_export_audit.sql

alter table public.health_report_exports
  add column if not exists metadata jsonb not null default '{}'::jsonb;
