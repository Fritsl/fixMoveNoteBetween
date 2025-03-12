import React, { useState, useEffect, useRef } from 'react';
import { X } from 'lucide-react';
import { supabase } from '../lib/supabase';
import { getUniqueTitle } from '../lib/utils';

interface NewProjectModalProps {
  onClose: () => void;
  onSuccess: (projectId: string) => void;
}

export function NewProjectModal({ onClose, onSuccess }: NewProjectModalProps) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const titleInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    // Generate unique default title
    const generateDefaultTitle = async () => {
      const { data: userData } = await supabase.auth.getUser();
      if (userData.user) {
        const defaultTitle = await getUniqueTitle(userData.user.id, 'New Project');
        setTitle(defaultTitle);
      }
    };
    generateDefaultTitle();

    // Focus title input
    if (titleInputRef.current) {
      titleInputRef.current.focus();
      titleInputRef.current.select();
    }
  }, []);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setIsLoading(true);

    try {
      const { data: userData } = await supabase.auth.getUser();
      if (!userData.user) {
        throw new Error('Not authenticated');
      }

      // Validate title
      if (!title.trim()) {
        throw new Error('Title is required');
      }
      if (title.length > 50) {
        throw new Error('Title cannot be longer than 50 characters');
      }
      if (!/^[a-zA-Z0-9\s\-_.,!?()]+$/.test(title)) {
        throw new Error('Title can only contain letters, numbers, spaces, and basic punctuation');
      }

      // Validate description
      if (description.length > 500) {
        throw new Error('Description cannot be longer than 500 characters');
      }

      // Get unique title
      const uniqueTitle = await getUniqueTitle(userData.user.id, title);

      // Create project
      const { data: project, error: projectError } = await supabase
        .from('settings')
        .insert({
          user_id: userData.user.id,
          title: uniqueTitle,
          description
        })
        .select()
        .single();

      if (projectError) throw projectError;
      if (!project) throw new Error('Failed to create project');

      onSuccess(project.id);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to create project');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Create New Project</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="p-4">
          <div className="space-y-4">
            <div>
              <label htmlFor="title" className="block text-sm font-medium text-gray-700 mb-1">
                Project Title
              </label>
              <input
                ref={titleInputRef}
                id="title"
                type="text"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
                placeholder="Enter project title"
                maxLength={50}
              />
            </div>

            <div>
              <label htmlFor="description" className="block text-sm font-medium text-gray-700 mb-1">
                Description (optional)
              </label>
              <textarea
                id="description"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                className="w-full px-3 py-2 border border-gray-300 rounded-lg shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
                rows={3}
                placeholder="Enter project description"
                maxLength={500}
              />
              <div className="mt-1 text-sm text-gray-500">
                {description.length}/500 characters
              </div>
            </div>

            {error && (
              <div className="text-sm text-red-600 bg-red-50 p-3 rounded-lg">
                {error}
              </div>
            )}
          </div>

          <div className="mt-6 flex justify-end gap-2">
            <button
              type="button"
              onClick={onClose}
              className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-800"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={isLoading}
              className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isLoading ? 'Creating...' : 'Create Project'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}