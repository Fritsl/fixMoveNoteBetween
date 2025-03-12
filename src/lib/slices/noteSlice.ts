import { StateCreator } from 'zustand';
import { Store } from '../../types';
import { supabase } from '../supabase';
import { findNoteById, removeNoteById } from '../utils';
import { databaseOperations, imageOperations, sequenceOperations, stateUtils } from '../state';

export const createNoteSlice: StateCreator<Store> = (set, get) => ({
  notes: [],
  undoStack: [],
  canUndo: false,
  isEditMode: false,
  expandedNotes: new Set<string>(),
  currentLevel: 0,
  canExpandMore: false,
  canCollapseMore: false,

  undo: () => {
    const { undoStack } = get();
    if (undoStack.length > 0) {
      const command = undoStack[undoStack.length - 1];
      command.undo();
      set(state => ({
        undoStack: state.undoStack.slice(0, -1),
        canUndo: state.undoStack.length > 1
      }));
    }
  },

  updateNote: async (id: string, content: string) => {
    set(state => {
      const updateNoteContent = (notes: Store['notes']): Store['notes'] => {
        const oldNote = findNoteById(state.notes, id);
        const oldContent = oldNote?.content;
        return notes.map(note => {
          if (note.id === id) {
            stateUtils.addToUndoStack(set, {
              execute: () => get().updateNote(id, content),
              undo: () => {
                if (oldContent !== undefined) {
                  get().updateNote(id, oldContent);
                  if (oldNote) get().toggleDiscussion(id, oldNote.is_discussion);
                  get().saveNote(id);
                }
              },
              description: `Update note content`
            });
            return { ...note, unsavedContent: content };
          }
          return { ...note, children: updateNoteContent(note.children) };
        });
      };
      return { 
        notes: updateNoteContent(state.notes),
        canUndo: true
      };
    });
  },

  deleteNote: async (id: string) => {
    try {
      const { error } = await supabase.rpc('delete_note_safely', {
        note_id: id
      });

      if (error) throw error;

      set(state => ({
        notes: removeNoteById(state.notes, id)
      }));
    } catch (error) {
      console.error('Error deleting note:', error);
      throw error;
    }
  },

  addNote: async (parentId: string | null) => {
    const user = await databaseOperations.validateUser();
    const projectId = await databaseOperations.getCurrentProject();

    const sequence = await sequenceOperations.getNextSequence(projectId, parentId);

    const newNote = {
      id: crypto.randomUUID(),
      content: '',
      children: [],
      isEditing: true,
      unsavedContent: '',
      user_id: user.id,
      project_id: projectId,
      is_discussion: false,
      images: []
    };

    const { error: noteError } = await supabase
      .from('notes')
      .insert({
        id: newNote.id,
        content: newNote.content,
        parent_id: parentId,
        user_id: user.id,
        project_id: projectId,
        is_discussion: false
      });

    if (noteError) throw noteError;

    const { error: seqError } = await supabase
      .from('note_sequences')
      .insert({
        project_id: projectId,
        parent_id: parentId,
        note_id: newNote.id,
        sequence
      });

    if (seqError) throw seqError;

    set(state => {
      if (!parentId) {
        return { notes: [...state.notes, newNote] };
      }

      const updateChildren = (notes: Store['notes']): Store['notes'] => {
        return notes.map(note => {
          if (note.id === parentId) {
            const newChildren = [...note.children, newNote];
            return { ...note, children: newChildren };
          }
          return { ...note, children: updateChildren(note.children) };
        });
      };

      return { notes: updateChildren(state.notes) };
    });
  },

  saveNote: async (id: string) => {
    const note = findNoteById(get().notes, id);
    if (!note?.unsavedContent && note?.content === '') {
      await supabase
        .from('notes')
        .delete()
        .eq('id', id);
      set(state => ({ notes: removeNoteById(state.notes, id) }));
      return;
    }

    if (note && note.unsavedContent !== undefined) {
      await supabase
        .from('notes')
        .update({ content: note.unsavedContent })
        .eq('id', id);

      set(state => {
        const updateContent = (notes: Store['notes']): Store['notes'] => {
          return notes.map(n => {
            if (n.id === id) {
              return { ...n, content: note.unsavedContent, unsavedContent: undefined };
            }
            return { ...n, children: updateContent(n.children) };
          });
        };
        return { notes: updateContent(state.notes) };
      });
    }
  },

  toggleEdit: (id: string) => {
    set(state => {
      const toggleNoteEdit = (notes: Store['notes']): Store['notes'] => {
        return notes.map(note => {
          if (note.id === id) {
            const newIsEditing = !note.isEditing;
            set(state => ({ ...state, isEditMode: newIsEditing }));
            return { ...note, isEditing: newIsEditing };
          }
          return { ...note, children: toggleNoteEdit(note.children) };
        });
      };
      return { notes: toggleNoteEdit(state.notes) };
    });
  },

  setCurrentLevel: (level: number) => {
    const state = get();
    const treeDepth = stateUtils.calculateTreeDepth(state.notes);
    const newLevel = Math.max(0, Math.min(level, treeDepth));

    const newExpandedNotes = new Set(state.expandedNotes);
    const updateExpanded = (notes: Store['notes'], currentDepth = 0) => {
      notes.forEach(note => {
        if (note.children.length > 0) {
          if (currentDepth < newLevel) {
            newExpandedNotes.add(note.id);
          } else {
            newExpandedNotes.delete(note.id);
          }
          updateExpanded(note.children, currentDepth + 1);
        }
      });
    };

    updateExpanded(state.notes);

    set({
      expandedNotes: newExpandedNotes,
      currentLevel: newLevel,
      canExpandMore: newLevel < treeDepth,
      canCollapseMore: newLevel > 0
    });
  },

  expandOneLevel: () => {
    const state = get();
    return state.setCurrentLevel(state.currentLevel + 1);
  },

  collapseOneLevel: () => {
    const state = get();
    return state.setCurrentLevel(state.currentLevel - 1);
  },

  setEditMode: (isEditing: boolean) => set({ isEditMode: isEditing }),

  addImage: async (noteId: string, url: string) => {
    const image = await imageOperations.addImage(noteId, url);
    set(state => {
      const newNotes = [...state.notes];
      const noteIndex = newNotes.findIndex(note => note.id === noteId);
      if (noteIndex !== -1) {
        if (!newNotes[noteIndex].images) {
          newNotes[noteIndex].images = [];
        }
        newNotes[noteIndex].images?.push(image);
      }
      return { notes: newNotes };
    });
  },

  removeImage: async (noteId: string, imageId: string) => {
    await imageOperations.removeImage(imageId);
    set(state => {
      const newNotes = [...state.notes];
      const noteIndex = newNotes.findIndex(note => note.id === noteId);
      if (noteIndex !== -1 && newNotes[noteIndex].images) {
        newNotes[noteIndex].images = newNotes[noteIndex].images?.filter(
          img => img.id !== imageId
        );
      }
      return { notes: newNotes };
    });
  },

  toggleDiscussion: async (id: string, value: boolean) => {
    try {
      const { error } = await supabase
        .from('notes')
        .update({ is_discussion: value })
        .eq('id', id);

      if (error) throw error;

      set(state => {
        const updateDiscussionFlag = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === id) {
              stateUtils.addToUndoStack(set, {
                execute: () => get().toggleDiscussion(id, value),
                undo: () => get().toggleDiscussion(id, !value),
                description: `Toggle discussion flag`
              });
              return { ...note, is_discussion: value };
            }
            return { ...note, children: updateDiscussionFlag(note.children) };
          });
        };
        return { notes: updateDiscussionFlag(state.notes), canUndo: true };
      });
    } catch (error) {
      console.error('Error toggling discussion flag:', error);
    }
  },

  moveNote: async (id: string, parentId: string | null, index: number) => {
    await sequenceOperations.moveNote(id, parentId, index);
    set(state => {
      const noteToMove = findNoteById(state.notes, id);
      if (!noteToMove) return state;

      const notesWithoutMoved = removeNoteById(state.notes, id);

      if (!parentId) {
        const newNotes = [...notesWithoutMoved];
        newNotes.splice(index, 0, noteToMove);
        return { notes: newNotes };
      }

      const insertIntoParent = (notes: Store['notes']): Store['notes'] => {
        return notes.map(note => {
          if (note.id === parentId) {
            const newChildren = [...note.children];
            newChildren.splice(index, 0, noteToMove);
            return { ...note, children: newChildren };
          }
          return { ...note, children: insertIntoParent(note.children) };
        });
      };

      return { notes: insertIntoParent(notesWithoutMoved) };
    });
  },

  printNotes: () => {
    const { notes, expandedNotes } = get();
    let result = '';
    const formatNote = (note: Store['notes'][0], level = 0) => {
      const indent = '  '.repeat(level);
      result += `${indent}• ${note.content || 'Empty note...'}\n`;
      if (note.children.length > 0 && expandedNotes.has(note.id)) {
        note.children.forEach(child => formatNote(child, level + 1));
      }
    };
    notes.forEach(note => formatNote(note));
    return result;
  }
});