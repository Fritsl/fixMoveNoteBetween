import React from 'react';
import { AlertTriangle, X } from 'lucide-react';
import { Note } from '../types';

interface DeleteNoteModalProps {
  noteContent: string;
  note: Note;
  onConfirm: () => void;
  onCancel: () => void;
}

export function DeleteNoteModal({ noteContent, note, onConfirm, onCancel }: DeleteNoteModalProps) {
  const truncatedContent = noteContent.length > 100 
    ? `${noteContent.substring(0, 100)}...` 
    : noteContent || 'Empty note';

  const countChildren = (note: Note): number => {
    let count = 0;
    for (const child of note.children) {
      count += 1 + countChildren(child);
    }
    return count;
  };

  const childCount = countChildren(note);

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-md">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Delete "{truncatedContent}"</h2>
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
                This will permanently delete this note{childCount > 0 ? ` and ${childCount} sub-note${childCount === 1 ? '' : 's'}` : ''}.
              </p>
              {childCount > 0 && (
                <div className="mt-3 bg-gray-50 p-3 rounded-lg">
                  <p className="text-sm font-medium text-gray-700 mb-2">Sub-notes that will be deleted:</p>
                  <ul className="text-sm text-gray-600 space-y-1 ml-4 list-disc">
                    {note.children.map((child, index) => (
                      <li key={child.id}>
                        {child.content || 'Empty note'}
                        {child.children.length > 0 && (
                          <span className="text-gray-400">
                            {` (and ${countChildren(child)} sub-note${countChildren(child) === 1 ? '' : 's'})`}
                          </span>
                        )}
                      </li>
                    ))}
                  </ul>
                </div>
              )}
              <p className="text-sm text-red-600 mt-3">
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
            Delete Note
          </button>
        </div>
      </div>
    </div>
  );
}