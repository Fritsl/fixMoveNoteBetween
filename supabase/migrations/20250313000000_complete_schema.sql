
/*
  # Complete Database Schema

  This single migration file contains all necessary database objects:
  - Tables: settings (projects), notes, note_sequences
  - Functions: move_note, delete_note_tree, soft_delete_project, restore_project
  - Storage setup for note images
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
  deleted_at timestamptz DEFAULT NULL
);

CREATE TABLE IF NOT EXISTS notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  content text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT NOW(),
  updated_at timestamptz NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS note_sequences (
  note_id uuid PRIMARY KEY REFERENCES notes(id) ON DELETE CASCADE,
  project_id uuid NOT NULL REFERENCES settings(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES notes(id) ON DELETE CASCADE,
  sequence integer NOT NULL,
  UNIQUE (project_id, parent_id, sequence)
);

-- Create note_images table for image storage
CREATE TABLE IF NOT EXISTS note_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  note_id uuid NOT NULL REFERENCES notes(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);

-- Create storage bucket for note images
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM storage.buckets WHERE id = 'note-images'
  ) THEN
    INSERT INTO storage.buckets (id, name, public)
    VALUES ('note-images', 'note-images', true);
  END IF;
END $$;

-- Create storage policies
CREATE POLICY "Users can upload note images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Anyone can view note images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'note-images');

CREATE POLICY "Users can delete their note images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

-- Create function to clean up storage when images are deleted
CREATE OR REPLACE FUNCTION delete_storage_object()
RETURNS TRIGGER AS $$
BEGIN
  -- Only attempt to delete if storage_path exists
  IF OLD.storage_path IS NOT NULL THEN
    -- Delete file from storage
    PERFORM net.http_post(
      url := current_setting('supabase_functions_endpoint') || '/storage/v1/object/note-images/' || OLD.storage_path,
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('supabase.auth.anon_key'),
        'Content-Type', 'application/json'
      ),
      body := '{}'
    );
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for storage cleanup
CREATE TRIGGER delete_note_image_storage_trigger
  BEFORE DELETE ON note_images
  FOR EACH ROW
  EXECUTE FUNCTION delete_storage_object();

-- Create function to move notes
CREATE OR REPLACE FUNCTION move_note(
  p_note_id uuid,
  p_new_parent_id uuid,
  p_new_position integer
) RETURNS void AS $$
DECLARE
  v_project_id uuid;
  v_old_parent_id uuid;
  v_old_sequence integer;
  v_max_sequence integer;
  v_temp_sequence integer := 9999999;  -- Very high temporary sequence
BEGIN
  -- Get current note info
  SELECT project_id, parent_id, sequence
  INTO v_project_id, v_old_parent_id, v_old_sequence
  FROM note_sequences
  WHERE note_id = p_note_id;

  IF v_project_id IS NULL THEN
    RAISE EXCEPTION 'Note with ID % not found in note_sequences', p_note_id;
  END IF;

  -- Get max sequence at target level
  SELECT COALESCE(MAX(sequence), 0)
  INTO v_max_sequence
  FROM note_sequences
  WHERE project_id = v_project_id
  AND parent_id IS NOT DISTINCT FROM p_new_parent_id;

  -- Ensure position is valid
  p_new_position := GREATEST(1, LEAST(p_new_position, v_max_sequence + 1));

  -- STEP 1: First move to a temporary high sequence to avoid conflicts
  -- This avoids the unique constraint violation
  UPDATE note_sequences
  SET 
    sequence = v_temp_sequence
  WHERE note_id = p_note_id;

  -- STEP 2: Update parent in notes table
  UPDATE notes
  SET parent_id = p_new_parent_id
  WHERE id = p_note_id;

  -- STEP 3: Handle sequence updates based on movement type
  IF v_old_parent_id IS NOT DISTINCT FROM p_new_parent_id THEN
    -- Moving within same parent
    IF v_old_sequence < p_new_position THEN
      -- Moving forward
      UPDATE note_sequences
      SET sequence = sequence - 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND sequence > v_old_sequence
      AND sequence <= p_new_position;
    ELSE
      -- Moving backward
      UPDATE note_sequences
      SET sequence = sequence + 1
      WHERE project_id = v_project_id
      AND parent_id IS NOT DISTINCT FROM p_new_parent_id
      AND sequence >= p_new_position
      AND sequence < v_old_sequence;
    END IF;
  ELSE
    -- Moving to different parent
    -- Close gap in old parent
    UPDATE note_sequences
    SET sequence = sequence - 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM v_old_parent_id
    AND sequence > v_old_sequence;

    -- Make space in new parent
    UPDATE note_sequences
    SET sequence = sequence + 1
    WHERE project_id = v_project_id
    AND parent_id IS NOT DISTINCT FROM p_new_parent_id
    AND sequence >= p_new_position;
  END IF;

  -- STEP 4: Finally, move note to its target position and parent
  UPDATE note_sequences
  SET 
    parent_id = p_new_parent_id,
    sequence = p_new_position
  WHERE note_id = p_note_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to delete note tree
CREATE OR REPLACE FUNCTION delete_note_tree(root_note_id uuid)
RETURNS void AS $$
DECLARE
  target_project_id uuid;
  notes_to_delete uuid[];
BEGIN
  -- Get the project id
  SELECT project_id INTO target_project_id
  FROM notes
  WHERE id = root_note_id;
  
  -- Recursively collect all note IDs to delete
  WITH RECURSIVE descendants AS (
    -- Base case: the root note
    SELECT id, parent_id, 1 AS depth
    FROM notes
    WHERE id = root_note_id
    
    UNION ALL
    
    -- Recursive case: direct children only, limiting recursion depth
    SELECT n.id, n.parent_id, d.depth + 1
    FROM notes n
    INNER JOIN descendants d ON n.parent_id = d.id
    WHERE d.depth < 50 -- Reasonable limit to prevent deep recursion
  )
  SELECT array_agg(id) INTO notes_to_delete
  FROM descendants;

  -- Delete the note sequences entries first to maintain referential integrity
  DELETE FROM note_sequences
  WHERE note_id = ANY(notes_to_delete);

  -- Delete all collected notes
  DELETE FROM notes
  WHERE id = ANY(notes_to_delete);

  -- Update project metadata
  UPDATE settings s
  SET 
    note_count = (
      SELECT COUNT(*)
      FROM notes n
      WHERE n.project_id = target_project_id
    ),
    last_modified_at = CURRENT_TIMESTAMP
  WHERE s.id = target_project_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to soft delete projects
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

-- Create function to restore projects
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

-- RLS policies for settings/projects
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
    AND deleted_at IS NULL
  )
  WITH CHECK (
    user_id = auth.uid()
  );

-- RLS policies for notes
CREATE POLICY "Users can read own notes" ON notes
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = notes.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can insert own notes" ON notes
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = notes.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can update own notes" ON notes
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = notes.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can delete own notes" ON notes
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = notes.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

-- RLS policies for note_sequences
CREATE POLICY "Users can read own note_sequences" ON note_sequences
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = note_sequences.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can insert own note_sequences" ON note_sequences
  FOR INSERT TO authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = note_sequences.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can update own note_sequences" ON note_sequences
  FOR UPDATE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = note_sequences.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

CREATE POLICY "Users can delete own note_sequences" ON note_sequences
  FOR DELETE TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM settings s
      WHERE s.id = note_sequences.project_id
      AND s.user_id = auth.uid()
      AND s.deleted_at IS NULL
    )
  );

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION move_note(uuid, uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION delete_note_tree(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION soft_delete_project(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION restore_project(uuid) TO authenticated;
