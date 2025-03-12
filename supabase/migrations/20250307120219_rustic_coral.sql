/*
  # Update default project title

  1. Changes
    - Change default title for settings table from 'AI Workshop Notes' to 'New Project'
    - Update any existing settings with the old default title

  2. Security
    - No changes to security policies
    - Maintains existing RLS
*/

-- Update the default value for the title column
ALTER TABLE settings 
ALTER COLUMN title SET DEFAULT 'New Project';

-- Update any existing records that have the old default title
UPDATE settings 
SET title = 'New Project' 
WHERE title = 'AI Workshop Notes';