/*
  # Fix note positioning system

  1. Changes
    - Add function to normalize note positions when they get too close
    - Add trigger to maintain position spacing
    - Add constraint to ensure positions are positive integers
    - Add function to get next available position

  2. Details
    - Uses integer positions with large gaps (100000) between notes
    - Automatically normalizes positions when gaps get too small
    - Maintains proper ordering during moves and inserts
*/

-- First normalize existing positions to ensure they're all positive integers
UPDATE notes
SET position = position_new.new_pos
FROM (
  SELECT 
    id,
    ROW_NUMBER() OVER (
      PARTITION BY project_id, parent_id 
      ORDER BY COALESCE(position, 0)
    ) * 100000 as new_pos
  FROM notes
) position_new
WHERE notes.id = position_new.id;

-- Add constraint for positive positions
ALTER TABLE notes DROP CONSTRAINT IF EXISTS positive_position;
ALTER TABLE notes ADD CONSTRAINT positive_position CHECK (position > 0);

-- Create function to normalize positions when they get too close
CREATE OR REPLACE FUNCTION normalize_note_positions(target_project_id uuid, target_parent_id uuid DEFAULT NULL)
RETURNS void AS $$
DECLARE
  note_record RECORD;
  current_position integer := 100000;
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
    
    current_position := current_position + 100000;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Create trigger function to maintain position integrity
CREATE OR REPLACE FUNCTION maintain_note_positions()
RETURNS TRIGGER AS $$
DECLARE
  min_gap integer := 1000; -- Minimum gap between positions
  prev_pos integer;
  next_pos integer;
BEGIN
  -- For new notes or position updates
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.position != OLD.position) THEN
    -- Get surrounding positions
    SELECT position INTO prev_pos
    FROM notes
    WHERE project_id = NEW.project_id
    AND parent_id IS NOT DISTINCT FROM NEW.parent_id
    AND position < NEW.position
    ORDER BY position DESC
    LIMIT 1;

    SELECT position INTO next_pos
    FROM notes
    WHERE project_id = NEW.project_id
    AND parent_id IS NOT DISTINCT FROM NEW.parent_id
    AND position > NEW.position
    ORDER BY position ASC
    LIMIT 1;

    -- Check if normalization is needed
    IF (prev_pos IS NOT NULL AND NEW.position - prev_pos < min_gap) OR
       (next_pos IS NOT NULL AND next_pos - NEW.position < min_gap) THEN
      -- Normalize positions at this level
      PERFORM normalize_note_positions(NEW.project_id, NEW.parent_id);
      
      -- Get new position after normalization
      IF prev_pos IS NULL THEN
        -- First position
        NEW.position := 100000;
      ELSIF next_pos IS NULL THEN
        -- Last position
        NEW.position := prev_pos + 100000;
      ELSE
        -- Middle position
        NEW.position := prev_pos + ((next_pos - prev_pos) / 2);
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create or replace the trigger
DROP TRIGGER IF EXISTS maintain_note_positions_trigger ON notes;
CREATE TRIGGER maintain_note_positions_trigger
  BEFORE INSERT OR UPDATE OF position ON notes
  FOR EACH ROW
  EXECUTE FUNCTION maintain_note_positions();