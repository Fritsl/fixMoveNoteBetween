import { create } from 'zustand';
import { Store } from './types';
import { createNoteSlice } from './slices/noteSlice';
import { createProjectSlice } from './slices/projectSlice';

export const useNoteStore = create<Store>((set, get) => ({
  ...createNoteSlice(set, get),
  ...createProjectSlice(set, get)
}));