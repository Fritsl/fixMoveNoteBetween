/*
  # Fix theme management for notes

  1. Changes
    - Creates theme_type enum with 6 color options
    - Adds theme column to notes table
    - Implements theme management trigger for automatic theme assignment
    - Adds function to reapply themes to existing notes
    - Fixes ambiguous column references in SQL queries

  2. Security
    - Maintains existing RLS policies
*/

-- Create theme type enum if it doesn't exist
DO $$ BEGIN
  CREATE TYPE theme_type AS ENUM ('indigo', 'emerald', 'amber', 'rose', 'violet', 'sky');
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

-- Add theme column to notes table if it doesn't exist
DO $$ BEGIN
  ALTER TABLE notes ADD COLUMN theme theme_type;
EXCEPTION
  WHEN duplicate_column THEN NULL;
END $$;

-- Drop existing trigger and function if they exist
DROP TRIGGER IF EXISTS manage_note_themes ON notes;
DROP FUNCTION IF EXISTS update_note_themes();

-- Create improved theme management function
CREATE OR REPLACE FUNCTION update_note_themes()
RETURNS TRIGGER AS $$
DECLARE
  current_theme theme_type;
BEGIN
  -- If this is a root note
  IF NEW.parent_id IS NULL THEN
    -- Get the last theme used in root notes for this project
    SELECT n.theme INTO current_theme
    FROM notes n
    WHERE n.project_id = NEW.project_id 
    AND n.parent_id IS NULL 
    AND n.position < COALESCE(NEW.position, 0)
    ORDER BY n.position DESC
    LIMIT 1;

    -- Get next theme in sequence
    NEW.theme := CASE COALESCE(current_theme, 'sky')
      WHEN 'indigo' THEN 'emerald'
      WHEN 'emerald' THEN 'amber'
      WHEN 'amber' THEN 'rose'
      WHEN 'rose' THEN 'violet'
      WHEN 'violet' THEN 'sky'
      WHEN 'sky' THEN 'indigo'
    END;
  ELSE
    -- Inherit parent's theme
    SELECT n.theme INTO NEW.theme
    FROM notes n
    WHERE n.id = NEW.parent_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for theme management
CREATE TRIGGER manage_note_themes
BEFORE INSERT OR UPDATE OF parent_id
ON notes
FOR EACH ROW
EXECUTE FUNCTION update_note_themes();

-- Function to update themes for all notes in a project
CREATE OR REPLACE FUNCTION reapply_project_themes(target_project_id uuid)
RETURNS void AS $$
DECLARE
  current_theme theme_type := 'sky';
  root_note RECORD;
BEGIN
  -- Process each root note in order
  FOR root_note IN 
    SELECT n.id
    FROM notes n
    WHERE n.project_id = target_project_id
    AND n.parent_id IS NULL
    ORDER BY n.position
  LOOP
    -- Get next theme
    current_theme := CASE current_theme
      WHEN 'indigo' THEN 'emerald'
      WHEN 'emerald' THEN 'amber'
      WHEN 'amber' THEN 'rose'
      WHEN 'rose' THEN 'violet'
      WHEN 'violet' THEN 'sky'
      WHEN 'sky' THEN 'indigo'
    END;

    -- Update root note and all its descendants
    WITH RECURSIVE note_tree AS (
      -- Base case: root note
      SELECT id, parent_id
      FROM notes
      WHERE id = root_note.id
      
      UNION ALL
      
      -- Recursive case: child notes
      SELECT n.id, n.parent_id
      FROM notes n
      INNER JOIN note_tree nt ON n.parent_id = nt.id
    )
    UPDATE notes n
    SET theme = current_theme
    WHERE n.id IN (SELECT id FROM note_tree);
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Reapply themes to all existing notes
DO $$
DECLARE
  project_record RECORD;
BEGIN
  FOR project_record IN SELECT DISTINCT n.project_id FROM notes n
  LOOP
    PERFORM reapply_project_themes(project_record.project_id);
  END LOOP;
END $$;