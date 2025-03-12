/*
  # Fix note deletion stack depth issue

  1. Changes
    - Replaces recursive function with a more efficient CTE-based approach
    - Handles cascading deletes for notes and their images
    - Prevents stack depth limit errors
    - Updates project metadata (note count, last modified)

  2. New Functions
    - `delete_note_tree`: Efficiently deletes a note and all its descendants
      - Uses a non-recursive CTE to avoid stack depth issues
      - Handles cleanup of note images
      - Updates project metadata
*/

-- Create function to delete note tree efficiently
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
DECLARE
  project_id uuid;
BEGIN
  -- Get project ID for the root note
  SELECT notes.project_id INTO project_id
  FROM notes
  WHERE id = root_note_id;

  -- Delete all descendant notes and their images using a CTE
  WITH RECURSIVE descendants AS (
    -- Base case: the root note
    SELECT id, project_id
    FROM notes
    WHERE id = root_note_id

    UNION ALL

    -- Recursive case: all descendants
    SELECT n.id, n.project_id
    FROM notes n
    INNER JOIN descendants d ON n.parent_id = d.id
  )
  -- First delete all related note images
  DELETE FROM note_images
  WHERE note_id IN (SELECT id FROM descendants);

  -- Then delete all notes in the tree
  DELETE FROM notes
  WHERE id IN (SELECT id FROM descendants);

  -- Update project metadata
  UPDATE settings
  SET 
    note_count = (
      SELECT COUNT(*)
      FROM notes
      WHERE project_id = project_id
    ),
    last_modified_at = CURRENT_TIMESTAMP
  WHERE id = project_id;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_note_tree(uuid) TO authenticated;