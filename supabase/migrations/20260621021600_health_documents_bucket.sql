-- supabase/migrations/20260621021600_health_documents_bucket.sql

INSERT INTO storage.buckets (id, name, public) 
VALUES ('health_documents', 'health_documents', true)
ON CONFLICT (id) DO NOTHING;

-- Policies for health_documents
DROP POLICY IF EXISTS "Health documents are publicly accessible." on storage.objects;
create policy "Health documents are publicly accessible."
  on storage.objects for select
  using ( bucket_id = 'health_documents' );

DROP POLICY IF EXISTS "Users can upload health documents." on storage.objects;
create policy "Users can upload health documents."
  on storage.objects for insert
  with check ( bucket_id = 'health_documents' AND auth.role() = 'authenticated' );

DROP POLICY IF EXISTS "Users can update their own health documents." on storage.objects;
create policy "Users can update their own health documents."
  on storage.objects for update
  using ( bucket_id = 'health_documents' AND auth.uid() = owner )
  with check ( bucket_id = 'health_documents' AND auth.uid() = owner );

DROP POLICY IF EXISTS "Users can delete their own health documents." on storage.objects;
create policy "Users can delete their own health documents."
  on storage.objects for delete
  using ( bucket_id = 'health_documents' AND auth.uid() = owner );
