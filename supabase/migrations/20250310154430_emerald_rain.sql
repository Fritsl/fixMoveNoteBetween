/*
  # Add discussion flag to notes

  1. Changes
    - Add `is_discussion` boolean column to notes table with default false
    - Add migration to handle existing notes
  
  2. Notes
    - Default value ensures backward compatibility
    - No data loss or schema changes required for existing notes
*/

-- Add is_discussion column with default value
ALTER TABLE notes ADD COLUMN IF NOT EXISTS is_discussion boolean DEFAULT false;

-- Update existing notes to have is_discussion set to false
UPDATE notes SET is_discussion = false WHERE is_discussion IS NULL;