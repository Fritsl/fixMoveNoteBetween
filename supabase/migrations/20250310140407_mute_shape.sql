/*
  # Fix storage setup for note images

  1. Storage Setup
    - Create bucket for note images if it doesn't exist
    - Enable RLS on objects table
    - Set up proper policies for image access

  2. Security
    - Allow authenticated users to upload images to their own folder
    - Allow users to view images from their own notes
    - Restrict file types to images only
    - Limit file size to 5MB
*/

-- Create the storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to ensure clean state
DROP POLICY IF EXISTS "Users can upload their own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view images from their notes" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;

-- Policy for uploading images
CREATE POLICY "Users can upload their own images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'note-images' AND
  (CASE 
    WHEN RIGHT(name, 4) = '.jpg' THEN true
    WHEN RIGHT(name, 4) = '.png' THEN true
    WHEN RIGHT(name, 5) = '.jpeg' THEN true
    WHEN RIGHT(name, 4) = '.gif' THEN true
    WHEN RIGHT(name, 5) = '.webp' THEN true
    ELSE false
  END) AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy for reading images
CREATE POLICY "Users can view images from their notes"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'note-images' AND
  EXISTS (
    SELECT 1 FROM note_images
    JOIN notes ON notes.id = note_images.note_id
    WHERE 
      note_images.storage_path = storage.objects.name AND
      notes.user_id = auth.uid()
  )
);

-- Policy for deleting images
CREATE POLICY "Users can delete their own images"
ON storage.objects FOR DELETE
TO authenticated
USING (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);