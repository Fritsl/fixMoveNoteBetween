/*
  # Add efficient note deletion function

  1. New Functions
    - `delete_note_tree`: Efficiently deletes a note and all its descendants using a recursive CTE
      - Handles large note trees without exceeding stack depth
      - Maintains referential integrity
      - Preserves performance with proper indexing

  2. Changes
    - Adds index on parent_id for better performance
    - Uses CTE for efficient recursive deletion
*/

-- Add index on parent_id for better performance
CREATE INDEX IF NOT EXISTS notes_parent_id_idx ON notes(parent_id);

-- Create function to delete note tree efficiently
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
BEGIN
  -- Delete all note images first
  DELETE FROM note_images
  WHERE note_id IN (
    WITH RECURSIVE note_tree AS (
      -- Base case: root note
      SELECT id FROM notes WHERE id = root_note_id
      UNION ALL
      -- Recursive case: child notes
      SELECT n.id 
      FROM notes n
      INNER JOIN note_tree nt ON n.parent_id = nt.id
    )
    SELECT id FROM note_tree
  );

  -- Then delete all notes
  DELETE FROM notes
  WHERE id IN (
    WITH RECURSIVE note_tree AS (
      -- Base case: root note
      SELECT id FROM notes WHERE id = root_note_id
      UNION ALL
      -- Recursive case: child notes
      SELECT n.id 
      FROM notes n
      INNER JOIN note_tree nt ON n.parent_id = nt.id
    )
    SELECT id FROM note_tree
  );
END;
$$ LANGUAGE plpgsql;