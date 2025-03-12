import { StateCreator } from 'zustand';
import { Store } from '../types';
import { supabase } from './supabase';
import { handleDatabaseError, handleValidationError } from './errors';

// Common state management utilities
export const createBaseState = (): Pick<Store, 'notes' | 'title' | 'isEditMode' | 'undoStack' | 'canUndo' | 'expandedNotes' | 'currentLevel' | 'canExpandMore' | 'canCollapseMore'> => ({
  notes: [],
  title: 'New Project',
  isEditMode: false,
  undoStack: [],
  canUndo: false,
  expandedNotes: new Set<string>(),
  currentLevel: 0,
  canExpandMore: false,
  canCollapseMore: false
});

// Common database operations
export const databaseOperations = {
  async validateUser() {
    const { data: userData } = await supabase.auth.getUser();
    if (!userData.user) {
      throw handleValidationError('User authentication required');
    }
    return userData.user;
  },

  async getCurrentProject() {
    const urlParams = new URLSearchParams(window.location.search);
    const projectId = urlParams.get('project');
    if (!projectId) {
      throw handleValidationError('Project ID is required');
    }
    return projectId;
  },

  async updateProjectUrl(projectId: string) {
    const newUrl = new URL(window.location.href);
    newUrl.searchParams.set('project', projectId);
    window.history.replaceState({}, '', newUrl.toString());
  }
};

// Common state update utilities
export const stateUtils = {
  addToUndoStack: <T extends Store>(
    set: StateCreator<T, [], []>['set'],
    command: { execute: () => void; undo: () => void; description: string }
  ) => {
    set(state => ({
      ...state,
      undoStack: [...state.undoStack, command],
      canUndo: true
    }));
  },

  calculateTreeDepth: (notes: Store['notes']): number => {
    let maxDepth = 0;
    const traverse = (notes: Store['notes'], depth = 0) => {
      maxDepth = Math.max(maxDepth, depth);
      notes.forEach(note => {
        if (note.children.length > 0) {
          traverse(note.children, depth + 1);
        }
      });
    };
    traverse(notes);
    return maxDepth;
  }
};

// Common sequence management
export const sequenceOperations = {
  async getNextSequence(projectId: string, parentId: string | null) {
    const { data: nextSeq, error } = await supabase.rpc('get_next_sequence', {
      p_project_id: projectId,
      p_parent_id: parentId
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to get sequence number');
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
  }
};

// Common image operations
export const imageOperations = {
  async addImage(noteId: string, url: string) {
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
      throw handleValidationError('Failed to create image record');
    }

    return data[0];
  },

  async removeImage(imageId: string) {
    const { error } = await supabase
      .from('note_images')
      .delete()
      .eq('id', imageId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to remove image');
    }
  }
};