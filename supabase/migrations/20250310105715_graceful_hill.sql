/*
  # Add sequence numbers to notes

  1. Changes
    - Add sequence_number column to notes table
    - Create function to set sequence numbers
    - Add trigger to automatically set sequence numbers on insert
    - Update existing notes with sequence numbers

  2. Details
    - sequence_number is a unique integer within each project
    - Numbers are assigned sequentially based on position and parent-child relationships
    - Existing notes will be numbered in their current order
    - New notes will get the next available number

  3. Notes
    - The sequence_number is maintained separately from position to allow for flexible reordering
    - Numbers are unique per project, making them suitable for external reference
*/

-- Add sequence_number column
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'notes' AND column_name = 'sequence_number'
  ) THEN
    ALTER TABLE notes ADD COLUMN sequence_number integer;
  END IF;
END $$;

-- Create function to set sequence numbers
CREATE OR REPLACE FUNCTION set_note_sequence_number()
RETURNS TRIGGER AS $$
DECLARE
  next_sequence integer;
BEGIN
  -- Get the next available sequence number for this project
  SELECT COALESCE(MAX(sequence_number), 0) + 1
  INTO next_sequence
  FROM notes
  WHERE project_id = NEW.project_id;
  
  -- Set the sequence number
  NEW.sequence_number := next_sequence;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to set sequence numbers on insert
DROP TRIGGER IF EXISTS note_sequence_number_trigger ON notes;
CREATE TRIGGER note_sequence_number_trigger
  BEFORE INSERT ON notes
  FOR EACH ROW
  EXECUTE FUNCTION set_note_sequence_number();

-- Update existing notes with sequence numbers
WITH RECURSIVE note_tree AS (
  -- Base case: get root notes
  SELECT 
    id,
    project_id,
    parent_id,
    position,
    1 as level,
    ARRAY[position] as path
  FROM notes
  WHERE parent_id IS NULL

  UNION ALL

  -- Recursive case: get child notes
  SELECT 
    c.id,
    c.project_id,
    c.parent_id,
    c.position,
    p.level + 1,
    p.path || c.position
  FROM notes c
  INNER JOIN note_tree p ON c.parent_id = p.id
),
numbered_notes AS (
  SELECT 
    id,
    project_id,
    ROW_NUMBER() OVER (
      PARTITION BY project_id 
      ORDER BY path
    ) as new_sequence
  FROM note_tree
)
UPDATE notes n
SET sequence_number = nn.new_sequence
FROM numbered_notes nn
WHERE n.id = nn.id
  AND n.sequence_number IS NULL;