/*
  # Add unique constraint for project titles

  1. Changes
    - Add unique constraint for title + user_id combination
    - This ensures titles are unique per user but allows different users to have the same title
*/

-- Add unique constraint for title per user
ALTER TABLE settings
ADD CONSTRAINT unique_title_per_user UNIQUE (user_id, title);