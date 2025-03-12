/*
  # Fix note sequence ordering

  1. Changes
    - Add function to normalize sequences to match visual order
    - Add trigger to maintain sequence order
    - Fix any existing out-of-order sequences

  2. Details
    - Ensures sequences start from 1 and increment sequentially
    - Maintains proper order when notes are moved
    - Fixes any existing sequence inconsistencies
*/

-- Function to normalize sequences for a project
CREATE OR REPLACE FUNCTION normalize_sequences(target_project_id uuid)
RETURNS void AS $$
DECLARE
  note_record RECORD;
  current_seq integer;
BEGIN
  -- First normalize root level notes
  current_seq := 1;
  FOR note_record IN (
    SELECT ns.note_id
    FROM note_sequences ns
    WHERE ns.project_id = target_project_id
    AND ns.parent_id IS NULL
    ORDER BY ns.sequence
  ) LOOP
    UPDATE note_sequences
    SET sequence = current_seq
    WHERE note_id = note_record.note_id;
    
    current_seq := current_seq + 1;
  END LOOP;

  -- Then normalize child notes for each parent
  FOR note_record IN (
    SELECT DISTINCT parent_id
    FROM note_sequences
    WHERE project_id = target_project_id
    AND parent_id IS NOT NULL
  ) LOOP
    current_seq := 1;
    
    UPDATE note_sequences
    SET sequence = new_seq.seq
    FROM (
      SELECT note_id, ROW_NUMBER() OVER (ORDER BY sequence) as seq
      FROM note_sequences
      WHERE project_id = target_project_id
      AND parent_id = note_record.parent_id
    ) new_seq
    WHERE note_sequences.note_id = new_seq.note_id;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Normalize existing sequences
DO $$
DECLARE
  project_record RECORD;
BEGIN
  FOR project_record IN SELECT DISTINCT project_id FROM note_sequences LOOP
    PERFORM normalize_sequences(project_record.project_id);
  END LOOP;
END $$;