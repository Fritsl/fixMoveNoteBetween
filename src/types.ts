import { User } from '@supabase/supabase-js';

// Core data types
export interface NoteImage {
  id: string;
  note_id: string;
  url: string;
  storage_path?: string;
  position: number;
  created_at?: string;
  updated_at?: string;
}

export interface Note {
  id: string;
  content: string;
  children: Note[];
  isEditing: boolean;
  unsavedContent?: string;
  sequence_number?: number;
  user_id: string;
  project_id: string;
  is_discussion: boolean;
  created_at?: string;
  updated_at?: string;
  images?: NoteImage[];
}

export interface Project {
  id: string;
  title: string;
  description: string;
  user_id: string;
  note_count: number;
  created_at?: string;
  updated_at?: string;
  last_modified_at?: string;
}

// Store types
export interface UndoCommand {
  execute: () => void;
  undo: () => void;
  description: string;
}

export interface BaseState {
  notes: Note[];
  title: string;
  isEditMode: boolean;
  undoStack: UndoCommand[];
  canUndo: boolean;
  expandedNotes: Set<string>;
  currentLevel: number;
  canExpandMore: boolean;
  canCollapseMore: boolean;
}

export interface NoteState extends BaseState {
  undo: () => void;
  expandOneLevel: () => void;
  collapseOneLevel: () => void;
  setCurrentLevel: (level: number) => void;
  deleteNote: (id: string) => Promise<void>;
  addNote: (parentId: string | null) => Promise<void>;
  updateNote: (id: string, content: string) => Promise<void>;
  toggleEdit: (id: string) => void;
  moveNote: (id: string, parentId: string | null, index: number) => Promise<void>;
  setEditMode: (isEditing: boolean) => void;
  addImage: (noteId: string, url: string) => Promise<void>;
  removeImage: (noteId: string, imageId: string) => Promise<void>;
  printNotes: () => string;
  saveNote: (id: string) => Promise<void>;
  toggleDiscussion: (id: string, value: boolean) => Promise<void>;
}

export interface ProjectState extends BaseState {
  projects: Project[];
  updateTitle: (title: string) => Promise<void>;
  copyProject: (id: string) => Promise<void>;
  loadProjects: () => Promise<void>;
  deleteProject: (id: string) => Promise<void>;
  switchProject: (projectId: string) => Promise<void>;
  loadNotes: () => Promise<void>;
}

export type Store = NoteState & ProjectState;