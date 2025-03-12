/*
  # Set up storage bucket for note images
  
  1. Storage Setup
    - Create 'note-images' bucket if it doesn't exist
    - Set bucket to private (not public)
    
  2. Security
    - Enable RLS on storage.objects
    - Drop existing policies to avoid conflicts
    - Add policies for authenticated users to:
      - Upload images to their own folder
      - Read their own images
      - Delete their own images
*/

-- Create bucket for note images if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can upload own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;

-- Allow authenticated users to upload images to their own folder
CREATE POLICY "Users can upload own images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'note-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to read their own images
CREATE POLICY "Users can read own images"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'note-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to delete their own images
CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'note-images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);