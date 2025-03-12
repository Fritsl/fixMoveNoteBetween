/*
  # Update note images to use binary storage

  1. Changes
    - Add storage_path column to note_images table
    - Make url column nullable (for backward compatibility)
    - Add policy for storage bucket access

  2. Security
    - Enable RLS on storage bucket
    - Add policies for authenticated users to manage their own images
*/

-- Add storage path column
ALTER TABLE note_images 
ADD COLUMN storage_path text;

-- Make url nullable for backward compatibility
ALTER TABLE note_images
ALTER COLUMN url DROP NOT NULL;

-- Create storage bucket for note images
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', false);

-- Enable RLS on the bucket
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow users to upload their own images
CREATE POLICY "Users can upload their own note images" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to read their own images
CREATE POLICY "Users can read their own note images" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Allow users to delete their own images
CREATE POLICY "Users can delete their own note images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );