/*
  # Add note sequence number

  1. Changes
    - Add sequence_number column to notes table
    - Add trigger to auto-increment sequence_number per project
    - Backfill existing notes with sequence numbers

  2. Details
    - sequence_number is a positive integer that auto-increments per project
    - Each project has its own sequence starting from 1
    - Numbers are never reused within a project, even after note deletion
*/

-- Add sequence_number column
ALTER TABLE notes ADD COLUMN sequence_number integer;

-- Create a function to get the next sequence number for a project
CREATE OR REPLACE FUNCTION get_next_sequence_number(project_id uuid)
RETURNS integer AS $$
DECLARE
  next_number integer;
BEGIN
  SELECT COALESCE(MAX(sequence_number), 0) + 1
  INTO next_number
  FROM notes
  WHERE project_id = $1;
  
  RETURN next_number;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically set sequence_number on insert
CREATE OR REPLACE FUNCTION set_note_sequence_number()
RETURNS TRIGGER AS $$
BEGIN
  NEW.sequence_number := get_next_sequence_number(NEW.project_id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER note_sequence_number_trigger
  BEFORE INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION set_note_sequence_number();

-- Backfill existing notes with sequence numbers
DO $$
DECLARE
  project record;
  note record;
  seq_num integer;
BEGIN
  FOR project IN SELECT DISTINCT project_id FROM notes LOOP
    seq_num := 1;
    FOR note IN SELECT id FROM notes WHERE project_id = project.project_id ORDER BY created_at LOOP
      UPDATE notes SET sequence_number = seq_num WHERE id = note.id;
      seq_num := seq_num + 1;
    END LOOP;
  END LOOP;
END $$;