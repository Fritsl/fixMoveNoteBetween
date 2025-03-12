/*
  # Add images support for notes

  1. New Tables
    - `note_images`
      - `id` (uuid, primary key)
      - `note_id` (uuid, references notes.id)
      - `url` (text, stores image URL)
      - `position` (integer, for ordering images)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `note_images` table
    - Add policies for authenticated users to manage their images
*/

CREATE TABLE IF NOT EXISTS note_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  url text NOT NULL,
  position integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS note_images_note_id_idx ON note_images(note_id);

-- Enable RLS
ALTER TABLE note_images ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Users can insert their own note images"
  ON note_images
  FOR INSERT
  TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_id
      AND notes.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can view their own note images"
  ON note_images
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_id
      AND notes.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can update their own note images"
  ON note_images
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_id
      AND notes.user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_id
      AND notes.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can delete their own note images"
  ON note_images
  FOR DELETE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes
      WHERE notes.id = note_id
      AND notes.user_id = auth.uid()
    )
  );