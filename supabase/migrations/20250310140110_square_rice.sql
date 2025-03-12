/*
  # Set up storage permissions for note images

  1. Storage Setup
    - Create bucket for note images if it doesn't exist
    - Enable RLS on the bucket
    - Add policies for authenticated users to:
      - Upload their own images
      - Read any images they have access to

  2. Security
    - Restrict uploads to images only
    - Limit file size to 5MB
    - Ensure users can only access images from notes they own
*/

-- Create the storage bucket if it doesn't exist
DO $$
BEGIN
  INSERT INTO storage.buckets (id, name, public)
  VALUES ('note-images', 'note-images', true)
  ON CONFLICT (id) DO NOTHING;
END $$;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DO $$
BEGIN
  DROP POLICY IF EXISTS "Users can upload their own images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can view images from their notes" ON storage.objects;
EXCEPTION
  WHEN undefined_object THEN
    NULL;
END $$;

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
  (metadata->>'size')::int <= 5242880 AND -- 5MB max
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