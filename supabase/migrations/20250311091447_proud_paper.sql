/*
  # Add project description and improve title handling

  1. Changes
    - Add description column to settings table
    - Set default description for existing projects
    - Add length constraint for description

  2. Validation
    - Description length limited to 500 characters
*/

-- Add description column with default value
ALTER TABLE settings
ADD COLUMN description text NOT NULL DEFAULT '';

-- Add length constraint for description
ALTER TABLE settings
ADD CONSTRAINT description_length_check 
CHECK (length(description) <= 500);