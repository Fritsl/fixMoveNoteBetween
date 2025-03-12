/*
  # Fix Note Deletion

  1. Changes
    - Implements an iterative approach for deleting notes to avoid stack depth issues
    - Handles cleanup of related note images
    - Updates project metadata after deletion
    - Uses arrays for efficient batch operations

  2. Functions
    - `delete_note_tree`: Deletes a note and all its descendants efficiently
      - Uses arrays to collect notes for deletion
      - Performs bulk deletions
      - Updates project metadata
*/

-- Create function to delete note tree efficiently
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
DECLARE
  target_project_id uuid;
  notes_to_delete uuid[];
  current_batch uuid[];
  next_batch uuid[];
BEGIN
  -- Get project ID for the root note
  SELECT project_id INTO target_project_id
  FROM notes
  WHERE id = root_note_id;

  -- Initialize with root note
  notes_to_delete := ARRAY[root_note_id];
  current_batch := ARRAY[root_note_id];

  -- Iteratively collect all descendant notes
  WHILE array_length(current_batch, 1) > 0 LOOP
    -- Get children of current batch
    SELECT array_agg(id)
    INTO next_batch
    FROM notes
    WHERE parent_id = ANY(current_batch);

    -- Add children to deletion list if any found
    IF next_batch IS NOT NULL THEN
      notes_to_delete := notes_to_delete || next_batch;
    END IF;

    -- Move to next batch
    current_batch := next_batch;
  END LOOP;

  -- Delete all related note images
  DELETE FROM note_images
  WHERE note_id = ANY(notes_to_delete);

  -- Delete all collected notes
  DELETE FROM notes
  WHERE id = ANY(notes_to_delete);

  -- Update project metadata
  UPDATE settings s
  SET 
    note_count = (
      SELECT COUNT(*)
      FROM notes n
      WHERE n.project_id = target_project_id
    ),
    last_modified_at = CURRENT_TIMESTAMP
  WHERE s.id = target_project_id;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_note_tree(uuid) TO authenticated;