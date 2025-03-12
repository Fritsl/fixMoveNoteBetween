import React, { useState, useEffect } from 'react';
import { X, ArrowUpCircle, ChevronRight, ArrowRight, MapPin } from 'lucide-react';
import { useNoteStore } from '../store';
import { findNoteById } from '../lib/utils';
import { Note } from '../types';
import { findNoteParents } from '../lib/utils';

interface MoveToMenuProps {
  noteId: string;
  onClose: () => void;
}

export const MoveToMenu: React.FC<MoveToMenuProps> = ({ noteId, onClose }) => {
  const { notes, moveNote } = useNoteStore();
  const [selectedParent, setSelectedParent] = useState<string | null>(null);
  const [expandedNodes, setExpandedNodes] = useState<Set<string>>(new Set());
  const [currentParentId, setCurrentParentId] = useState<string | null>(null);
  const [availablePositions, setAvailablePositions] = useState<Note[]>([]);
  const noteToMove = findNoteById(notes, noteId);

  // Helper function to check relationships
  const isDescendant = (parent: Note | null | undefined, childId: string): boolean => {
    if (!parent || !childId) return false;
    return parent.children.some(child => 
      child.id === childId || isDescendant(child, childId)
    );
  };

  const toggleExpanded = (id: string) => {
    setExpandedNodes(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  // Get current location path
  const currentLocation = findNoteParents(notes, noteId);

  // Find the current parent ID
  useEffect(() => {
    const findParentId = (notes: Note[], targetId: string): string | null => {
      for (const note of notes) {
        if (note.children.some(child => child.id === targetId)) {
          return note.id;
        }
        const found = findParentId(note.children, targetId);
        if (found) return found;
      }
      return null;
    };
    const parentId = findParentId(notes, noteId);
    setCurrentParentId(parentId);
  }, [noteId, notes]);

  // Initialize expanded nodes with the path to the current note
  useEffect(() => {
    const currentPath = currentLocation?.map(note => note.id) || [];
    const newExpandedNodes = new Set(currentPath);
    
    // Only update if the expanded nodes have actually changed
    const hasChanges = currentPath.some(id => !expandedNodes.has(id)) ||
      Array.from(expandedNodes).some(id => !currentPath.includes(id));
    
    if (hasChanges) {
      setExpandedNodes(newExpandedNodes);
    }
  }, [noteId]); // Only depend on noteId to prevent unnecessary updates

  const truncatedContent = noteToMove?.content 
    ? noteToMove.content.length > 200 
      ? `${noteToMove.content.substring(0, 200)}...` 
      : noteToMove.content
    : 'Empty note...';

  const renderCurrentLocation = () => {
    if (!currentLocation) {
      return (
        <div className="px-4 py-2 bg-blue-50 border-y border-blue-100">
          <div className="flex items-center gap-2 text-sm text-blue-700">
            <MapPin className="w-4 h-4" />
            <span>Currently at root level</span>
          </div>
        </div>
      );
    }

    return (
      <div className="px-4 py-2 bg-blue-50 border-y border-blue-100">
        <div className="flex items-center gap-2 text-sm text-blue-700">
          <MapPin className="w-4 h-4" />
          <span>Current location:</span>
        </div>
        <div className="mt-1 pl-6 text-sm text-blue-600">
          {currentLocation.map((note) => (
            <div key={note.id} className="flex items-center gap-1">
              <ChevronRight className="w-3 h-3" />
              <span className="truncate">{note.content || 'Empty note...'}</span>
            </div>
          ))}
        </div>
      </div>
    );
  };

  // Collect all valid target notes
  useEffect(() => {
    const collectValidTargets = (notes: Note[], path: Note[] = []): Note[] => {
      let targets: Note[] = [];
      
      for (const note of notes) {
        // Skip if this is the note being moved or its descendants
        if (note.id === noteId || isDescendant(noteToMove!, note.id)) {
          continue;
        }
        
        targets.push(note);
        targets = [...targets, ...collectValidTargets(note.children, [...path, note])];
      }
      
      return targets;
    };
    
    if (noteToMove) {
      const validTargets = collectValidTargets(notes);
      setAvailablePositions(validTargets);
    }
  }, [noteId, notes, noteToMove]);

  const renderNoteOption = (note: Note, level = 0): React.ReactNode => {
    const displayText = note.content || 'Empty note...';
    const truncatedText = displayText.length > 40 
      ? `${displayText.substring(0, 40)}...` 
      : displayText;

    // Skip if this is the note being moved or one of its descendants
    if (note.id === noteId || (noteToMove && isDescendant(noteToMove, note.id))) {
      return null;
    }

    return (
      <React.Fragment key={note.id}>
        <div className="group">
          <div className="flex items-center hover:bg-gray-50 relative">
            {note.children.length > 0 && (
              <button
                onClick={() => toggleExpanded(note.id)}
                className="p-1.5 hover:bg-gray-100 rounded"
                style={{ marginLeft: `${level * 1}rem` }}
              >
                <ChevronRight
                  className={`w-4 h-4 text-gray-400 transition-transform ${
                    expandedNodes.has(note.id) ? 'rotate-90' : ''
                  }`}
                />
              </button>
            )}
            <button
              onClick={() => setSelectedParent(note.id)}
              className={`flex-1 text-left px-4 py-2 flex items-center text-sm text-gray-700 hover:bg-gray-50 ${
                selectedParent === note.id ? 'bg-blue-50' : ''
              }`}
              style={{ marginLeft: note.children.length === 0 ? `${level * 1.5}rem` : 0 }}
            >
              <span className="truncate flex-1">{truncatedText}</span>
              {note.children.length > 0 && (
                <span className="text-xs text-gray-400 mr-2">
                  {note.children.length} {note.children.length === 1 ? 'note' : 'notes'}
                </span>
              )}
              <ArrowRight className={`w-4 h-4 ml-2 transition-opacity ${
                selectedParent === note.id ? 'opacity-100 text-blue-600' : 'opacity-0'
              }`} />
            </button>
          </div>
        </div>
        {selectedParent === note.id && (
          <div className="border-l-2 border-blue-100 ml-6 my-1">
            <div className="pl-4 py-2 text-xs text-gray-500 font-medium">Select position:</div>
            <button
              onClick={() => {
                moveNote(noteId, note.id, 0);
                onClose();
              }}
              className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
            >
              <span>At the beginning</span>
            </button>
            {note.children.map((child, index) => (
              <button
                key={index + 1}
                onClick={() => {
                  moveNote(noteId, note.id, index + 1);
                  onClose();
                }}
                className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
              >
                <span>After {child.content || 'Empty note...'}</span>
              </button>
            ))}
          </div>
        )}
        {expandedNodes.has(note.id) && note.children.map(child => renderNoteOption(child, level + 1))}
      </React.Fragment>
    );
  };

  return (
    <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4">
      <div className="bg-white rounded-lg shadow-xl w-full max-w-2xl">
        <div className="flex items-center justify-between px-4 py-3 border-b">
          <div className="pr-8">
            <h2 className="text-lg font-semibold text-gray-900">Move note</h2>
            <p className="text-sm text-gray-600 mt-1 line-clamp-2">{truncatedContent}</p>
          </div>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 rounded-full transition-colors"
          >
            <X className="w-5 h-5 text-gray-500" />
          </button>
        </div>
        {renderCurrentLocation()}
        <div className="max-h-[60vh] overflow-y-auto">
          <button
            onClick={() => {
              if (selectedParent === null) {
                setSelectedParent(undefined); // Deselect root level
              } else {
                setSelectedParent(null); // Select root level
              }
            }}
            className={`w-full text-left px-4 py-2 hover:bg-gray-100 flex items-center gap-2 text-sm text-gray-700 font-medium ${
              selectedParent === null ? 'bg-blue-50' : ''
            }`}
          >
            <ArrowUpCircle className="w-4 h-4" />
            <span className="flex-1">Root level</span>
            <ArrowRight className={`w-4 h-4 transition-opacity ${
              selectedParent === null ? 'opacity-100 text-blue-600' : 'opacity-0'
            }`} />
          </button>
          {selectedParent === null && (
            <div className="border-l-2 border-blue-100 ml-6 my-1">
              <div className="pl-4 py-2 text-xs text-gray-500 font-medium">Select position:</div>
              <button
                onClick={() => {
                  moveNote(noteId, null, 0);
                  onClose();
                }}
                className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
              >
                <span>At the beginning</span>
              </button>
              {notes.map((note, index) => (
                <button
                  key={index + 1}
                  onClick={() => {
                    moveNote(noteId, null, index + 1);
                    onClose();
                  }}
                  className="w-full text-left px-4 py-2 hover:bg-blue-50 text-sm text-blue-700 flex items-center gap-2"
                >
                  <span>After {note.content || 'Empty note...'}</span>
                </button>
              ))}
            </div>
          )}
          <div className="py-1">
            {notes.map(note => renderNoteOption(note))}
          </div>
        </div>
        <div className="p-4 border-t bg-gray-50 flex justify-end">
          <button
            onClick={onClose}
            className="px-4 py-2 text-gray-600 hover:text-gray-800"
          >
            Cancel
          </button>
        </div>
      </div>
    </div>
  );
};