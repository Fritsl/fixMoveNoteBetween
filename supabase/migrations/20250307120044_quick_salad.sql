/*
  # Flush all project data

  1. Changes
    - Delete all notes
    - Delete all settings/projects
    - Reset sequences if any exist

  2. Security
    - Maintains existing RLS policies
    - No changes to table structure or permissions
*/

-- Delete all notes first to maintain referential integrity
DELETE FROM notes;

-- Then delete all settings/projects
DELETE FROM settings;