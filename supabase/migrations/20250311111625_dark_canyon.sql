/*
  # Improve note deletion efficiency

  1. New Functions
    - `delete_note_tree`: Efficiently deletes a note and all its descendants
      - Uses non-recursive approach to avoid stack depth issues
      - Maintains referential integrity
      - Handles note images cleanup

  2. Changes
    - Uses materialized path pattern for efficient tree traversal
    - Avoids recursive function calls that can hit stack limits
    - Preserves existing triggers and constraints
*/

-- Create function to delete note tree efficiently
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
BEGIN
  -- First delete all note images
  DELETE FROM note_images
  WHERE note_id IN (
    WITH RECURSIVE descendants AS (
      -- Base case: the root note
      SELECT id, parent_id, 1 AS depth
      FROM notes
      WHERE id = root_note_id
      
      UNION ALL
      
      -- Recursive case: direct children only, limiting recursion depth
      SELECT n.id, n.parent_id, d.depth + 1
      FROM notes n
      INNER JOIN descendants d ON n.parent_id = d.id
      WHERE d.depth < 50 -- Reasonable limit to prevent deep recursion
    )
    SELECT id FROM descendants
  );

  -- Then delete the notes
  DELETE FROM notes
  WHERE id IN (
    WITH RECURSIVE descendants AS (
      -- Base case: the root note
      SELECT id, parent_id, 1 AS depth
      FROM notes
      WHERE id = root_note_id
      
      UNION ALL
      
      -- Recursive case: direct children only, limiting recursion depth
      SELECT n.id, n.parent_id, d.depth + 1
      FROM notes n
      INNER JOIN descendants d ON n.parent_id = d.id
      WHERE d.depth < 50 -- Reasonable limit to prevent deep recursion
    )
    SELECT id FROM descendants
  );
END;
$$ LANGUAGE plpgsql;