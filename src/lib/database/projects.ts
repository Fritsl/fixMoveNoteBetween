import { supabase } from '../supabase';
import { handleDatabaseError, handleValidationError } from '../errors';
import { getUniqueTitle } from '../utils';

export const projectOperations = {
  async getCurrentProjectId(): Promise<string | null> {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get('project');
  },

  async updateProjectUrl(projectId: string) {
    const newUrl = new URL(window.location.href);
    newUrl.searchParams.set('project', projectId);
    window.history.replaceState({}, '', newUrl.toString());
  },

  async getProject(projectId: string) {
    const { data, error } = await supabase
      .from('settings')
      .select('*')
      .eq('id', projectId)
      .single();

    if (error) {
      throw handleDatabaseError(error, 'Failed to get project');
    }

    return data;
  },

  async create(userId: string, title: string, description: string = '') {
    const uniqueTitle = await getUniqueTitle(userId, title);

    const { data, error } = await supabase
      .from('settings')
      .insert({
        user_id: userId,
        title: uniqueTitle,
        description
      })
      .select()
      .single();

    if (error) {
      throw handleDatabaseError(error, 'Failed to create project');
    }

    return data;
  },

  async update(projectId: string, userId: string, title: string) {
    const trimmedTitle = title.trim();
    
    if (!trimmedTitle) {
      throw handleValidationError('Title cannot be empty');
    }
    if (trimmedTitle.length > 50) {
      throw handleValidationError('Title cannot be longer than 50 characters');
    }
    if (!/^[a-zA-Z0-9\s\-_.,!?()]+$/.test(trimmedTitle)) {
      throw handleValidationError('Title can only contain letters, numbers, spaces, and basic punctuation');
    }

    const { data: existingProject } = await supabase
      .from('settings')
      .select('id')
      .eq('user_id', userId)
      .eq('title', trimmedTitle)
      .neq('id', projectId)
      .is('deleted_at', null)
      .maybeSingle();

    if (existingProject) {
      throw handleValidationError('A project with this title already exists');
    }

    const { error } = await supabase
      .from('settings')
      .update({
        title: trimmedTitle,
        updated_at: new Date().toISOString()
      })
      .eq('id', projectId)
      .eq('user_id', userId);

    if (error) {
      throw handleDatabaseError(error, 'Failed to update project');
    }
  },

  async delete(projectId: string) {
    const { error } = await supabase.rpc('soft_delete_project', {
      project_id: projectId
    });

    if (error) {
      throw handleDatabaseError(error, 'Failed to delete project');
    }
  },

  async loadProjects(userId: string) {
    const { data, error } = await supabase
      .from('settings')
      .select('*')
      .is('deleted_at', null)
      .eq('user_id', userId)
      .order('last_modified_at', { ascending: false, nullsLast: true });

    if (error) {
      throw handleDatabaseError(error, 'Failed to load projects');
    }

    return data || [];
  },

  async copy(sourceId: string, userId: string) {
    const { data: sourceProject } = await supabase
      .from('settings')
      .select('*')
      .eq('id', sourceId)
      .single();

    if (!sourceProject) {
      throw handleValidationError('Source project not found');
    }

    const uniqueTitle = await getUniqueTitle(userId, `${sourceProject.title} (Copy)`);

    const { data: newProject, error: projectError } = await supabase
      .from('settings')
      .insert({
        user_id: userId,
        title: uniqueTitle,
        description: sourceProject.description
      })
      .select()
      .single();

    if (projectError || !newProject) {
      throw handleDatabaseError(projectError, 'Failed to create project copy');
    }

    const { data: sourceNotes, error: notesError } = await supabase
      .from('notes')
      .select(`
        *,
        images:note_images(*)
      `)
      .eq('project_id', sourceId);

    if (notesError) {
      throw handleDatabaseError(notesError, 'Failed to copy notes');
    }

    if (!sourceNotes || sourceNotes.length === 0) {
      return newProject;
    }

    const idMap = new Map<string, string>();

    // First pass: Create all notes
    for (const note of sourceNotes) {
      const newId = crypto.randomUUID();
      idMap.set(note.id, newId);

      await supabase
        .from('notes')
        .insert({
          id: newId,
          content: note.content,
          parent_id: null,
          user_id: userId,
          project_id: newProject.id,
          is_discussion: note.is_discussion
        });
    }

    // Second pass: Update parent relationships
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

    // Third pass: Copy images
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

    return newProject;
  }
};