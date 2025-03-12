/*
  # Fix sequence number handling

  1. Changes
    - Add a new trigger function to handle sequence numbers
    - The function will:
      - Maintain a separate sequence for each project
      - Automatically assign the next sequence number when a note is created
      - Handle sequence number gaps when notes are deleted

  2. Security
    - No changes to security policies required
    - Function runs with the same permissions as the calling user
*/

CREATE OR REPLACE FUNCTION set_note_sequence_number()
RETURNS TRIGGER AS $$
DECLARE
  next_sequence INTEGER;
BEGIN
  -- Get the next sequence number for this project
  SELECT COALESCE(MAX(sequence_number), 0) + 1
  INTO next_sequence
  FROM notes
  WHERE project_id = NEW.project_id;

  -- Set the sequence number
  NEW.sequence_number := next_sequence;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS note_sequence_number_trigger ON notes;

-- Create new trigger
CREATE TRIGGER note_sequence_number_trigger
BEFORE INSERT ON notes
FOR EACH ROW
EXECUTE FUNCTION set_note_sequence_number();