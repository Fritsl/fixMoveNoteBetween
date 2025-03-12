import React, { useState } from 'react';
import { X, Upload } from 'lucide-react';
import { useNoteStore } from '../store';

interface ImportNotesModalProps {
  onClose: () => void;
}

export function ImportNotesModal({ onClose }: ImportNotesModalProps) {
  const [text, setText] = useState('');
  const [isImporting, setIsImporting] = useState(false);
  const { importNotes } = useNoteStore();

  const handleImport = async () => {
    try {
      setIsImporting(true);
      await importNotes(text);
      onClose();
    } catch (error) {
      console.error('Error importing notes:', error);
      alert('Failed to import notes. Please check the format and try again.');
    } finally {
      setIsImporting(false);
    }
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b">
          <h2 className="text-lg font-semibold text-gray-900">Import Notes</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="p-4">
          <p className="text-sm text-gray-600 mb-4">
            Paste your notes below. Each line should start with bullets (•) and use spaces for indentation to indicate hierarchy.
          </p>
          <textarea
            value={text}
            onChange={(e) => setText(e.target.value)}
            className="w-full h-96 font-mono text-sm p-4 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
            placeholder="• Main note
  • Sub-note
    • Sub-sub-note
• Another main note"
          />
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end gap-2">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 hover:text-gray-800"
          >
            Cancel
          </button>
          <button
            onClick={handleImport}
            disabled={!text.trim() || isImporting}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed flex items-center gap-2"
          >
            <Upload className="w-4 h-4" />
            {isImporting ? 'Importing...' : 'Import Notes'}
          </button>
        </div>
      </div>
    </div>
  );
}