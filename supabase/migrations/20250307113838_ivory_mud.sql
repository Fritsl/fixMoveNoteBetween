/*
  # Flush database

  1. Changes
    - Delete all data from notes table
    - Delete all data from settings table
    - Preserve table structure and RLS policies

  2. Notes
    - This is a destructive operation that removes all user data
    - Table schemas and security policies remain intact
*/

-- Delete all data from notes table
DELETE FROM notes;

-- Delete all data from settings table
DELETE FROM settings;