/*
  # Add settings table for project customization

  1. New Tables
    - `settings`
      - `id` (uuid, primary key)
      - `user_id` (uuid, foreign key to users)
      - `title` (text, project title)
      - `created_at` (timestamp)
      - `updated_at` (timestamp)

  2. Security
    - Enable RLS on `settings` table
    - Add policies for authenticated users to:
      - Read their own settings
      - Create their own settings
      - Update their own settings
*/

-- Create the settings table if it doesn't exist
CREATE TABLE IF NOT EXISTS settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id),
  title text NOT NULL DEFAULT 'AI Workshop Notes',
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid conflicts
DO $$ 
BEGIN
  DROP POLICY IF EXISTS "Users can read own settings" ON settings;
  DROP POLICY IF EXISTS "Users can insert own settings" ON settings;
  DROP POLICY IF EXISTS "Users can update own settings" ON settings;
END $$;

-- Create policies
CREATE POLICY "Users can read own settings"
  ON settings
  FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
  ON settings
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
  ON settings
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);