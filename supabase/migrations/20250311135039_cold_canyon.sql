/*
  # Update theme inheritance mechanism

  1. Changes
    - Improves theme inheritance to make sure themes are properly assigned
    - Updates database to support theme inheritance during note move operations
    - Removes previous trigger that may conflict with the improved approach

  2. Details
    - When notes are moved, they will now inherit the theme from their parent
    - Root-level notes will maintain their own themes
    - Child notes get themes from their parents for consistent styling
*/

-- Check if the trigger exists and disable it if it does
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'manage_note_themes'
  ) THEN
    EXECUTE 'ALTER TABLE notes DISABLE TRIGGER manage_note_themes';
  END IF;
END $$;

-- Create an updated function to handle theme inheritance
CREATE OR REPLACE FUNCTION update_theme_on_move()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  -- When parent_id is changed (note is moved)
  IF OLD.parent_id IS DISTINCT FROM NEW.parent_id THEN
    -- If moved to a parent, inherit parent's theme
    IF NEW.parent_id IS NOT NULL THEN
      -- Get parent theme
      SELECT theme INTO NEW.theme
      FROM notes
      WHERE id = NEW.parent_id;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Drop the trigger if it exists
DROP TRIGGER IF EXISTS update_theme_on_move_trigger ON notes;

-- Create a new trigger to update themes when notes are moved
CREATE TRIGGER update_theme_on_move_trigger
BEFORE UPDATE OF parent_id ON notes
FOR EACH ROW
EXECUTE FUNCTION update_theme_on_move();

-- Create safe note deletion function to avoid excessive recursion
CREATE OR REPLACE FUNCTION delete_note_safely(note_id UUID)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
  -- Simply delete the note directly, letting database constraints handle cascading
  DELETE FROM notes WHERE id = note_id;
END;
$$;

-- Update existing notes to ensure theme inheritance is consistent
DO $$
DECLARE
  root_note RECORD;
BEGIN
  -- Process each root note
  FOR root_note IN 
    SELECT id, theme FROM notes WHERE parent_id IS NULL
  LOOP
    -- Update all children of this root note to have the same theme
    UPDATE notes
    SET theme = root_note.theme
    WHERE id IN (
      WITH RECURSIVE descendants AS (
        SELECT id FROM notes WHERE parent_id = root_note.id
        UNION ALL
        SELECT n.id FROM notes n
        JOIN descendants d ON n.parent_id = d.id
      )
      SELECT id FROM descendants
    );
  END LOOP;
END $$;