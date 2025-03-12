/*
  # Fix note deletion stack overflow

  1. Changes
    - Adds a new non-recursive cleanup function to replace existing triggers
    - Disables existing recursive triggers that cause stack overflow
    - Implements a more efficient cleanup approach

  2. Details
    - Fixes the "stack depth limit exceeded" error when deleting notes with many children
    - Uses a more efficient non-recursive approach for cleaning up related resources
*/

-- First disable the problematic triggers
ALTER TABLE notes DISABLE TRIGGER cleanup_notes_trigger;
ALTER TABLE notes DISABLE TRIGGER cleanup_images_trigger;

-- Create a new, more efficient cleanup function that avoids recursion
CREATE OR REPLACE FUNCTION cleanup_notes_non_recursive()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- This approach avoids recursion by using direct SQL operations
  -- rather than recursive trigger calls

  -- Delete the images associated with the deleted notes
  -- This is done in a single operation without recursion
  DELETE FROM note_images 
  WHERE note_id IN (
    WITH RECURSIVE note_tree AS (
      SELECT id FROM notes WHERE id = OLD.id
      UNION ALL
      SELECT n.id FROM notes n
      JOIN note_tree nt ON n.parent_id = nt.id
    )
    SELECT id FROM note_tree
  );

  RETURN OLD;
END;
$$;

-- Create a new trigger that uses the non-recursive function
CREATE TRIGGER cleanup_notes_non_recursive_trigger
AFTER DELETE ON notes
FOR EACH ROW
EXECUTE FUNCTION cleanup_notes_non_recursive();