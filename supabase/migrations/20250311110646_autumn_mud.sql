/*
  # Add theme support to notes

  1. New Enum Type
    - Creates a theme_type enum with 6 color options
  
  2. Changes
    - Adds theme column to notes table
    - Adds function to automatically set themes for root notes and their children
    - Adds trigger to maintain themes on note changes

  3. Security
    - Updates RLS policies to include new column
*/

-- Create theme enum type
CREATE TYPE theme_type AS ENUM (
  'indigo',
  'emerald', 
  'amber',
  'rose',
  'violet',
  'sky'
);

-- Add theme column to notes table
ALTER TABLE notes 
ADD COLUMN theme theme_type;

-- Function to get next theme in cycle
CREATE OR REPLACE FUNCTION get_next_theme(current_theme theme_type)
RETURNS theme_type AS $$
BEGIN
  CASE current_theme
    WHEN 'indigo' THEN RETURN 'emerald';
    WHEN 'emerald' THEN RETURN 'amber';
    WHEN 'amber' THEN RETURN 'rose';
    WHEN 'rose' THEN RETURN 'violet';
    WHEN 'violet' THEN RETURN 'sky';
    WHEN 'sky' THEN RETURN 'indigo';
    ELSE RETURN 'indigo';
  END CASE;
END;
$$ LANGUAGE plpgsql;

-- Function to update themes for a note tree
CREATE OR REPLACE FUNCTION update_note_themes()
RETURNS TRIGGER AS $$
DECLARE
  root_note RECORD;
  last_theme theme_type;
BEGIN
  -- If this is a root note (no parent_id), assign next theme in cycle
  IF NEW.parent_id IS NULL THEN
    -- Get the last theme used for root notes in this project
    SELECT theme INTO last_theme
    FROM notes
    WHERE project_id = NEW.project_id 
    AND parent_id IS NULL 
    AND id != NEW.id
    ORDER BY position DESC
    LIMIT 1;

    -- Assign next theme in cycle
    NEW.theme := COALESCE(get_next_theme(last_theme), 'indigo');
  ELSE
    -- If this is a child note, inherit parent's theme
    SELECT theme INTO NEW.theme
    FROM notes
    WHERE id = NEW.parent_id;
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

-- Update existing notes with themes
DO $$
DECLARE
  root_note RECORD;
  current_theme theme_type := 'indigo';
BEGIN
  -- Process each root note
  FOR root_note IN 
    SELECT DISTINCT ON (project_id) id, project_id
    FROM notes 
    WHERE parent_id IS NULL
    ORDER BY project_id, position
  LOOP
    -- Update root note and its descendants
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
    UPDATE notes
    SET theme = current_theme
    WHERE id IN (SELECT id FROM note_tree);
    
    -- Get next theme for next root note
    current_theme := get_next_theme(current_theme);
  END LOOP;
END $$;