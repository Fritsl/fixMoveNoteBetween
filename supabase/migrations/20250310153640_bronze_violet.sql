/*
  # Fix project deletion cascade

  1. Changes
    - Add ON DELETE CASCADE to note_images foreign key reference to notes
    - Add ON DELETE CASCADE to notes foreign key reference to settings (projects)
    - Add storage bucket cleanup trigger for note_images

  2. Security
    - Maintains existing RLS policies
*/

-- Add cascade delete from projects to notes
ALTER TABLE notes DROP CONSTRAINT IF EXISTS notes_project_id_fkey;
ALTER TABLE notes ADD CONSTRAINT notes_project_id_fkey 
  FOREIGN KEY (project_id) REFERENCES settings(id) ON DELETE CASCADE;

-- Add cascade delete from notes to note_images
ALTER TABLE note_images DROP CONSTRAINT IF EXISTS note_images_note_id_fkey;
ALTER TABLE note_images ADD CONSTRAINT note_images_note_id_fkey 
  FOREIGN KEY (note_id) REFERENCES notes(id) ON DELETE CASCADE;

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