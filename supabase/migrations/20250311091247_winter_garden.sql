/*
  # Add title validation with data cleanup

  1. Changes
    - Clean up existing titles to match new constraints
    - Add check constraints for title validation
    - Ensure all titles are properly formatted

  2. Notes
    - Updates existing data before adding constraints
    - Handles empty, oversized, and invalid titles
    - Maintains data integrity
*/

-- First, clean up existing titles
UPDATE settings 
SET title = regexp_replace(
  trim(
    CASE 
      WHEN length(title) > 50 THEN substring(title, 1, 50)
      WHEN length(trim(title)) = 0 THEN 'Untitled Project'
      ELSE title
    END
  ),
  '[^a-zA-Z0-9\s\-_.,!?()]', 
  '', 
  'g'
);

-- Handle any remaining empty titles after cleanup
UPDATE settings
SET title = 'Untitled Project'
WHERE length(trim(title)) = 0;

-- Now add the constraints after data is clean
ALTER TABLE settings
  ADD CONSTRAINT title_length_check 
    CHECK (length(trim(title)) BETWEEN 1 AND 50);

ALTER TABLE settings
  ADD CONSTRAINT title_whitespace_check 
    CHECK (title = trim(title));

ALTER TABLE settings
  ADD CONSTRAINT title_characters_check 
    CHECK (title ~ '^[a-zA-Z0-9\s\-_.,!?()]+$');