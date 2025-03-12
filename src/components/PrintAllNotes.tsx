import React from 'react';
import { X } from 'lucide-react';
import { Note } from '../types';
import { useState, useEffect } from 'react';
import { formatNotesAsText } from '../lib/utils';

interface PrintAllNotesProps {
  notes: Note[];
  onClose: () => void;
}

export const PrintAllNotes: React.FC<PrintAllNotesProps> = ({ notes, onClose }) => {
  const [editableText, setEditableText] = useState(formatNotesAsText(notes));

  useEffect(() => {
    setEditableText(formatNotesAsText(notes));
  }, [notes]);

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Edit Notes</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="flex-1 p-4 overflow-auto">
          <textarea
            value={editableText}
            onChange={(e) => setEditableText(e.target.value)}
            className="w-full h-full min-h-[400px] font-mono text-sm text-gray-700 p-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent resize-none"
            spellCheck={false}
          />
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end">
          <button
            onClick={() => {
              navigator.clipboard.writeText(editableText);
              alert('Notes copied to clipboard!');
            }}
            className="px-4 py-2 text-gray-600 hover:text-gray-800 mr-2"
          >
            Copy to Clipboard
          </button>
          <button
            onClick={onClose}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
};