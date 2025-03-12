/*
  # Configure storage policies for note images

  1. Security
    - Add policies for authenticated users to:
      - Upload images to their own folder
      - Read any public image
      - Delete their own images
    
  2. Access Control
    - Users can only upload to their own user ID folder
    - Anyone can view images
    - Users can only delete their own images

  Note: This assumes the 'note-images' bucket already exists
*/

-- Create policies for the storage bucket
CREATE POLICY "Users can upload images"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "Anyone can view images"
  ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'note-images');

CREATE POLICY "Users can delete their own images"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );