/*
  # Add discussion flag to notes

  1. Changes
    - Add `is_discussion` boolean column to `notes` table with default value of false
    - Update RLS policies to maintain existing security model

  2. Security
    - Maintain existing RLS policies
    - No additional policies needed as the column inherits existing note-level security
*/

-- Add is_discussion column with default value
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notes' AND column_name = 'is_discussion'
  ) THEN
    ALTER TABLE notes ADD COLUMN is_discussion boolean DEFAULT false;
  END IF;
END $$;