-- Meesho Entry Bills (PDF): Supabase Storage Policies
-- Run in Supabase Dashboard -> SQL Editor
-- Bucket name expected: meesho-entry-bills
-- Note: If you want to open PDFs via getPublicUrl(), set bucket to Public in Storage.

-- IMPORTANT:
-- Policies do NOT create buckets. Create the bucket first (UI or SQL below),
-- otherwise uploads will fail with "Bucket not found".

-- Create bucket if missing (and set public=true so getPublicUrl() works)
-- If you want private PDFs, set public=false and use signed URLs in frontend.
insert into storage.buckets (id, name, public)
values ('meesho-entry-bills', 'meesho-entry-bills', true)
on conflict (id) do update set
	name = excluded.name,
	public = excluded.public;

-- Allow authenticated users to upload PDFs into this bucket
DROP POLICY IF EXISTS "meesho_bills_insert" ON storage.objects;
CREATE POLICY "meesho_bills_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'meesho-entry-bills');

-- Allow authenticated users to update/replace PDFs in this bucket
DROP POLICY IF EXISTS "meesho_bills_update" ON storage.objects;
CREATE POLICY "meesho_bills_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'meesho-entry-bills')
WITH CHECK (bucket_id = 'meesho-entry-bills');

-- Allow authenticated users to delete PDFs in this bucket
DROP POLICY IF EXISTS "meesho_bills_delete" ON storage.objects;
CREATE POLICY "meesho_bills_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'meesho-entry-bills');

-- Public read (optional). If your bucket is already Public in dashboard,
-- this policy makes reads work even when RLS is on.
DROP POLICY IF EXISTS "meesho_bills_select_public" ON storage.objects;
CREATE POLICY "meesho_bills_select_public"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'meesho-entry-bills');
