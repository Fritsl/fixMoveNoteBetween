/*
  # Add soft delete functionality to projects

  1. Changes
    - Add deleted_at timestamp column to settings table
    - Update RLS policies to exclude deleted projects
    - Add function to soft delete projects
    - Add function to restore deleted projects

  2. Security
    - Maintain existing RLS policies
    - Add deleted_at check to all policies
*/

-- Add deleted_at column
ALTER TABLE settings
ADD COLUMN deleted_at timestamptz DEFAULT NULL;

-- Update RLS policies to exclude deleted projects
DROP POLICY IF EXISTS "Users can read own settings" ON settings;
CREATE POLICY "Users can read own settings" ON settings
  FOR SELECT TO authenticated
  USING (
    user_id = auth.uid() 
    AND deleted_at IS NULL
  );

DROP POLICY IF EXISTS "Users can insert own settings" ON settings;
CREATE POLICY "Users can insert own settings" ON settings
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
  );

DROP POLICY IF EXISTS "Users can update own settings" ON settings;
CREATE POLICY "Users can update own settings" ON settings
  FOR UPDATE TO authenticated
  USING (
    user_id = auth.uid() 
    AND deleted_at IS NULL
  )
  WITH CHECK (
    user_id = auth.uid()
  );

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

-- Create function to restore deleted projects
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