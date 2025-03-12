/*
  # Remove theme functionality

  1. Changes
    - Remove theme_type enum
    - Remove theme column from notes table
    - Remove theme-related triggers
*/

-- Drop theme-related triggers
DROP TRIGGER IF EXISTS cascade_theme_changes_trigger ON notes;
DROP TRIGGER IF EXISTS set_note_theme_trigger ON notes;
DROP TRIGGER IF EXISTS update_theme_on_move_trigger ON notes;

-- Drop theme-related functions
DROP FUNCTION IF EXISTS cascade_theme_changes();
DROP FUNCTION IF EXISTS set_note_theme();
DROP FUNCTION IF EXISTS update_theme_on_move();
DROP FUNCTION IF EXISTS update_note_themes();

-- Remove theme column from notes table
ALTER TABLE notes DROP COLUMN IF EXISTS theme;

-- Drop theme_type enum
DROP TYPE IF EXISTS theme_type;