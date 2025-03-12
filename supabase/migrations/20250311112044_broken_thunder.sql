/*
  # Improve note deletion efficiency

  1. New Functions
    - `delete_note_tree`: Efficiently deletes a note and all its descendants
      - Uses a non-recursive approach with CTEs to avoid stack depth issues
      - Handles cleanup of note images
      - Maintains referential integrity

  2. Changes
    - Replaces recursive function calls with a single CTE query
    - Prevents stack depth limit errors
    - Preserves existing triggers and constraints
*/

-- Create function to delete note tree efficiently
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
BEGIN
  -- First, get all descendant note IDs using a CTE
  WITH RECURSIVE descendants AS (
    -- Base case: the root note
    SELECT id
    FROM notes
    WHERE id = root_note_id
    
    UNION
    
    -- Recursive case: all descendants
    SELECT n.id
    FROM notes n
    INNER JOIN descendants d ON n.parent_id = d.id
  )
  -- Delete all related note images first
  DELETE FROM note_images
  WHERE note_id IN (SELECT id FROM descendants);

  -- Then delete all notes in the tree
  DELETE FROM notes
  WHERE id IN (SELECT id FROM descendants);
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION delete_note_tree(uuid) TO authenticated;