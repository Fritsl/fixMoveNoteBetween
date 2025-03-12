/*
  Complete Database Schema

  This single migration contains everything needed for a fresh database setup:
  - Tables: settings (corresponds to "projects" in code), notes, note_sequences
  - Functions: move_note, delete_note_tree, soft_delete_project, restore_project
  - RLS policies for security
*/

-- Create tables
CREATE TABLE IF NOT EXISTS settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  title text NOT NULL DEFAULT 'Untitled Project',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  last_modified_at timestamptz NOT NULL DEFAULT NOW(),
  note_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  deleted_at timestamptz DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  content text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW(),
  user_id uuid NOT NULL
);

CREATE TABLE IF NOT EXISTS note_sequences (
  note_id uuid PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  UNIQUE (project_id, parent_id, sequence)
);

-- Create function to move notes
CREATE OR REPLACE FUNCTION move_note(
  note_id_param uuid,
  new_parent_id_param uuid,
  new_sequence_param integer
) RETURNS void AS $$
DECLARE
  current_parent_id uuid;
  current_sequence integer;
  project_id_val uuid;
  temp_sequence integer := 999999; -- Use a temporary high sequence to avoid conflicts
BEGIN
  -- Get current values
  SELECT 
    ns.parent_id, 
    ns.sequence, 
    ns.project_id
  INTO 
    current_parent_id, 
    current_sequence, 
    project_id_val
  FROM 
    note_sequences ns
  WHERE 
    ns.note_id = note_id_param;

  -- If not found, exit
  IF project_id_val IS NULL THEN
    RAISE EXCEPTION 'Note sequence not found';
    RETURN;
  END IF;

  -- Step 1: Temporarily move note to a very high sequence to avoid conflicts
  UPDATE note_sequences
  SET sequence = temp_sequence
  WHERE note_id = note_id_param;

  -- Step 2: Update the original position - close the gap
  UPDATE note_sequences
  SET sequence = sequence - 1
  WHERE 
    project_id = project_id_val 
    AND parent_id IS NOT DISTINCT FROM current_parent_id
    AND sequence > current_sequence;

  -- Step 3: Make space at the destination
  UPDATE note_sequences
  SET sequence = sequence + 1
  WHERE 
    project_id = project_id_val 
    AND parent_id IS NOT DISTINCT FROM new_parent_id_param
    AND sequence >= new_sequence_param;

  -- Step 4: Move the note to its final destination
  UPDATE note_sequences
  SET 
    parent_id = new_parent_id_param,
    sequence = new_sequence_param
  WHERE note_id = note_id_param;
END;
$$ LANGUAGE plpgsql;

-- Function to delete a note and its children recursively
CREATE OR REPLACE FUNCTION delete_note_tree(note_id_param uuid)
RETURNS void AS $$
DECLARE
  child_id uuid;
BEGIN
  -- First, recursively delete all children
  FOR child_id IN (
    SELECT n.id 
    FROM notes n
    JOIN note_sequences ns ON n.id = ns.note_id
    WHERE ns.parent_id = note_id_param
  )
  LOOP
    PERFORM delete_note_tree(child_id);
  END LOOP;

  -- Then delete the note itself and its sequence
  DELETE FROM notes WHERE id = note_id_param;
END;
$$ LANGUAGE plpgsql;

-- Create function to soft delete project
CREATE OR REPLACE FUNCTION soft_delete_project(project_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE settings
  SET deleted_at = NOW()
  WHERE id = project_id
  AND user_id = auth.uid()
  AND deleted_at IS NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to restore project
CREATE OR REPLACE FUNCTION restore_project(project_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE settings
  SET deleted_at = NULL
  WHERE id = project_id
  AND user_id = auth.uid()
  AND deleted_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create storage bucket for note images if needed
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_extension WHERE extname = 'storage'
  ) THEN
    -- Skip if storage extension isn't available
    RAISE NOTICE 'Storage extension not available, skipping bucket creation';
  ELSE
    -- Only try to create bucket if storage extension exists
    IF NOT EXISTS (
      SELECT 1 FROM storage.buckets WHERE id = 'note-images'
    ) THEN
      INSERT INTO storage.buckets (id, name, public)
      VALUES ('note-images', 'note-images', true);
    END IF;
  END IF;
END $$;

-- Enable RLS on tables
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE note_sequences ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for settings table
CREATE POLICY "Users can read own settings" ON settings
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() 
    AND deleted_at IS NULL
  );

CREATE POLICY "Users can insert own settings" ON settings
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
  );

CREATE POLICY "Users can update own settings" ON settings
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
  );

-- Create RLS policies for notes table
CREATE POLICY "Users can read own notes" ON notes
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid()
  );

CREATE POLICY "Users can insert own notes" ON notes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
  );

CREATE POLICY "Users can update own notes" ON notes
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid()
  );

CREATE POLICY "Users can delete own notes" ON notes
  FOR DELETE TO authenticated
  USING (
    user_id = auth.uid()
  );

-- Create RLS policies for note_sequences table
CREATE POLICY "Users can read note sequences through parent notes" ON note_sequences
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE n.id = note_id
      AND n.user_id = auth.uid()
    )
  );

CREATE POLICY "Users can modify note sequences through parent notes" ON note_sequences
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM notes n
      WHERE n.id = note_id
      AND n.user_id = auth.uid()
    )
  );