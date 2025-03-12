/*
  # Set up storage bucket for note images

  1. New Storage Bucket
    - Creates a private bucket called 'note-images' for storing note attachments
  
  2. Security
    - Enables RLS on storage.objects table
    - Adds policies for authenticated users to:
      - Upload images to their own folder
      - Read their own images
      - Delete their own images
*/

-- Create bucket for note images if it doesn't exist
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('note-images', 'note-images', false)
  ON CONFLICT (id) DO NOTHING;
END $$;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to upload images to their own folder
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Users can upload own images'
  ) THEN
    CREATE POLICY "Users can upload own images"
    ON storage.objects FOR INSERT TO authenticated
    WITH CHECK (
      bucket_id = 'note-images' AND
      auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- Allow authenticated users to read their own images
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Users can read own images'
  ) THEN
    CREATE POLICY "Users can read own images"
    ON storage.objects FOR SELECT TO authenticated
    USING (
      bucket_id = 'note-images' AND
      auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;

-- Allow authenticated users to delete their own images
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Users can delete own images'
  ) THEN
    CREATE POLICY "Users can delete own images"
    ON storage.objects FOR DELETE TO authenticated
    USING (
      bucket_id = 'note-images' AND
      auth.uid()::text = (storage.foldername(name))[1]
    );
  END IF;
END $$;