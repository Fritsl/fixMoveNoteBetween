/*
  # Fix image storage and note_images table

  1. Tables
    - Create note_images table to track images associated with notes
    - Add proper foreign key constraints and indexes

  2. Storage
    - Create storage bucket for note images
    - Set up RLS policies for secure access
*/

-- Create note_images table if it doesn't exist
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

-- Enable RLS
ALTER TABLE note_images ENABLE ROW LEVEL SECURITY;

-- Create storage bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('note-images', 'note-images', true)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS on storage.objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can upload their own images" ON storage.objects;
DROP POLICY IF EXISTS "Users can view images from their notes" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;

-- Create policies for note_images table
CREATE POLICY "Users can manage their own note images"
ON note_images
USING (
  EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
    AND notes.user_id = auth.uid()
  )
);

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
  EXISTS (
    SELECT 1 FROM note_images
    JOIN notes ON notes.id = note_images.note_id
    WHERE 
      note_images.storage_path = storage.objects.name AND
      notes.user_id = auth.uid()
  )
);

CREATE POLICY "Users can delete their own images"
ON storage.objects
FOR DELETE TO authenticated
USING (
  bucket_id = 'note-images' AND
  (storage.foldername(name))[1] = auth.uid()::text
);