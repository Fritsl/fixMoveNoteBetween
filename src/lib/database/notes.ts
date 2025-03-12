import { supabase } from '../supabase';
import { Note } from '../../types';
import { handleDatabaseError, handleValidationError } from '../errors';
import { sequenceOperations } from './sequences';

export const noteOperations = {
  async create(userId: string, projectId: string, parentId: string | null, content: string = '') {
    const noteId = crypto.randomUUID();

    const { error: noteError } = await supabase
      .from('notes')
      .insert({
        id: noteId,
        content,
        parent_id: parentId,
        user_id: userId,
        project_id: projectId,
        is_discussion: false
      });

    if (noteError) {
      throw handleDatabaseError(noteError, 'Failed to create note');
    }

    const sequence = await sequenceOperations.getNextSequence(projectId, parentId);

    const { error: seqError } = await supabase
      .from('note_sequences')
      .insert({
        project_id: projectId,
        parent_id: parentId,
        note_id: noteId,
        sequence: sequence || 1
      });

    if (seqError) {
      // Try to clean up the note if sequence creation failed
      await supabase.from('notes').delete().eq('id', noteId);
      throw handleDatabaseError(seqError, 'Failed to create note sequence');
    }

    return noteId;
  },

  async update(noteId: string, content: string) {
    const { error } = await supabase
      .from('notes')
      .update({ content })
      .eq('id', noteId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to update note');
    }
  },

  async delete(noteId: string) {
    const { error } = await supabase.rpc('delete_note_safely', {
      note_id: noteId
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to delete note');
    }
  },

  async move(noteId: string, newParentId: string | null, newPosition: number) {
    await sequenceOperations.moveNote(noteId, newParentId, newPosition);

    // Update parent_id in notes table
    const { error: noteError } = await supabase
      .from('notes')
      .update({ parent_id: newParentId })
      .eq('id', noteId);

    if (noteError) {
      throw handleDatabaseError(noteError, 'Failed to update note parent');
    }
  },

  async toggleDiscussion(noteId: string, value: boolean) {
    const { error } = await supabase
      .from('notes')
      .update({ is_discussion: value })
      .eq('id', noteId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to toggle discussion');
    }
  },

  async loadNotes(userId: string, projectId: string): Promise<Note[]> {
    // First get the sequences to determine order
    const { data: sequences, error: seqError } = await supabase
      .from('note_sequences')
      .select('note_id, sequence')
      .eq('project_id', projectId)
      .order('sequence');

    if (seqError) {
      throw handleDatabaseError(seqError, 'Failed to load note sequences');
    }

    const orderMap = new Map(sequences?.map(s => [s.note_id, s.sequence]) || []);

    // Then get notes with their images
    const { data: notes, error } = await supabase
      .from('notes')
      .select(`
        *,
        images:note_images(*)
      `)
      .eq('user_id', userId)
      .eq('project_id', projectId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to load notes');
    }

    // Sort notes based on sequence
    return notes?.sort((a, b) => {
      const seqA = orderMap.get(a.id) || 0;
      const seqB = orderMap.get(b.id) || 0;
      return seqA - seqB;
    }) || [];
  }
};