import { StateCreator } from 'zustand';
import { Store } from '../types';
import { database } from '../../database';
import { handleDatabaseError } from '../../errors';

export const createProjectSlice: StateCreator<Store> = (set, get) => ({
  title: 'New Project',
  projects: [],

  updateTitle: async (title: string) => {
    try {
      const user = await database.auth.getCurrentUser();
      const projectId = await database.projects.getCurrentProjectId();
      if (!projectId) return;

      await database.projects.update(projectId, user.id, title);

      set({ title });
      set(state => ({
        projects: state.projects.map(p =>
          p.id === projectId ? {
            ...p,
            title,
            updated_at: new Date().toISOString()
          } : p
        )
      }));
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to update title');
    }
  },

  loadProjects: async () => {
    try {
      const user = await database.auth.getCurrentUser();
      const projects = await database.projects.loadProjects(user.id);
      set({ projects });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to load projects');
    }
  },

  switchProject: async (projectId: string) => {
    try {
      const user = await database.auth.getCurrentUser();
      set({ notes: [] });

      const project = await database.projects.getProject(projectId);
      if (!project) {
        throw new Error('Project not found');
      }

      await database.projects.updateProjectUrl(projectId);
      set({ title: project.title });

      const notes = await database.notes.loadNotes(user.id, projectId);
      const noteMap = new Map(notes.map(note => ({
        ...note,
        images: note.images?.sort((a, b) => a.position - b.position) || [],
        children: [],
        isEditing: false,
        unsavedContent: undefined
      })).map(note => [note.id, note]));

      const rootNotes: Store['notes'] = [];

      notes.forEach(note => {
        const noteWithChildren = noteMap.get(note.id);
        if (noteWithChildren) {
          if (note.parent_id && noteMap.has(note.parent_id)) {
            const parent = noteMap.get(note.parent_id);
            parent?.children.push(noteWithChildren);
          } else {
            rootNotes.push(noteWithChildren);
          }
        }
      });

      set({ notes: rootNotes });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to switch project');
    }
  },

  deleteProject: async (id: string) => {
    try {
      await database.projects.delete(id);

      const currentProjectId = await database.projects.getCurrentProjectId();
      if (currentProjectId === id) {
        const user = await database.auth.getCurrentUser();
        const remainingProjects = await database.projects.loadProjects(user.id);

        if (remainingProjects.length > 0) {
          await get().switchProject(remainingProjects[0].id);
        } else {
          const newProject = await database.projects.create(user.id, 'New Project');
          await get().switchProject(newProject.id);
        }
      }

      const user = await database.auth.getCurrentUser();
      const updatedProjects = await database.projects.loadProjects(user.id);
      set({ projects: updatedProjects });
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to delete project');
    }
  },

  copyProject: async (id: string) => {
    try {
      const user = await database.auth.getCurrentUser();
      const newProject = await database.projects.copy(id, user.id);
      await get().switchProject(newProject.id);
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to copy project');
    }
  },

  loadNotes: async () => {
    try {
      const user = await database.auth.getCurrentUser();
      const projects = await database.projects.loadProjects(user.id);

      if (projects.length > 0) {
        const projectId = await database.projects.getCurrentProjectId() || projects[0].id;
        const currentProject = projects.find(p => p.id === projectId) || projects[0];

        await database.projects.updateProjectUrl(currentProject.id);

        set({ 
          title: currentProject.title,
          projects
        });

        const notes = await database.notes.loadNotes(user.id, currentProject.id);
        const noteMap = new Map(notes.map(note => ({
          ...note,
          images: note.images?.sort((a, b) => a.position - b.position) || [],
          children: [],
          isEditing: false,
          unsavedContent: undefined
        })).map(note => [note.id, note]));

        const rootNotes: Store['notes'] = [];

        notes.forEach(note => {
          const noteWithChildren = noteMap.get(note.id);
          if (noteWithChildren) {
            if (note.parent_id && noteMap.has(note.parent_id)) {
              const parent = noteMap.get(note.parent_id);
              parent?.children.push(noteWithChildren);
            } else {
              rootNotes.push(noteWithChildren);
            }
          }
        });

        set({ notes: rootNotes });
      } else {
        const newProject = await database.projects.create(user.id, 'New Project');
        set({ 
          title: newProject.title,
          projects: [newProject],
          notes: []
        });
        await database.projects.updateProjectUrl(newProject.id);
      }
    } catch (error) {
      throw handleDatabaseError(error, 'Failed to load notes');
    }
  }
});