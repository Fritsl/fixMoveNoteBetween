/*
  # Fix note ordering system

  1. Changes
    - Add move_note function for handling note reordering
    - Add insert_note_at_position function for new notes
    - Update existing functions to handle note sequences properly

  2. Security
    - Maintain existing RLS policies
    - Ensure proper cascading deletes
*/

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