/*
  # Implement robust note ordering system

  1. Changes
    - Create note_sequences table to track ordering
    - Add functions to manage sequences
    - Migrate existing notes to new system
    - Drop old position column and constraints

  2. Details
    - Each parent (including root level) has its own sequence
    - Moving notes is just updating sequence numbers
    - No more floating point or gap calculations needed
*/

-- First drop existing triggers and constraints
DROP TRIGGER IF EXISTS maintain_note_positions_trigger ON notes;
DROP FUNCTION IF EXISTS maintain_note_positions();
ALTER TABLE notes DROP CONSTRAINT IF EXISTS positive_position;

-- Create sequence table to track ordering
CREATE TABLE note_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  UNIQUE (project_id, parent_id, sequence),
  UNIQUE (note_id)
);

-- Create index for faster lookups
CREATE INDEX note_sequences_note_id_idx ON note_sequences(note_id);
CREATE INDEX note_sequences_parent_id_idx ON note_sequences(parent_id);
CREATE INDEX note_sequences_project_id_idx ON note_sequences(project_id);

-- Function to get next sequence number
CREATE OR REPLACE FUNCTION get_next_sequence(p_project_id uuid, p_parent_id uuid DEFAULT NULL)
RETURNS integer AS $$
DECLARE
  next_seq integer;
BEGIN
  SELECT COALESCE(MAX(sequence), 0) + 1
  INTO next_seq
  FROM note_sequences
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id;
  
  RETURN next_seq;
END;
$$ LANGUAGE plpgsql;

-- Function to insert note at specific position
CREATE OR REPLACE FUNCTION insert_note_at_position(
  p_note_id uuid,
  p_project_id uuid,
  p_parent_id uuid,
  p_position integer
) RETURNS void AS $$
BEGIN
  -- Make space for the new note
  UPDATE note_sequences
  SET sequence = sequence + 1
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id
  AND sequence >= p_position;

  -- Insert the new note
  INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
  VALUES (p_project_id, p_parent_id, p_note_id, p_position);
END;
$$ LANGUAGE plpgsql;

-- Function to move note to new position
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_old_parent_id uuid;
  v_project_id uuid;
  v_old_sequence integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;

  -- If moving within same parent, handle reordering
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    IF v_old_sequence < p_new_position THEN
      -- Moving forward
      UPDATE note_sequences
      SET sequence = sequence - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM v_old_parent_id
      AND sequence > v_old_sequence
      AND sequence <= p_new_position;
    ELSE
      -- Moving backward
      UPDATE note_sequences
      SET sequence = sequence + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM v_old_parent_id
      AND sequence >= p_new_position
      AND sequence < v_old_sequence;
    END IF;

    -- Update note's sequence
    UPDATE note_sequences
    SET sequence = p_new_position
    WHERE note_id = p_note_id;
  ELSE
    -- Moving to different parent
    -- Remove from old parent
    DELETE FROM note_sequences WHERE note_id = p_note_id;
    
    -- Make space in new parent
    UPDATE note_sequences
    SET sequence = sequence + 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND sequence >= p_new_position;
    
    -- Insert at new position
    INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
    VALUES (v_project_id, p_new_parent_id, p_note_id, p_new_position);
    
    -- Update note's parent
    UPDATE notes SET parent_id = p_new_parent_id WHERE id = p_note_id;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Migrate existing notes to new system
WITH RECURSIVE note_tree AS (
  -- Base case: root notes
  SELECT 
    id,
    project_id,
    parent_id,
    position,
    ROW_NUMBER() OVER (
      PARTITION BY project_id, parent_id 
      ORDER BY COALESCE(position, 0)
    ) as sequence
  FROM notes
  WHERE parent_id IS NULL AND project_id IS NOT NULL
  
  UNION ALL
  
  -- Recursive case: child notes
  SELECT 
    n.id,
    n.project_id,
    n.parent_id,
    n.position,
    ROW_NUMBER() OVER (
      PARTITION BY n.project_id, n.parent_id 
      ORDER BY COALESCE(n.position, 0)
    ) as sequence
  FROM notes n
  INNER JOIN note_tree p ON n.parent_id = p.id
  WHERE n.project_id IS NOT NULL
)
INSERT INTO note_sequences (project_id, parent_id, note_id, sequence)
SELECT project_id, parent_id, id, sequence
FROM note_tree;

-- Drop position column
ALTER TABLE notes DROP COLUMN position;