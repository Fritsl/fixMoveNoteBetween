/*
  # Set up storage for note images

  1. Storage Setup
    - Create 'note-images' bucket for storing note images
    - Enable public access to the bucket

  2. Security
    - Add RLS policies for:
      - Upload: Only authenticated users can upload to their own folder
      - View: Public access to all images
      - Delete: Users can only delete their own images
*/

-- Create the storage bucket if it doesn't exist
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'note-images'
  ) THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('note-images', 'note-images', true);
  END IF;
END $$;

-- Drop existing policies if they exist and recreate them
DO $$
BEGIN
  -- Upload policy
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Users can upload images'
  ) THEN
    DROP POLICY IF EXISTS "Users can upload images" ON storage.objects;
  END IF;

  -- View policy
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Anyone can view images'
  ) THEN
    DROP POLICY IF EXISTS "Anyone can view images" ON storage.objects;
  END IF;

  -- Delete policy
  IF EXISTS (
    SELECT 1 FROM pg_policies WHERE policyname = 'Users can delete their own images'
  ) THEN
    DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;
  END IF;
END $$;

-- Create policies
CREATE POLICY "Users can upload images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Anyone can view images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'note-images');

CREATE POLICY "Users can delete their own images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );