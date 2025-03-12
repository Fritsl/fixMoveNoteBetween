/*
  # Fix note position handling

  1. Changes
    - Update existing positions to be positive integers
    - Add constraint to ensure positions are positive
    - Add functions for position management
    - Add triggers for automatic position maintenance

  2. Details
    - Uses large integer steps (100000) to prevent position collisions
    - Maintains proper spacing between notes
    - Prevents negative or decimal positions
    - Automatically normalizes positions when needed
*/

-- First normalize existing positions to ensure they're all positive
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

-- Now add constraint for positive positions
ALTER TABLE notes ADD CONSTRAINT positive_position CHECK (position > 0);

-- Create function to get next position
CREATE OR REPLACE FUNCTION get_next_position(target_project_id uuid, target_parent_id uuid DEFAULT NULL)
RETURNS integer AS $$
DECLARE
  last_position integer;
BEGIN
  -- Get the highest position for the current level
  SELECT COALESCE(MAX(position), 0)
  INTO last_position
  FROM notes
  WHERE project_id = target_project_id
  AND parent_id IS NOT DISTINCT FROM target_parent_id;

  -- Return next position with large spacing
  RETURN GREATEST(last_position + 100000, 100000);
END;
$$ LANGUAGE plpgsql;

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
BEGIN
  -- For new notes or position updates
  IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND NEW.position != OLD.position) THEN
    -- If position is missing or invalid, get next position
    IF NEW.position IS NULL OR NEW.position <= 0 THEN
      NEW.position := get_next_position(NEW.project_id, NEW.parent_id);
    END IF;

    -- If position gets too large, normalize
    IF NEW.position >= 1000000000 THEN
      PERFORM normalize_note_positions(NEW.project_id, NEW.parent_id);
      NEW.position := get_next_position(NEW.project_id, NEW.parent_id);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
CREATE TRIGGER maintain_note_positions_trigger
  BEFORE INSERT OR UPDATE OF position ON notes
  FOR EACH ROW
  EXECUTE FUNCTION maintain_note_positions();