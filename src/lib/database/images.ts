import { supabase } from '../supabase';
import { handleDatabaseError } from '../errors';

export const imageOperations = {
  async add(noteId: string, url: string) {
    const { data, error } = await supabase
      .from('note_images')
      .insert([{
        note_id: noteId,
        url,
        position: 0
      }])
      .select();

    if (error) {
      throw handleDatabaseError(error, 'Failed to add image');
    }

    if (!data || data.length === 0) {
      throw handleDatabaseError(new Error('No data returned'), 'Failed to create image record');
    }

    return data[0];
  },

  async remove(imageId: string) {
    const { error } = await supabase
      .from('note_images')
      .delete()
      .eq('id', imageId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to remove image');
    }
  },

  async getStorageUrl(path: string) {
    const { data } = supabase.storage
      .from('note-images')
      .getPublicUrl(path);

    return data.publicUrl;
  }
};