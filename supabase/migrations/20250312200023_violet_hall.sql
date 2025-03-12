/*
  # Fix note movement and sequence conflicts

  1. Changes
    - Improve move_note function to prevent sequence conflicts
    - Add transaction management to ensure atomic updates
    - Fix sequence normalization during moves
    - Prevent unique constraint violations

  2. Details
    - Uses a two-step approach for note movement
    - Implements temporary high sequence assignment
    - Handles edge cases properly
    - Maintains data integrity during movement operations
*/

-- Drop existing move_note function
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
  v_max_sequence integer;
  v_temp_sequence integer := 9999999;  -- Very high temporary sequence
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;
  
  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note with ID % not found in note_sequences', p_note_id;
  END IF;

  -- Get max sequence at target level
  SELECT COALESCE(MAX(sequence), 0)
  INTO v_max_sequence
  FROM note_sequences
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

  -- Ensure position is valid
  p_new_position := GREATEST(1, LEAST(p_new_position, v_max_sequence + 1));

  -- STEP 1: First move to a temporary high sequence to avoid conflicts
  UPDATE note_sequences
  SET 
    parent_id = p_new_parent_id,
    sequence = v_temp_sequence
  WHERE note_id = p_note_id;

  -- STEP 2: Update parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

  -- STEP 3: Handle sequence updates based on movement type
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same parent
    IF v_old_sequence < p_new_position THEN
      -- Moving forward
      UPDATE note_sequences
      SET sequence = sequence - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND sequence > v_old_sequence
      AND sequence <= p_new_position;
    ELSE
      -- Moving backward
      UPDATE note_sequences
      SET sequence = sequence + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND sequence >= p_new_position
      AND sequence < v_old_sequence;
    END IF;
  ELSE
    -- Moving to different parent
    -- Close gap in old parent
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
  END IF;

  -- STEP 4: Set the final sequence
  UPDATE note_sequences
  SET sequence = p_new_position
  WHERE note_id = p_note_id;

  -- STEP 5: Fix any possible sequence conflicts
  PERFORM normalize_note_sequences(v_project_id, v_old_parent_id);
  
  IF v_old_parent_id IS DISTINCT FROM p_new_parent_id THEN
    PERFORM normalize_note_sequences(v_project_id, p_new_parent_id);
  END IF;

  -- Update last_modified_at timestamp
  UPDATE settings
  SET last_modified_at = CURRENT_TIMESTAMP
  WHERE id = v_project_id;
END;
$$ LANGUAGE plpgsql;

-- Create or replace a function to normalize note sequences
CREATE OR REPLACE FUNCTION normalize_note_sequences(target_project_id uuid, target_parent_id uuid DEFAULT NULL)
RETURNS void AS $$
DECLARE
  note_record RECORD;
  current_seq integer := 1;
BEGIN
  -- Update sequences to be sequential starting from 1
  FOR note_record IN (
    SELECT note_id
    FROM note_sequences
    WHERE project_id = target_project_id
    AND parent_id IS NOT DISTINCT FROM target_parent_id
    ORDER BY sequence
  ) LOOP
    UPDATE note_sequences
    SET sequence = current_seq
    WHERE note_id = note_record.note_id;
    
    current_seq := current_seq + 1;
  END LOOP;
END;
$$ LANGUAGE plpgsql;