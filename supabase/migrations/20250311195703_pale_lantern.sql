/*
  # Fix note position handling

  1. Changes
    - Drop existing position constraint
    - Add new position constraint with default value
    - Update trigger to handle position assignment better
    - Fix position normalization function

  2. Details
    - Ensures positions are always positive
    - Uses large gaps between positions (100,000)
    - Handles edge cases better
*/

-- Drop existing position constraint
ALTER TABLE notes DROP CONSTRAINT IF EXISTS positive_position;

-- Add new position constraint with better default
ALTER TABLE notes 
  ADD CONSTRAINT positive_position 
  CHECK (position > 0);

-- Update position column to have a default value
ALTER TABLE notes 
  ALTER COLUMN position 
  SET DEFAULT 100000;

-- Create function to normalize positions
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
  last_position integer;
BEGIN
  -- For new notes or position updates
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.position != OLD.position) THEN
    -- Get the highest position at this level
    SELECT COALESCE(MAX(position), 0)
    INTO last_position
    FROM notes
    WHERE project_id = NEW.project_id
    AND parent_id IS NOT DISTINCT FROM NEW.parent_id;

    -- Set position for new notes
    IF TG_OP = 'INSERT' THEN
      NEW.position := GREATEST(last_position + 100000, 100000);
    END IF;

    -- Normalize if position gets too large
    IF NEW.position >= 1000000000 THEN
      PERFORM normalize_note_positions(NEW.project_id, NEW.parent_id);
      SELECT COALESCE(MAX(position), 0) + 100000
      INTO NEW.position
      FROM notes
      WHERE project_id = NEW.project_id
      AND parent_id IS NOT DISTINCT FROM NEW.parent_id;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger
DROP TRIGGER IF EXISTS maintain_note_positions_trigger ON notes;

-- Create new trigger
CREATE TRIGGER maintain_note_positions_trigger
  BEFORE INSERT OR UPDATE OF position ON notes
  FOR EACH ROW
  EXECUTE FUNCTION maintain_note_positions();