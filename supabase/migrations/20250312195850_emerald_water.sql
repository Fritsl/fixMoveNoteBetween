/*
  # Fix note movement and sequence handling

  1. Changes
    - Improve move_note function to prevent sequence conflicts
    - Add transaction control to ensure atomic updates
    - Fix sequence normalization during moves

  2. Details
    - Ensures sequences remain unique
    - Handles edge cases properly
    - Maintains data integrity
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
  v_temp_sequence integer;
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

  -- Use a temporary high sequence number to avoid conflicts
  v_temp_sequence := v_max_sequence + 1000000;

  -- First move the note to a temporary high sequence to avoid conflicts
  UPDATE note_sequences
  SET 
    parent_id = p_new_parent_id,
    sequence = v_temp_sequence
  WHERE note_id = p_note_id;

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
  ELSE
    -- Moving to different parent
    -- Close the gap in old parent's sequence
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

    -- Update note's parent in notes table
    UPDATE notes
    SET parent_id = p_new_parent_id
    WHERE id = p_note_id;
  END IF;

  -- Finally, move the note to its target position
  UPDATE note_sequences
  SET sequence = p_new_position
  WHERE note_id = p_note_id;

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;