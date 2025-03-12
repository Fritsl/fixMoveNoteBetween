/*
  # Create notes table with proper UUID types

  1. New Tables
    - `notes`
      - `id` (uuid, primary key)
      - `content` (text)
      - `parent_id` (uuid, references notes.id)
      - `user_id` (uuid, references auth.users.id)
      - `position` (integer)
      - `created_at` (timestamptz)
      - `updated_at` (timestamptz)

  2. Security
    - Enable RLS on `notes` table
    - Add policies for authenticated users to:
      - Read their own notes
      - Insert their own notes
      - Update their own notes
      - Delete their own notes
*/

CREATE TABLE IF NOT EXISTS notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content text DEFAULT '',
  parent_id uuid REFERENCES notes(id),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  position integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE notes ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read their own notes
CREATE POLICY "Users can read own notes"
  ON notes
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- Policy: Users can insert their own notes
CREATE POLICY "Users can insert own notes"
  ON notes
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can update their own notes
CREATE POLICY "Users can update own notes"
  ON notes
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Policy: Users can delete their own notes
CREATE POLICY "Users can delete own notes"
  ON notes
  FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);