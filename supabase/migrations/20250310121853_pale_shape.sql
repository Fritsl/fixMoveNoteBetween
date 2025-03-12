/*
  # Set up storage policies for note images
  
  1. Storage Policies
    - Drop existing policies if they exist to avoid conflicts
    - Create new policies for authenticated users to:
      - Upload images to their own folder
      - Read their own images
      - Delete their own images
*/

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Users can upload images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can read own images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;
END $$;

-- Create bucket if it doesn't exist
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

-- Allow authenticated users to upload images
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