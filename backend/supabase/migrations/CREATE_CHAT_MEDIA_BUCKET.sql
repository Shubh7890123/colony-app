-- ============================================================
-- Create the 'chat_media' storage bucket for image attachments
-- Run this in Supabase SQL Editor (Dashboard -> SQL Editor)
-- ============================================================

-- 1. Create bucket (if it doesn't exist)
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat_media', 'chat_media', true)
ON CONFLICT (id) DO NOTHING;

-- 2. Allow authenticated users to upload their own files
CREATE POLICY "Users can upload their own chat media"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'chat_media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- 3. Allow public read access (images are served via public URL)
CREATE POLICY "Chat media is publicly readable"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat_media');

-- 4. Allow users to delete their own files
CREATE POLICY "Users can delete their own chat media"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'chat_media'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
