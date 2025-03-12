/*
  # Fix delete note tree function

  1. Changes
    - Fixes ambiguous project_id reference in the update statement
    - Improves variable naming for clarity
    - Adds explicit table aliases to prevent ambiguity

  2. Functions
    - `delete_note_tree`: Deletes a note and all its descendants
      - Uses CTE to find all descendant notes
      - Handles cleanup of note images
      - Updates project metadata
*/

-- Create function to delete note tree efficiently
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
DECLARE
  target_project_id uuid;
BEGIN
  -- Get project ID for the root note
  SELECT project_id INTO target_project_id
  FROM notes
  WHERE id = root_note_id;

  -- Delete all descendant notes and their images using a CTE
  WITH RECURSIVE descendants AS (
    -- Base case: the root note
    SELECT id
    FROM notes
    WHERE id = root_note_id

    UNION ALL

    -- Recursive case: all descendants
    SELECT n.id
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