import React, { useState } from 'react';
import { Note as NoteType } from '../types';
import { useNoteStore } from '../store';
import { FullscreenEditor } from './FullscreenEditor';
import { MoveToMenu } from './MoveToMenu';
import { DeleteNoteModal } from './DeleteNoteModal';
import { NoteContent } from './NoteContent';
import { NoteActions } from './NoteActions';

const getLevelColor = (level: number = 0): string => {
  const colors = [
    'bg-white hover:bg-gray-50',           // Level 0
    'bg-purple-50 hover:bg-purple-100',    // Level 1
    'bg-blue-50 hover:bg-blue-100',        // Level 2
    'bg-green-50 hover:bg-green-100',      // Level 3
    'bg-amber-50 hover:bg-amber-100',      // Level 4
    'bg-rose-50 hover:bg-rose-100',        // Level 5
  ];
  return colors[Math.min(level, colors.length - 1)];
};

interface NoteProps {
  note: NoteType;
  parentId: string | null;
  level?: number;
}

export const Note: React.FC<NoteProps> = ({ note, parentId, level = 0 }) => {
  const { updateNote, toggleEdit, addNote, saveNote, setEditMode, deleteNote, expandedNotes } = useNoteStore();
  const [isSelected, setIsSelected] = useState(false);
  const [isMoveMenuOpen, setIsMoveMenuOpen] = useState(false);
  const [showDeleteModal, setShowDeleteModal] = useState(false);

  React.useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (isSelected && !e.defaultPrevented) {
        setIsSelected(false);
      }
    };
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, [isSelected]);

  return (
    <div className="group relative" id={note.id}>
      <div
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          setIsSelected(true);
        }}
        className={`flex items-start gap-2 p-3 rounded-lg shadow-sm hover:shadow-md transition-all ${getLevelColor(level)} ${isSelected ? 'ring-2 ring-blue-500' : ''}`}
      >
        <div className="w-full">
          <div className="flex flex-col gap-2">
            {note.isEditing ? (
              <FullscreenEditor
                content={note.unsavedContent ?? note.content}
                sequenceNumber={note.sequence_number}
                isNew={!note.content}
                note={note}
                onChange={(content) => updateNote(note.id, content)}
                onClose={() => {
                  setEditMode(false);
                  saveNote(note.id);
                  toggleEdit(note.id);
                }}
              />
            ) : (
              <div className="flex-1">
                <div className="flex flex-col gap-2">
                  <NoteContent note={note} level={level} />
                  <div className={`flex items-center gap-1 ${isSelected || note.isEditing ? 'opacity-100' : 'opacity-0 group-hover:opacity-100'} transition-opacity`}>
                    <NoteActions
                      onEdit={() => {
                        setEditMode(true);
                        toggleEdit(note.id);
                        setIsSelected(false);
                      }}
                      onMove={() => {
                        setIsMoveMenuOpen(true);
                        setIsSelected(false);
                      }}
                      onAdd={() => {
                        addNote(note.id);
                        setIsSelected(false);
                      }}
                      onDelete={() => {
                        setShowDeleteModal(true);
                        setIsSelected(false);
                      }}
                    />
                  </div>
                </div>
              </div>
            )}
          </div>

          {note.children.length > 0 && expandedNotes.has(note.id) && (
            <div className="pl-4 mt-3 space-y-3 border-l-2 border-gray-200">
              {note.children.map((child) => (
                <Note 
                  key={child.id} 
                  note={child} 
                  parentId={note.id} 
                  level={Math.min(level + 1, 4)} 
                />
              ))}
            </div>
          )}
        </div>
      </div>

      {isMoveMenuOpen && (
        <MoveToMenu
          noteId={note.id}
          onClose={() => setIsMoveMenuOpen(false)}
        />
      )}

      {showDeleteModal && (
        <DeleteNoteModal
          noteContent={note.content}
          note={note}
          onConfirm={async () => {
            await deleteNote(note.id);
            setShowDeleteModal(false);
          }}
          onCancel={() => setShowDeleteModal(false)}
        />
      )}
    </div>
  );
};