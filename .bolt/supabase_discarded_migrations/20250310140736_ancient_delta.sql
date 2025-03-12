/*
  # Fix image storage and policies

  1. Storage
    - Create note-images bucket if it doesn't exist
    - Set up proper RLS policies for secure access
    - Fix image access and upload permissions

  2. Tables
    - Ensure note_images table exists with proper structure
    - Add RLS policies for note_images table
*/

-- Create storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can upload their own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view images from their notes" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;

-- Create storage policies
CREATE POLICY "Users can upload their own images"
ON storage.objects
FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can view images from their notes"
ON storage.objects
FOR SELECT TO authenticated
USING (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

CREATE POLICY "Users can delete their own images"
ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Ensure note_images table exists
CREATE TABLE IF NOT EXISTS note_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  url text,
  storage_path text,
  position integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS note_images_note_id_idx ON note_images(note_id);

-- Enable RLS on note_images
ALTER TABLE note_images ENABLE ROW LEVEL SECURITY;

-- Create RLS policy for note_images
CREATE POLICY "Users can manage their own note images"
ON note_images FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
);