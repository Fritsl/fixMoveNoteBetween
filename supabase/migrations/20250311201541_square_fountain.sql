/*
  # Fix note ordering system

  1. Changes
    - Drop position column from notes table
    - Create note_sequences table for ordering
    - Add functions for sequence management
    - Add indexes for performance

  2. Details
    - Uses a separate table for note ordering
    - Maintains parent-child relationships
    - Provides efficient sequence management
*/

-- Drop position column from notes if it exists
ALTER TABLE notes DROP COLUMN IF EXISTS position;

-- Create sequence table if it doesn't exist
CREATE TABLE IF NOT EXISTS note_sequences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  UNIQUE (project_id, parent_id, sequence),
  UNIQUE (note_id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS note_sequences_note_id_idx ON note_sequences(note_id);
CREATE INDEX IF NOT EXISTS note_sequences_parent_id_idx ON note_sequences(parent_id);
CREATE INDEX IF NOT EXISTS note_sequences_project_id_idx ON note_sequences(project_id);

-- Function to get next sequence number
CREATE OR REPLACE FUNCTION get_next_sequence(p_project_id uuid, p_parent_id uuid DEFAULT NULL)
RETURNS integer AS $$
DECLARE
  next_seq integer;
BEGIN
  SELECT COALESCE(MAX(sequence), 0) + 1
  INTO next_seq
  FROM note_sequences
  WHERE project_id = p_project_id
  AND parent_id IS NOT DISTINCT FROM p_parent_id;
  
  RETURN next_seq;
END;
$$ LANGUAGE plpgsql;