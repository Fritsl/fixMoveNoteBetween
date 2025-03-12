
-- Reset and reconfigure the storage bucket for note images
DO $$
BEGIN
  -- Create the bucket if it doesn't exist (or recreate it)
  DROP POLICY IF EXISTS "Users can upload images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can read own images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can delete own images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can upload their own images" ON storage.objects;
  DROP POLICY IF EXISTS "Anyone can view images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can delete their own images" ON storage.objects;
  DROP POLICY IF EXISTS "Users can view images from their notes" ON storage.objects;
  
  -- Make sure the bucket exists and is public
  INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
  VALUES (
    'note-images', 
    'note-images', 
    true, 
    5242880, -- 5MB limit
    ARRAY['image/png', 'image/jpeg', 'image/gif', 'image/webp']::text[]
  )
  ON CONFLICT (id) DO UPDATE 
  SET 
    public = true,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/png', 'image/jpeg', 'image/gif', 'image/webp']::text[];
END $$;

-- Enable RLS
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Create upload policy
CREATE POLICY "Anyone can upload images" ON storage.objects
  FOR INSERT TO public
  WITH CHECK (bucket_id = 'note-images');

-- Create read policy
CREATE POLICY "Anyone can view images" ON storage.objects
  FOR SELECT TO public
  USING (bucket_id = 'note-images');

-- Create delete policy - only authenticated users can delete their own uploads
CREATE POLICY "Authenticated users can delete their own images" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'note-images' AND
    (storage.foldername(name))[1] = auth.uid()::text
  );
