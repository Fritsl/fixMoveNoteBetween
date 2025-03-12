
import { useState, useEffect } from 'react';
import { NoteImage as NoteImageType } from '../types';
import { supabase } from '../lib/supabase';

interface NoteImageProps {
  image: NoteImageType;
  onDelete?: (imageId: string) => void;
}

export const NoteImage = ({ image, onDelete }: NoteImageProps) => {
  const [imageUrl, setImageUrl] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const loadImage = async () => {
      try {
        setLoading(true);
        
        // If we already have a URL, use it
        if (image.url) {
          setImageUrl(image.url);
          return;
        }
        
        // If we have a storage path, get the public URL
        if (image.storage_path) {
          const { data } = supabase.storage
            .from('note-images')
            .getPublicUrl(image.storage_path);
          
          setImageUrl(data.publicUrl);
        } else {
          setError('No image URL or storage path available');
        }
      } catch (err: any) {
        console.error('Error loading image:', err);
        setError(err.message || 'Failed to load image');
      } finally {
        setLoading(false);
      }
    };

    loadImage();
  }, [image]);

  if (loading) return <div className="w-full h-32 bg-gray-200 animate-pulse rounded"></div>;
  if (error) return <div className="text-red-500">Failed to load image: {error}</div>;
  if (!imageUrl) return null;

  return (
    <div className="relative group">
      <img 
        src={imageUrl} 
        alt="Note attachment" 
        className="max-w-full rounded-md shadow-sm" 
      />
      {onDelete && (
        <button
          onClick={() => onDelete(image.id)}
          className="absolute top-2 right-2 bg-red-500 text-white rounded-full p-1 opacity-0 group-hover:opacity-100 transition-opacity"
          aria-label="Delete image"
        >
          <svg xmlns="http://www.w3.org/2000/svg" className="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      )}
    </div>
  );
};
