import { StateCreator } from 'zustand';
import { Store } from '../types';
import { findNoteById, removeNoteById } from '../../utils';
import { database } from '../../database';
import { handleDatabaseError } from '../../errors';

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
    try {
      await database.notes.update(id, content);
      set(state => {
        const updateNoteContent = (notes: Store['notes']): Store['notes'] => {
          const oldNote = findNoteById(state.notes, id);
          const oldContent = oldNote?.content;
          return notes.map(note => {
            if (note.id === id) {
              state.undoStack.push({
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
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to update note');
    }
  },

  deleteNote: async (id: string) => {
    try {
      await database.notes.delete(id);
      set(state => ({
        notes: removeNoteById(state.notes, id)
      }));
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to delete note');
    }
  },

  addNote: async (parentId: string | null) => {
    try {
      const user = await database.auth.getCurrentUser();
      const projectId = await database.projects.getCurrentProjectId();
      if (!projectId) return;

      const noteId = await database.notes.create(user.id, projectId, parentId);

      const newNote = {
        id: noteId,
        content: '',
        children: [],
        isEditing: true,
        unsavedContent: '',
        user_id: user.id,
        project_id: projectId,
        is_discussion: false,
        images: []
      };

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
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to add note');
    }
  },

  saveNote: async (id: string) => {
    const note = findNoteById(get().notes, id);
    if (!note?.unsavedContent && note?.content === '') {
      await database.notes.delete(id);
      set(state => ({ notes: removeNoteById(state.notes, id) }));
      return;
    }

    if (note && note.unsavedContent !== undefined) {
      await database.notes.update(id, note.unsavedContent);
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
    const treeDepth = Math.max(...state.notes.map(note => {
      let depth = 0;
      const traverse = (note: Store['notes'][0], currentDepth = 0) => {
        depth = Math.max(depth, currentDepth);
        note.children.forEach(child => traverse(child, currentDepth + 1));
      };
      traverse(note);
      return depth;
    }));

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
    try {
      const image = await database.images.add(noteId, url);
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
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to add image');
    }
  },

  removeImage: async (noteId: string, imageId: string) => {
    try {
      await database.images.remove(imageId);
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
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to remove image');
    }
  },

  toggleDiscussion: async (id: string, value: boolean) => {
    try {
      await database.notes.toggleDiscussion(id, value);
      set(state => {
        const updateDiscussionFlag = (notes: Store['notes']): Store['notes'] => {
          return notes.map(note => {
            if (note.id === id) {
              state.undoStack.push({
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
      throw handleDatabaseError(error, 'Failed to toggle discussion');
    }
  },

  moveNote: async (id: string, parentId: string | null, index: number) => {
    try {
      await database.notes.move(id, parentId, index);
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
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to move note');
    }
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