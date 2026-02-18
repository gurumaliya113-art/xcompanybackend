-- Meesho Entry Images: Supabase Storage Policies
-- Run in Supabase Dashboard -> SQL Editor
-- Bucket name expected: meesho-entry-images

-- Storage tables already exist in Supabase projects.

-- Allow authenticated users to upload images into this bucket
DROP POLICY IF EXISTS "meesho_images_insert" ON storage.objects;
CREATE POLICY "meesho_images_insert"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'meesho-entry-images');

-- Allow authenticated users to update/replace images in this bucket
DROP POLICY IF EXISTS "meesho_images_update" ON storage.objects;
CREATE POLICY "meesho_images_update"
ON storage.objects
FOR UPDATE
TO authenticated
USING (bucket_id = 'meesho-entry-images')
WITH CHECK (bucket_id = 'meesho-entry-images');

-- Allow authenticated users to delete images in this bucket
DROP POLICY IF EXISTS "meesho_images_delete" ON storage.objects;
CREATE POLICY "meesho_images_delete"
ON storage.objects
FOR DELETE
TO authenticated
USING (bucket_id = 'meesho-entry-images');

-- Public read (optional). If your bucket is already Public in dashboard,
-- this policy makes reads work even when RLS is on.
DROP POLICY IF EXISTS "meesho_images_select_public" ON storage.objects;
CREATE POLICY "meesho_images_select_public"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'meesho-entry-images');
