/*
  # Set up storage for note images
  
  1. Storage Setup
    - Create bucket for note images
    - Enable RLS on storage.objects
    - Create policies for authenticated users to:
      - Upload images to their own folder
      - Read their own images
      - Delete their own images
  
  2. Security
    - Bucket is private by default
    - Users can only access their own images
    - Images are stored in user-specific folders
*/

-- Create bucket for note images if it doesn't exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'note-images'
  ) THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('note-images', 'note-images', false);
  END IF;
END $$;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload images" ON storage.objects;
DROP POLICY IF EXISTS "Users can read own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;

-- Allow authenticated users to upload images to their own folder
CREATE POLICY "Users can upload images"
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