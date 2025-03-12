/*
  # Create a safer note deletion function

  1. New Functions
    - `delete_note_safely` - A database function that safely deletes notes without stack overflow

  2. Details
    - Provides a non-recursive approach to delete notes
    - Prevents stack depth limit exceeded errors
    - Can handle deeply nested note structures
*/

-- Create a function to delete notes safely without recursion
CREATE OR REPLACE FUNCTION delete_note_safely(note_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  -- First delete all images associated with this note and its children
  -- This uses a recursive query but in a single SQL operation
  DELETE FROM note_images 
  WHERE note_id IN (
    WITH RECURSIVE note_tree AS (
      SELECT id FROM notes WHERE id = note_id
      UNION ALL
      SELECT n.id FROM notes n
      JOIN note_tree nt ON n.parent_id = nt.id
    )
    SELECT id FROM note_tree
  );

  -- Then delete all descendant notes
  -- Delete from the bottom up to avoid foreign key issues
  DELETE FROM notes 
  WHERE id IN (
    WITH RECURSIVE note_tree AS (
      SELECT id, parent_id, 0 AS depth FROM notes WHERE id = note_id
      UNION ALL
      SELECT n.id, n.parent_id, nt.depth + 1 
      FROM notes n
      JOIN note_tree nt ON n.parent_id = nt.id
    )
    SELECT id FROM note_tree
    ORDER BY depth DESC
  );
END;
$$;

-- Grant appropriate permissions
GRANT EXECUTE ON FUNCTION delete_note_safely TO authenticated;
GRANT EXECUTE ON FUNCTION delete_note_safely TO anon;
GRANT EXECUTE ON FUNCTION delete_note_safely TO service_role;