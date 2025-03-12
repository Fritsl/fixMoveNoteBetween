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

  Note: This migration creates a new storage bucket and sets up the necessary
  security policies to ensure users can only access their own images while
  making them publicly viewable.
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

-- Drop existing policies if they exist
DO $$
BEGIN
  -- Upload policy
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can upload note images'
  ) THEN
    DROP POLICY IF EXISTS "Users can upload note images" ON storage.objects;
  END IF;

  -- View policy
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Anyone can view note images'
  ) THEN
    DROP POLICY IF EXISTS "Anyone can view note images" ON storage.objects;
  END IF;

  -- Delete policy
  IF EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE schemaname = 'storage' 
    AND tablename = 'objects' 
    AND policyname = 'Users can delete their note images'
  ) THEN
    DROP POLICY IF EXISTS "Users can delete their note images" ON storage.objects;
  END IF;
END $$;

-- Create new policies with unique names
CREATE POLICY "Users can upload note images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Anyone can view note images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'note-images');

CREATE POLICY "Users can delete their note images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );