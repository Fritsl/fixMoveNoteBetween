/*
  # Fix note ordering system

  1. Changes
    - Drop any remaining position-related items
    - Ensure note_sequences table exists with proper structure
    - Add functions for sequence management
    - Add indexes for performance

  2. Details
    - Uses note_sequences table for ordering instead of position column
    - Provides functions for getting next sequence and moving notes
    - Maintains proper parent-child relationships
*/

-- Drop position column from notes if it exists
ALTER TABLE notes DROP COLUMN IF EXISTS position;

-- Create sequence table if it doesn't exist
CREATE TABLE IF NOT EXISTS note_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  UNIQUE (project_id, parent_id, sequence),
  UNIQUE (note_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS note_sequences_note_id_idx ON note_sequences(note_id);
CREATE INDEX IF NOT EXISTS note_sequences_parent_id_idx ON note_sequences(parent_id);
CREATE INDEX IF NOT EXISTS note_sequences_project_id_idx ON note_sequences(project_id);

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