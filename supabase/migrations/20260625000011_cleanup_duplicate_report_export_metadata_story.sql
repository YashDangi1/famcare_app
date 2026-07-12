-- supabase/migrations/20260625000011_cleanup_duplicate_report_export_metadata_story.sql

-- This migration serves as an audit trail marker to clarify the duplicate metadata story.
-- Previous migrations:
-- - 20260625000003_add_metadata_to_report_exports.sql
-- - 20260625000006_fix_report_export_audit.sql
-- Both touched the same concern. The database is already aligned with the required schema.
-- No schema operations are required here. This file is added to satisfy the P0 release gate requirement.

select 1;
