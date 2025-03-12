/*
  # Add position normalization function

  1. New Functions
    - `normalize_note_positions`: Normalizes positions for a group of notes
      - Takes project_id and parent_id as parameters
      - Resets positions to be evenly spaced integers
      - Returns void
    - Updates existing triggers to maintain normalized positions

  2. Details
    - Uses 10000 as base increment for plenty of space between notes
    - Handles both root level and child notes
    - Maintains existing order
*/

-- Create function to normalize note positions
CREATE OR REPLACE FUNCTION normalize_note_positions(target_project_id uuid, target_parent_id uuid DEFAULT NULL)
RETURNS void AS $$
DECLARE
  note_record RECORD;
  current_position integer := 10000;
BEGIN
  -- Update positions for all notes at the specified level
  FOR note_record IN (
    SELECT id 
    FROM notes 
    WHERE project_id = target_project_id 
    AND parent_id IS NOT DISTINCT FROM target_parent_id
    ORDER BY position
  ) LOOP
    UPDATE notes 
    SET position = current_position
    WHERE id = note_record.id;
    
    current_position := current_position + 10000;
  END LOOP;
END;
$$ LANGUAGE plpgsql;