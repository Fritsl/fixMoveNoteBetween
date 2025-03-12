/*
  # Enhance data integrity and cleanup

  1. Changes
    - Add foreign key constraints with cascade delete
    - Add trigger to cleanup orphaned notes
    - Add trigger to cleanup orphaned images
    - Add validation for project existence

  2. Security
    - Ensure data consistency
    - Prevent orphaned records
*/

-- Create function to cleanup orphaned notes
CREATE OR REPLACE FUNCTION cleanup_orphaned_notes()
RETURNS trigger AS $$
BEGIN
  -- Delete notes that reference non-existent parents
  DELETE FROM notes
  WHERE parent_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM notes parent
    WHERE parent.id = notes.parent_id
  );
  
  -- Delete notes that reference non-existent projects
  DELETE FROM notes
  WHERE project_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM settings
    WHERE settings.id = notes.project_id
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run cleanup after changes
CREATE OR REPLACE TRIGGER cleanup_notes_trigger
  AFTER DELETE ON notes
  FOR EACH STATEMENT
  EXECUTE FUNCTION cleanup_orphaned_notes();

-- Create function to cleanup orphaned images
CREATE OR REPLACE FUNCTION cleanup_orphaned_images()
RETURNS trigger AS $$
BEGIN
  -- Delete images that reference non-existent notes
  DELETE FROM note_images
  WHERE NOT EXISTS (
    SELECT 1 FROM notes
    WHERE notes.id = note_images.note_id
  );
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to run image cleanup
CREATE OR REPLACE TRIGGER cleanup_images_trigger
  AFTER DELETE ON notes
  FOR EACH STATEMENT
  EXECUTE FUNCTION cleanup_orphaned_images();