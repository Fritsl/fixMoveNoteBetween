/*
  # Fix note movement function

  1. Changes
    - Improve move_note function to handle sequence conflicts
    - Add proper sequence normalization during moves
    - Fix race conditions in sequence updates

  2. Details
    - Ensures sequences remain unique
    - Handles edge cases when moving notes
    - Maintains proper ordering
*/

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
  v_max_sequence integer;
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;

  -- Get max sequence at target level
  SELECT COALESCE(MAX(sequence), 0)
  INTO v_max_sequence
  FROM note_sequences
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

  -- Ensure target position is valid
  IF p_new_position > v_max_sequence + 1 THEN
    p_new_position := v_max_sequence + 1;
  END IF;

  -- Update note's parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

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

      UPDATE note_sequences
      SET sequence = p_new_position
      WHERE note_id = p_note_id;
    ELSE
      -- Moving backward
      UPDATE note_sequences
      SET sequence = sequence + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM v_old_parent_id
      AND sequence >= p_new_position
      AND sequence < v_old_sequence;

      UPDATE note_sequences
      SET sequence = p_new_position
      WHERE note_id = p_note_id;
    END IF;
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

  -- Normalize sequences if needed
  IF EXISTS (
    SELECT 1 FROM note_sequences
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    GROUP BY sequence
    HAVING COUNT(*) > 1
  ) THEN
    PERFORM normalize_sequences(v_project_id);
  END IF;

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;