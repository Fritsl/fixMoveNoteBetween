import React from 'react';
import { Plus, Edit2, MoveVertical, Trash2 } from 'lucide-react';

interface NoteActionsProps {
  onEdit: () => void;
  onMove: () => void;
  onAdd: () => void;
  onDelete: () => void;
}

export const NoteActions: React.FC<NoteActionsProps> = ({
  onEdit,
  onMove,
  onAdd,
  onDelete
}) => (
  <div className="flex items-center gap-1">
    <button
      onClick={onEdit}
      className="p-1.5 rounded hover:bg-gray-200 touch-manipulation transition-colors"
    >
      <Edit2 className="w-4 h-4 text-gray-600" />
    </button>
    <button
      onClick={onMove}
      className="p-1.5 rounded hover:bg-gray-200 touch-manipulation transition-colors"
    >
      <MoveVertical className="w-4 h-4 text-gray-600" />
    </button>
    <button
      onClick={onAdd}
      className="p-1.5 rounded hover:bg-gray-200 touch-manipulation transition-colors"
    >
      <Plus className="w-4 h-4 text-gray-600" />
    </button>
    <button
      onClick={onDelete}
      className="p-1.5 rounded hover:bg-gray-200 touch-manipulation transition-colors"
    >
      <Trash2 className="w-4 h-4 text-gray-600" />
    </button>
  </div>
);