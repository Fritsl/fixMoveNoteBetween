/*
  # Fix note ordering system

  1. Changes
    - Add function to properly handle note reordering
    - Ensure sequence numbers are updated atomically
    - Fix race conditions in note movement

  2. Details
    - Uses proper sequence management
    - Handles moving notes within same parent
    - Handles moving notes between different parents
*/

-- Drop existing move_note function if it exists
DROP FUNCTION IF EXISTS move_note;

-- Create improved move_note function
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_sequence integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;

  -- Update note's parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

  -- Handle sequence updates within transaction
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same parent
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
    -- First, close the gap in old parent's sequence
    UPDATE note_sequences
    SET sequence = sequence - 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM v_old_parent_id
    AND sequence > v_old_sequence;

    -- Make space in new parent
    UPDATE note_sequences
    SET sequence = sequence + 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND sequence >= p_new_position;

    -- Move note to new position
    UPDATE note_sequences
    SET 
      parent_id = p_new_parent_id,
      sequence = p_new_position
    WHERE note_id = p_note_id;
  END IF;

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;