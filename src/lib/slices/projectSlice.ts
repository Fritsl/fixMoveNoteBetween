import { StateCreator } from 'zustand';
import { Store } from '../../types';
import { supabase } from '../supabase';
import { databaseOperations } from '../state';
import { getUniqueTitle } from '../utils';

export const createProjectSlice: StateCreator<Store> = (set, get) => ({
  title: 'New Project',
  projects: [],

  updateTitle: async (title: string) => {
    const user = await databaseOperations.validateUser();
    const projectId = await databaseOperations.getCurrentProject();

    try {
      const trimmedTitle = title.trim();
      if (!trimmedTitle) {
        throw new Error('Title cannot be empty');
      }
      if (trimmedTitle.length > 50) {
        throw new Error('Title cannot be longer than 50 characters');
      }
      if (!/^[a-zA-Z0-9\s\-_.,!?()]+$/.test(trimmedTitle)) {
        throw new Error('Title can only contain letters, numbers, spaces, and basic punctuation');
      }
      
      const { data: existingProject } = await supabase
        .from('settings')
        .select('id')
        .eq('user_id', user.id)
        .eq('title', trimmedTitle)
        .neq('id', projectId)
        .is('deleted_at', null)
        .maybeSingle();

      if (existingProject) {
        throw new Error('A project with this title already exists');
      }

      const { error } = await supabase
        .from('settings')
        .update({
          title: trimmedTitle,
          updated_at: new Date().toISOString()
        })
        .eq('id', projectId)
        .eq('user_id', user.id);

      if (error) throw error;

      set({ title: trimmedTitle });

      set(state => ({
        projects: state.projects.map(p =>
          p.id === projectId ? {
            ...p,
            title: trimmedTitle,
            updated_at: new Date().toISOString()
          } : p
        )
      }));
    } catch (error) {
      console.error('Error updating title:', error);
      throw error;
    }
  },

  loadProjects: async () => {
    const user = await databaseOperations.validateUser();

    const { data: projects, error } = await supabase
      .from('settings')
      .select('*')
      .is('deleted_at', null)
      .eq('user_id', user.id)
      .order('last_modified_at', { ascending: false, nullsLast: true });

    if (error) {
      console.error('Error loading projects:', error);
      return;
    }

    set({ projects: projects || [] });
  },

  switchProject: async (projectId: string) => {
    const user = await databaseOperations.validateUser();
    set({ notes: [] });

    try {
      const { data: project, error: projectError } = await supabase
        .from('settings')
        .select('*')
        .is('deleted_at', null)
        .eq('user_id', user.id)
        .eq('id', projectId)
        .single();

      if (projectError || !project) {
        throw new Error('Project not found');
      }

      await databaseOperations.updateProjectUrl(project.id);
      set({ title: project.title });

      const { data: notes, error } = await supabase
        .from('notes')
        .select(`
          *,
          images:note_images(*)
        `)
        .eq('user_id', user.id)
        .eq('project_id', projectId);

      if (error) {
        throw new Error('Failed to load notes');
      }

      const noteMap = new Map(notes?.map(note => ({
        ...note,
        images: note.images?.sort((a, b) => a.position - b.position) || [],
        children: []
      })).map(note => [note.id, note]) ?? []);
      const rootNotes: Store['notes'] = [];

      notes?.forEach(note => {
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
      console.error('Error switching project:', error);
      throw error;
    }
  },

  deleteProject: async (id: string) => {
    const user = await databaseOperations.validateUser();
    const urlParams = new URLSearchParams(window.location.search);
    const currentProjectId = urlParams.get('project');

    try {
      const { error: projectError } = await supabase.rpc('soft_delete_project', {
        project_id: id
      });

      if (projectError) throw projectError;

      if (currentProjectId === id) {
        const { data: remainingProjects } = await supabase
          .from('settings')
          .select()
          .is('deleted_at', null)
          .eq('user_id', user.id)
          .order('last_modified_at', { ascending: false, nullsLast: true })
          .limit(1);

        if (remainingProjects && remainingProjects.length > 0) {
          await databaseOperations.updateProjectUrl(remainingProjects[0].id);
          await get().switchProject(remainingProjects[0].id);
        } else {
          const { data: newProject } = await supabase
            .from('settings')
            .insert({
              user_id: user.id,
              title: 'New Project'
            })
            .select()
            .single();

          if (newProject) {
            await databaseOperations.updateProjectUrl(newProject.id);
            await get().switchProject(newProject.id);
          }
        }
      }

      const { data: updatedProjects } = await supabase
        .from('settings')
        .select('*')
        .is('deleted_at', null)
        .eq('user_id', user.id)
        .order('created_at');

      set({ projects: updatedProjects || [] });
    } catch (error) {
      console.error('Error deleting project:', error);
      throw error;
    }
  },

  copyProject: async (id: string) => {
    const user = await databaseOperations.validateUser();

    try {
      const { data: sourceProject } = await supabase
        .from('settings')
        .select('*')
        .eq('id', id)
        .single();

      if (!sourceProject) {
        throw new Error('Source project not found');
      }

      const uniqueTitle = await getUniqueTitle(user.id, `${sourceProject.title} (Copy)`);

      const { data: newProject, error: projectError } = await supabase
        .from('settings')
        .insert({
          user_id: user.id,
          title: uniqueTitle,
          description: sourceProject.description
        })
        .select()
        .single();

      if (projectError || !newProject) {
        throw new Error('Failed to create new project');
      }

      const { data: sourceNotes, error: notesError } = await supabase
        .from('notes')
        .select(`
          *,
          images:note_images(*)
        `)
        .eq('project_id', id)
        .order('position');

      if (notesError) {
        throw new Error('Failed to fetch source notes');
      }

      if (!sourceNotes || sourceNotes.length === 0) {
        await databaseOperations.updateProjectUrl(newProject.id);
        await get().switchProject(newProject.id);
        return;
      }

      const idMap = new Map<string, string>();
      
      for (const note of sourceNotes) {
        const newId = crypto.randomUUID();
        idMap.set(note.id, newId);
        
        await supabase
          .from('notes')
          .insert({
            id: newId,
            content: note.content,
            parent_id: null,
            user_id: user.id,
            project_id: newProject.id,
            is_discussion: note.is_discussion
          });
      }

      for (const note of sourceNotes) {
        if (note.parent_id) {
          const newParentId = idMap.get(note.parent_id);
          if (newParentId) {
            await supabase
              .from('notes')
              .update({ parent_id: newParentId })
              .eq('id', idMap.get(note.id));
          }
        }
      }

      for (const note of sourceNotes) {
        if (note.images && note.images.length > 0) {
          for (const image of note.images) {
            await supabase
              .from('note_images')
              .insert({
                note_id: idMap.get(note.id),
                url: image.url,
                storage_path: image.storage_path,
                position: image.position
              });
          }
        }
      }

      await databaseOperations.updateProjectUrl(newProject.id);
      await get().switchProject(newProject.id);
    } catch (error) {
      console.error('Error copying project:', error);
      throw error;
    }
  },

  loadNotes: async () => {
    const user = await databaseOperations.validateUser();

    try {
      const { data: existingSettings, error: settingsError } = await supabase
        .from('settings')
        .select()
        .is('deleted_at', null)
        .eq('user_id', user.id)
        .order('last_modified_at', { ascending: false, nullsLast: true });

      if (settingsError) {
        console.error('Error loading settings:', settingsError);
        return;
      }

      if (existingSettings && existingSettings.length > 0) {
        const urlParams = new URLSearchParams(window.location.search);
        const projectId = urlParams.get('project');

        let currentProject = projectId 
          ? existingSettings.find(p => p.id === projectId) 
          : existingSettings[0];

        if (!currentProject) {
          currentProject = existingSettings[0];
        }

        await databaseOperations.updateProjectUrl(currentProject.id);

        set({ 
          title: currentProject.title,
          projects: existingSettings
        });

        const { data: notes, error } = await supabase
          .from('notes')
          .select(`
            *,
            images:note_images(*)
          `)
          .eq('user_id', user.id)
          .eq('project_id', currentProject.id);

        if (error) {
          console.error('Error loading notes:', error);
          return;
        }

        const noteMap = new Map(notes?.map(note => ({
          ...note,
          images: note.images?.sort((a, b) => a.position - b.position) || [],
          children: []
        })).map(note => [note.id, note]) ?? []);
        const rootNotes: Store['notes'] = [];

        notes?.forEach(note => {
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
        const { data: newSettings } = await supabase
          .from('settings')
          .insert({
            user_id: user.id,
            title: 'New Project'
          })
          .select()
          .single();

        if (!newSettings) {
          console.error('Failed to create initial project');
          return;
        }

        set({ 
          title: newSettings.title,
          projects: [newSettings],
          notes: []
        });

        await databaseOperations.updateProjectUrl(newSettings.id);
      }
    } catch (error) {
      console.error('Error in loadNotes:', error);
    }
  }
});