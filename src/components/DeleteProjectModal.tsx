import React from 'react';
import { AlertTriangle, X } from 'lucide-react';

interface DeleteProjectModalProps {
  projectTitle: string;
  onConfirm: () => void;
  onCancel: () => void;
}

export function DeleteProjectModal({ projectTitle, onConfirm, onCancel }: DeleteProjectModalProps) {
  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Delete Project</h2>
          <button
            onClick={onCancel}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="p-4">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-full bg-red-100 flex items-center justify-center flex-shrink-0">
              <AlertTriangle className="w-5 h-5 text-red-600" />
            </div>
            <div>
              <h3 className="font-medium text-gray-900">Are you absolutely sure?</h3>
              <p className="text-sm text-gray-600 mt-1">
                This will permanently delete <span className="font-medium">"{projectTitle}"</span> and all of its notes.
                This action cannot be undone.
              </p>
            </div>
          </div>
        </div>
        <div className="px-4 py-3 bg-gray-50 flex justify-end gap-2 rounded-b-lg">
          <button
            onClick={onCancel}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-800"
          >
            Cancel
          </button>
          <button
            onClick={onConfirm}
            className="px-4 py-2 text-sm font-medium text-white bg-red-600 rounded-lg hover:bg-red-700 transition-colors"
          >
            Delete Project
          </button>
        </div>
      </div>
    </div>
  );
}