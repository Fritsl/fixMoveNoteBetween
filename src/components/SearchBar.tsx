import React, { useState, useRef, useEffect } from 'react';
import { Search, X } from 'lucide-react';
import { Note } from '../types';
import { useNoteStore } from '../store';
import { findNoteParents, calculateNoteLevel } from '../lib/utils';

interface SearchResult {
  note: Note;
  path: string[];
  level: number;
}

export function SearchBar() {
  const [isOpen, setIsOpen] = useState(false);
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResult[]>([]);
  const { notes, expandedNotes, setCurrentLevel } = useNoteStore();
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  const searchNotes = (notes: Note[], currentPath: string[] = []): SearchResult[] => {
    let results: SearchResult[] = [];
    
    for (const note of notes) {
      const content = note.content?.toLowerCase() || '';
      if (content.includes(query.toLowerCase())) {
        results.push({
          note,
          path: currentPath,
          level: currentPath.length
        });
      }
      
      if (note.children.length > 0) {
        results = [
          ...results,
          ...searchNotes(note.children, [...currentPath, note.content || 'Empty note...'])
        ];
      }
    }
    
    return results;
  };

  useEffect(() => {
    if (query.trim()) {
      const searchResults = searchNotes(notes);
      setResults(searchResults);
    } else {
      setResults([]);
    }
  }, [query, notes]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Escape') {
      setIsOpen(false);
      setQuery('');
    }
  };

  return (
    <div className="relative">
      <button
        onClick={() => {
          setIsOpen(true);
          if (inputRef.current) {
            setTimeout(() => inputRef.current?.focus(), 100);
          }
        }}
        className="p-2 hover:bg-gray-800 rounded-lg transition-colors text-white"
        aria-label="Search"
      >
        <Search className="w-5 h-5" />
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-96 bg-white rounded-lg shadow-lg z-50">
          <div className="p-2 border-b">
            <div className="relative">
              <input
                ref={inputRef}
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                onKeyDown={handleKeyDown}
                placeholder="Search notes..."
                className="w-full pl-10 pr-4 py-2 bg-gray-50 border border-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
              />
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              {query && (
                <button
                  onClick={() => setQuery('')}
                  className="absolute right-3 top-1/2 transform -translate-y-1/2 p-1 hover:bg-gray-200 rounded-full"
                >
                  <X className="w-3 h-3 text-gray-500" />
                </button>
              )}
            </div>
          </div>

          <div className="max-h-96 overflow-y-auto">
            {results.length > 0 ? (
              <div className="py-2">
                {results.map((result, index) => (
                  <div
                    key={`${result.note.id}-${index}`}
                    className="px-4 py-2 hover:bg-gray-50 cursor-pointer"
                    onClick={() => {
                      // Find all parent notes that need to be expanded
                      const parents = findNoteParents(notes, result.note.id);
                      if (parents) {
                        // Add all parent IDs to expandedNotes to make the path visible
                        parents.forEach(parent => {
                          expandedNotes.add(parent.id);
                        });
                        
                        // Instantly update the zoom level to match the note's depth
                        setCurrentLevel(result.level);
                      }
                      
                      // Close search and scroll to the note
                      setIsOpen(false);
                      setQuery('');
                      
                      // Use requestAnimationFrame to ensure the note is rendered before scrolling
                      requestAnimationFrame(() => {
                        const element = document.getElementById(result.note.id);
                        if (element) {
                          element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                          element.classList.add('highlight-note');
                          setTimeout(() => {
                            element.classList.remove('highlight-note');
                          }, 2000);
                        }
                      });
                    }}
                  >
                    <div className="font-medium text-gray-900 mb-1">
                      {result.note.content || 'Empty note...'}
                    </div>
                    {result.path.length > 0 && (
                      <div className="text-sm text-gray-500 flex items-center gap-1">
                        {result.path.map((step, i) => (
                          <React.Fragment key={i}>
                            {i > 0 && <span className="text-gray-300">›</span>}
                            <span className="truncate max-w-[150px]">{step}</span>
                          </React.Fragment>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            ) : query ? (
              <div className="px-4 py-8 text-center text-gray-500">
                No results found for "{query}"
              </div>
            ) : null}
          </div>
        </div>
      )}
    </div>
  );
}