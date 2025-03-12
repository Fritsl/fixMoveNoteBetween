import React, { useState, useRef, useEffect } from 'react';
import { useNoteStore } from '../store';
import { Edit2 } from 'lucide-react';

export function EditableTitle() {
  const { title, updateTitle } = useNoteStore();
  const [isEditing, setIsEditing] = useState(false);
  const [editedTitle, setEditedTitle] = useState('');
  const [error, setError] = useState<string | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Update local state when title changes
  useEffect(() => {
    setEditedTitle(title);
  }, [title]);

  useEffect(() => {
    if (isEditing && inputRef.current) {
      inputRef.current.focus();
      inputRef.current.select();
    }
  }, [isEditing]);

  const handleSubmit = async () => {
    if (editedTitle.trim()) {
      try {
        await updateTitle(editedTitle);
        setError(null);
      } catch (error) {
        setError(error instanceof Error ? error.message : 'Failed to update title');
        return;
      }
    } else {
      setEditedTitle(title);
    }
    setIsEditing(false);
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      handleSubmit();
    } else if (e.key === 'Escape') {
      setEditedTitle(title);
      setIsEditing(false);
    }
  };

  if (isEditing) {
    return (
      <div className="relative">
      <input
        ref={inputRef}
        type="text"
        value={editedTitle}
        onChange={(e) => setEditedTitle(e.target.value)}
        onBlur={handleSubmit}
        onKeyDown={handleKeyDown}
        className={`text-xl font-semibold text-white bg-transparent border-b-2 ${
          error ? 'border-red-500' : 'border-blue-600'
        } focus:outline-none px-1`}
        maxLength={50}
      />
      {error && (
        <div className="absolute top-full left-0 mt-1 text-sm text-red-500 bg-gray-900 px-2 py-1 rounded">
          {error}
        </div>
      )}
      </div>
    );
  }

  return (
    <button
      onClick={() => setIsEditing(true)}
      className="group flex items-center gap-2"
    >
      <h1 className="text-xl font-semibold text-white">
        {title}
      </h1>
      <Edit2 className="w-4 h-4 text-gray-400 opacity-0 group-hover:opacity-100 transition-opacity hover:text-white" />
    </button>
  );
}