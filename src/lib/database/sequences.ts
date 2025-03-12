import { supabase } from '../supabase';
import { handleDatabaseError } from '../errors';

export const sequenceOperations = {
  async getNextSequence(projectId: string, parentId: string | null) {
    const { data: nextSeq, error } = await supabase.rpc('get_next_sequence', {
      p_project_id: projectId,
      p_parent_id: parentId
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to get next sequence number');
    }

    return nextSeq || 1;
  },

  async moveNote(noteId: string, newParentId: string | null, newPosition: number) {
    const { error } = await supabase.rpc('move_note', {
      p_note_id: noteId,
      p_new_parent_id: newParentId,
      p_new_position: newPosition
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to move note');
    }
  },

  async reorderNotes(projectId: string, parentId: string | null) {
    const { error } = await supabase.rpc('normalize_note_positions', {
      target_project_id: projectId,
      target_parent_id: parentId
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to reorder notes');
    }
  }
};