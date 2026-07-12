-- supabase/migrations/20260621021500_copy_legacy_prescriptions.sql

-- Copy existing prescriptions into the new health_records table
INSERT INTO public.health_records (user_id, category, title, file_url, source, created_at)
SELECT 
    user_id, 
    'prescription' AS category, 
    title, 
    image_url AS file_url, 
    'legacy_prescription' AS source, 
    created_at
FROM public.prescriptions
ON CONFLICT DO NOTHING;
