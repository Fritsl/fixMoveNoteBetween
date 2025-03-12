/*
  # Add project metadata

  1. Changes
    - Add last_modified_at timestamp column
    - Add note_count column
    - Add trigger to update last_modified_at
    - Add trigger to maintain note_count
    - Add function to calculate note count

  2. Security
    - Ensure RLS policies are maintained
*/

-- Add metadata columns to settings table
ALTER TABLE settings
ADD COLUMN last_modified_at timestamptz DEFAULT now(),
ADD COLUMN note_count integer DEFAULT 0;

-- Create function to update last_modified_at
CREATE OR REPLACE FUNCTION update_project_last_modified()
RETURNS trigger AS $$
BEGIN
  UPDATE settings
  SET last_modified_at = now()
  WHERE id = NEW.project_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to update last_modified_at
CREATE TRIGGER update_project_last_modified_trigger
AFTER INSERT OR UPDATE OR DELETE ON notes
FOR EACH ROW
EXECUTE FUNCTION update_project_last_modified();

-- Create function to update note count
CREATE OR REPLACE FUNCTION update_project_note_count()
RETURNS trigger AS $$
BEGIN
  -- Update note count for affected project
  WITH RECURSIVE note_tree AS (
    -- Base case: all root notes for the project
    SELECT id, project_id
    FROM notes
    WHERE project_id = COALESCE(NEW.project_id, OLD.project_id)
    UNION
    -- Recursive case: all child notes
    SELECT n.id, n.project_id
    FROM notes n
    INNER JOIN note_tree nt ON n.parent_id = nt.id
  )
  UPDATE settings
  SET note_count = (SELECT count(*) FROM note_tree WHERE project_id = settings.id)
  WHERE id = COALESCE(NEW.project_id, OLD.project_id);
  
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to maintain note count
CREATE TRIGGER update_project_note_count_trigger
AFTER INSERT OR UPDATE OR DELETE ON notes
FOR EACH STATEMENT
EXECUTE FUNCTION update_project_note_count();

-- Initialize note counts for existing projects
WITH RECURSIVE note_tree AS (
  -- Base case: all root notes
  SELECT id, project_id
  FROM notes
  UNION
  -- Recursive case: all child notes
  SELECT n.id, n.project_id
  FROM notes n
  INNER JOIN note_tree nt ON n.parent_id = nt.id
)
UPDATE settings
SET note_count = (
  SELECT count(*)
  FROM note_tree
  WHERE project_id = settings.id
);