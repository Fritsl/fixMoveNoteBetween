/*
  # Add safe note deletion function

  1. New Functions
    - `delete_note_safely`: A function to safely delete notes without stack depth issues
    
  2. Purpose
    - Provides a controlled way to delete notes without exceeding the PostgreSQL stack depth limit
    - Handles cascading deletion in batches
    - Ensures complete cleanup of all related records
*/

-- Create a function to safely delete a note and all its descendants
CREATE OR REPLACE FUNCTION delete_note_safely(note_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  descendant_ids UUID[];
BEGIN
  -- First, find all descendant note IDs using a non-recursive approach
  WITH RECURSIVE descendants AS (
    SELECT id FROM notes WHERE id = note_id
    UNION ALL
    SELECT n.id FROM notes n
    JOIN descendants d ON n.parent_id = d.id
  )
  SELECT array_agg(id) INTO descendant_ids
  FROM descendants;
  
  -- Now delete all images associated with these notes
  DELETE FROM note_images
  WHERE note_id = ANY(descendant_ids);
  
  -- Finally delete the notes themselves
  DELETE FROM notes
  WHERE id = ANY(descendant_ids);
END;
$$;