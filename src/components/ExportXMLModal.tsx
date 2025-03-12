import React from 'react';
import { X, Check } from 'lucide-react';
import { Note } from '../types';

interface ExportXMLModalProps {
  notes: Note[];
  title: string;
  onClose: () => void;
}

const generateXML = (title: string, notes: Note[]): string => {
  const formatNote = (note: Note, indent: number = 2): string => {
    const spaces = ' '.repeat(indent);
    const childNotes = note.children.length > 0
      ? `\n${spaces}  <children>\n${note.children.map(child => formatNote(child, indent + 4)).join('\n')}\n${spaces}  </children>`
      : '';
    
    return `${spaces}<note id="${note.sequence_number || ''}">
${spaces}  <content><![CDATA[${note.content || ''}]]></content>${childNotes}
${spaces}</note>`;
  };

  const notesXML = notes.map(note => formatNote(note)).join('\n');
  
  return `<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="https://aiworkshop.dev/notes/1.0">
  <title><![CDATA[${title}]]></title>
  <notes>
${notesXML}
  </notes>
</project>`;
};

export function ExportXMLModal({ notes, title, onClose }: ExportXMLModalProps) {
  const xml = generateXML(title, notes);

  React.useEffect(() => {
    navigator.clipboard.writeText(xml);
  }, [xml]);

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-4xl max-h-[90vh] flex flex-col">
        <div className="flex items-center justify-between p-4 border-b">
          <div>
            <h2 className="text-lg font-semibold text-gray-900">XML Copied to Clipboard</h2>
            <p className="text-sm text-green-600 mt-1 flex items-center gap-1">
              <Check className="w-4 h-4" />
              XML has been copied to your clipboard
            </p>
          </div>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        <div className="flex-1 p-4 overflow-auto">
          <pre className="font-mono text-sm bg-gray-50 p-4 rounded-lg overflow-x-auto whitespace-pre">
            {xml}
          </pre>
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end gap-2">
          <button
            onClick={() => onClose()}
            className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors flex items-center gap-2"
          >
            OK
          </button>
        </div>
      </div>
    </div>
  );
}