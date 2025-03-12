/*
  # Create storage bucket for note images

  1. Storage
    - Create a new public bucket for note images
    - Enable RLS on the bucket
    - Add policies for authenticated users to manage their own images

  2. Security
    - Enable RLS on storage bucket
    - Add policies for authenticated users to:
      - Upload images
      - Read their own images
      - Delete their own images
*/

-- Create a new bucket for note images
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true);

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Allow authenticated users to upload images
CREATE POLICY "Users can upload images"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to read their own images
CREATE POLICY "Users can read own images"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to delete their own images
CREATE POLICY "Users can delete own images"
ON storage.objects FOR DELETE TO authenticated
USING (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);