/*
  # Add project_id to notes table

  1. Changes
    - Add `project_id` column to notes table
    - Add foreign key constraint to settings table
    - Update existing notes to link to current project
    - Add index for performance

  2. Security
    - Maintain existing RLS policies
*/

-- Add project_id column
ALTER TABLE notes ADD COLUMN project_id uuid REFERENCES settings(id);

-- Create index for performance
CREATE INDEX notes_project_id_idx ON notes(project_id);

-- Update existing notes to link to their project
DO $$
DECLARE
  user_record RECORD;
  project_record RECORD;
BEGIN
  FOR user_record IN SELECT DISTINCT user_id FROM notes
  LOOP
    -- Get the user's first project
    SELECT id INTO project_record
    FROM settings
    WHERE user_id = user_record.user_id
    ORDER BY created_at ASC
    LIMIT 1;

    -- Update notes to link to the project
    IF project_record.id IS NOT NULL THEN
      UPDATE notes
      SET project_id = project_record.id
      WHERE user_id = user_record.user_id;
    END IF;
  END LOOP;
END $$;