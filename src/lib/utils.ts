import { Note } from '../types';
import { supabase } from './supabase';

export const formatNotesAsText = (notes: Note[], expandedNotes: Set<string> = new Set(), level = 0): string => {
  let result = '';
  const indent = '  '.repeat(level);
  
  for (const note of notes) {
    result += `${indent}• ${note.content || 'Empty note...'}\n`;
    if (note.children.length > 0 && expandedNotes.has(note.id)) {
      result += formatNotesAsText(note.children, expandedNotes, level + 1);
    }
  }
  
  return result;
};

export const findNoteById = (notes: Note[], id: string): Note | null => {
  for (const note of notes) {
    if (note.id === id) return note;
    const found = findNoteById(note.children, id);
    if (found) return found;
  }
  return null;
};

export const findNoteParents = (notes: Note[], targetId: string, path: Note[] = []): Note[] | null => {
  for (const note of notes) {
    if (note.id === targetId) {
      return path;
    }
    const found = findNoteParents(note.children, targetId, [...path, note]);
    if (found) return found;
  }
  return null;
};

export const calculateNoteLevel = (notes: Note[], targetId: string, level = 0): number | null => {
  for (const note of notes) {
    if (note.id === targetId) return level;
    const found = calculateNoteLevel(note.children, targetId, level + 1);
    if (found !== null) return found;
  }
  return null;
};

export const removeNoteById = (notes: Note[], id: string): Note[] => {
  return notes.filter(note => {
    if (note.id === id) return false;
    note.children = removeNoteById(note.children, id);
    return true;
  });
};

export const getUniqueTitle = async (userId: string, baseTitle: string): Promise<string> => {
  const trimmedTitle = baseTitle.trim();
  if (!trimmedTitle) {
    return getUniqueTitle(userId, 'New Project');
  }

  let title = trimmedTitle;
  let counter = 1;

  while (true) {
    const { data: existing } = await supabase
      .from('settings')
      .select('id')
      .eq('user_id', userId)
      .eq('title', title);

    if (!existing || existing.length === 0) {
      return title;
    }

    title = `${trimmedTitle} (${counter})`;
    counter++;
  }
};