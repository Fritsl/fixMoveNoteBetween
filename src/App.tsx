import React from 'react';
import { Plus, Sparkles, Check, FolderOpen, FolderClosed } from 'lucide-react';
import { useNoteStore } from './store';
import { useAuth } from './hooks/useAuth';
import { useErrorHandler } from './hooks/useErrorHandler';
import { Note } from './components/Note';
import { AuthForm } from './components/AuthForm';
import { EditableTitle } from './components/EditableTitle';
import { Menu } from './components/Menu';
import { SearchBar } from './components/SearchBar';
import { ErrorContainer } from './components/ErrorContainer';

const useUndoKeyboard = () => {
  const { undo, canUndo } = useNoteStore();

  React.useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'z' && !e.shiftKey && canUndo) {
        e.preventDefault();
        undo();
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [undo, canUndo]);
};

function App() {
  const { 
    notes, 
    title, 
    loadNotes, 
    addNote, 
    isEditMode, 
    setEditMode, 
    expandOneLevel, 
    collapseOneLevel,
    canExpandMore,
    canCollapseMore,
    currentLevel,
  } = useNoteStore();
  const { isLoading, error: authError, user, signOut } = useAuth();
  const { error, handleError, clearError } = useErrorHandler();
  useUndoKeyboard();

  React.useEffect(() => {
    if (!isLoading && !authError) {
      loadNotes().catch(handleError);
    }
  }, [isLoading, authError, loadNotes, handleError]);

  // Initialize expand/collapse state when notes are loaded
  React.useEffect(() => {
    if (notes.length > 0) {
      expandOneLevel();
    }
  }, [notes, expandOneLevel]);

  if (!user) {
    return <AuthForm />;
  }

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-bounce mb-4">
            <Sparkles className="w-12 h-12 text-blue-600" />
          </div>
          <h2 className="text-xl font-semibold text-gray-700 mb-2">Loading your workspace</h2>
          <p className="text-gray-500">Preparing your notes and projects...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-b from-gray-50 to-white">
      <header className="bg-gray-900 shadow-lg sticky top-0 z-10">
        <div className="max-w-5xl mx-auto px-4 py-4 flex items-center justify-between">
          <EditableTitle onError={handleError} />
          <div className="flex items-center gap-4">
            <SearchBar />
            <div className="flex items-center gap-2">
              <button
                onClick={collapseOneLevel}
                className={`p-2 rounded-lg transition-colors relative ${
                  canCollapseMore ? 'hover:bg-gray-800 text-white' : 'text-gray-500 cursor-not-allowed'
                }`}
                disabled={!canCollapseMore}
                title="Collapse notes"
              >
                <FolderClosed className="w-5 h-5" />
              </button>
              <div className="w-6 h-6 flex items-center justify-center text-sm font-medium text-white bg-gray-800 rounded-lg">
                {currentLevel}
              </div>
              <button
                onClick={expandOneLevel}
                className={`p-2 rounded-lg transition-colors relative ${
                  canExpandMore ? 'hover:bg-gray-800 text-white' : 'text-gray-500 cursor-not-allowed'
                }`}
                disabled={!canExpandMore}
                title="Expand notes"
              >
                <FolderOpen className="w-5 h-5" />
              </button>
            </div>
            <Menu onSignOut={signOut} onError={handleError} />
          </div>
        </div>
      </header>

      <main className="max-w-5xl mx-auto px-4 py-8">
        <div className="space-y-4">
          {notes.map(note => (
            <Note 
              key={note.id} 
              note={note} 
              parentId={null} 
              level={0}
              onError={handleError}
            />
          ))}
          {notes.length === 0 && (
            <div className="text-center py-16">
              <div className="mb-4">
                <Sparkles className="w-16 h-16 text-blue-600 mx-auto mb-4" />
                <h2 className="text-2xl font-semibold text-gray-900 mb-2">Welcome to Your Workspace</h2>
                <p className="text-gray-600 max-w-md mx-auto">
                  Start organizing your thoughts by adding your first note. Click the + button below to begin.
                </p>
              </div>
            </div>
          )}
        </div>
        <button
          onClick={() => addNote(null).catch(handleError)}
          className={`fixed bottom-8 right-8 w-14 h-14 ${
            isEditMode ? 'bg-green-600 hover:bg-green-700' : 'bg-blue-600 hover:bg-blue-700'
          } text-white rounded-full shadow-xl hover:shadow-blue-200 flex items-center justify-center transition-all transform hover:scale-110`}
          aria-label={isEditMode ? "Done editing" : "Add new note"}
        >
          {isEditMode ? (
            <Check className="w-6 h-6" />
          ) : (
            <Plus className="w-6 h-6" />
          )}
        </button>
      </main>

      <ErrorContainer 
        error={error} 
        onDismiss={clearError}
      />
    </div>
  );
}

export default App;