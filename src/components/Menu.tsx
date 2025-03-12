import React, { useState, useRef, useEffect } from 'react';
import { Menu as MenuIcon, LogOut, Printer, FolderPlus, Folder, Trash2, Copy, FileDown, Files, Loader2, FileText, ExternalLink } from 'lucide-react';
import { useNoteStore } from '../store';
import { supabase } from '../lib/supabase';

import { DeleteProjectModal } from './DeleteProjectModal';
import { NewProjectModal } from './NewProjectModal';
import { PrintAllNotes } from './PrintAllNotes';
import { ExportXMLModal } from './ExportXMLModal';

interface MenuProps {
  onSignOut: () => void;
}

export function Menu({ onSignOut }: MenuProps) {
  const { loadProjects, projects, title, copyProject, deleteProject, switchProject, printNotes } = useNoteStore();
  const [isOpen, setIsOpen] = useState(false);
  const [isPrintModalOpen, setIsPrintModalOpen] = useState(false);
  const [showProjectsMenu, setShowProjectsMenu] = useState(false);
  const [projectToDelete, setProjectToDelete] = useState<{ id: string; title: string } | null>(null);
  const menuRef = useRef<HTMLDivElement>(null);
  const [showExportModal, setShowExportModal] = useState(false);
  const [showNewProjectModal, setShowNewProjectModal] = useState(false);
  const projectsMenuRef = useRef<HTMLDivElement>(null);
  const [isLoadingProjects, setIsLoadingProjects] = useState(false);
  const [isDuplicating, setIsDuplicating] = useState(false);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (menuRef.current && !menuRef.current.contains(event.target as Node)) {
        if (!projectsMenuRef.current?.contains(event.target as Node)) {
          setIsOpen(false);
          setShowProjectsMenu(false);
        }
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [projectsMenuRef]);

  const handleShowProjects = async () => {
    setIsLoadingProjects(true);
    setShowProjectsMenu(true);
    await loadProjects();
    setIsLoadingProjects(false);
  };

  const handleDuplicateProject = async () => {
    const urlParams = new URLSearchParams(window.location.search);
    const currentProjectId = urlParams.get('project');
    if (!currentProjectId) return;

    setIsDuplicating(true);
    try {
      await copyProject(currentProjectId);
      setIsOpen(false);
    } catch (error) {
      console.error('Failed to duplicate project:', error);
      alert('Failed to duplicate project. Please try again.');
    } finally {
      setIsDuplicating(false);
    }
  };

  const handleDeleteConfirm = async () => {
    if (!projectToDelete) return;
    try {
      await deleteProject(projectToDelete.id);
      setProjectToDelete(null);
      setShowProjectsMenu(false);
    } catch (error) {
      console.error('Failed to delete project:', error);
      alert('Failed to delete project. Please try again.');
    }
  };

  const handleCopyProject = async (projectId: string) => {
    await copyProject(projectId);
    setShowProjectsMenu(false);
  };

  return (
    <div className="relative" ref={menuRef}>
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="p-2 hover:bg-gray-800 rounded-lg transition-colors text-white"
        aria-label="Menu"
      >
        <MenuIcon className="w-5 h-5" />
      </button>

      {isOpen && (
        <div className="absolute right-0 mt-2 w-48 bg-white rounded-lg shadow-lg py-1 z-50">
          <button
            onClick={handleShowProjects}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <Folder className="w-4 h-4" />
            <span>Projects</span>
          </button>
          <button
            onClick={handleDuplicateProject}
            disabled={isDuplicating}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isDuplicating ? (
              <>
                <Loader2 className="w-4 h-4 animate-spin" />
                <span>Duplicating...</span>
              </>
            ) : (
              <>
                <Files className="w-4 h-4" />
                <span>Duplicate Project</span>
              </>
            )}
          </button>
          <button
            onClick={() => {
              setShowNewProjectModal(true);
              setIsOpen(false);
            }}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <FolderPlus className="w-4 h-4" />
            <span>New Project</span>
          </button>
          <a
            href="https://presenterviewer.netlify.app"
            target="_blank"
            rel="noopener noreferrer"
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <ExternalLink className="w-4 h-4" />
            <span>Viewer</span>
          </a>
          <button
            onClick={() => {
              const text = printNotes();
              try {
                navigator.clipboard.writeText(text);
                alert('Notes copied to clipboard!');
              } catch (error) {
                console.error('Failed to copy notes:', error);
                alert('Failed to copy notes to clipboard. Please try again.');
              }
              setIsOpen(false);
            }}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <FileText className="w-4 h-4" />
            <span>Copy visible as Text</span>
          </button>
          <button
            onClick={() => {
              setIsPrintModalOpen(true);
              setIsOpen(false);
            }}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <Printer className="w-4 h-4" />
            <span>Print all on screen</span>
          </button>
          <button
            onClick={() => {
              setShowExportModal(true);
              setIsOpen(false);
            }}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <FileDown className="w-4 h-4" />
            <span>Export as XML</span>
          </button>
          <button
            onClick={() => {
              setIsOpen(false);
              onSignOut();
            }}
            className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 transition-colors"
          >
            <LogOut className="w-4 h-4" />
            <span>Sign out</span>
          </button>
        </div>
      )}
      
      {showProjectsMenu && (
        <div 
          ref={projectsMenuRef}
          className="absolute right-0 mt-2 w-[480px] bg-white rounded-lg shadow-lg py-1 z-50"
        >
          <div className="px-4 py-2 border-b border-gray-100">
            <h3 className="font-medium text-gray-900">Your Projects</h3>
          </div>
          <div className="max-h-[400px] overflow-y-auto min-h-[100px] relative">
            {isLoadingProjects ? (
              <div className="absolute inset-0 flex items-center justify-center">
                <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-blue-600"></div>
              </div>
            ) : projects.map((project) => (
              <div
                key={project.id}
                className={`flex items-center justify-between px-4 py-2 hover:bg-gray-50 ${
                  project.title === title ? 'bg-blue-50' : ''
                }`}
              >
                <div className="flex-1">
                  <div className="flex items-center justify-between">
                    <button
                      onClick={async () => {
                        await switchProject(project.id);
                        setShowProjectsMenu(false);
                        setIsOpen(false);
                      }}
                      className="text-left text-sm text-gray-700 font-medium hover:text-gray-900"
                    >
                      {project.title}
                    </button>
                    <div className="flex items-center gap-1">
                      <button
                        onClick={() => handleCopyProject(project.id)}
                        className="p-1 hover:bg-gray-200 rounded group"
                        title="Copy project"
                      >
                        <Copy className="w-4 h-4 text-gray-400 group-hover:text-blue-600" />
                      </button>
                      <button
                        onClick={() => setProjectToDelete({ id: project.id, title: project.title })}
                        className="p-1 hover:bg-gray-200 rounded group"
                        title="Delete project"
                      >
                        <Trash2 className="w-4 h-4 text-gray-400 group-hover:text-red-600" />
                      </button>
                    </div>
                  </div>
                  <div className="mt-2 grid grid-cols-3 gap-2 text-xs">
                    <div className="px-2 py-1 bg-gray-50 rounded">
                      <span className="text-gray-500">Notes:</span>
                      <span className="ml-1 text-gray-900 font-medium">{project.note_count}</span>
                    </div>
                    <div className="px-2 py-1 bg-gray-50 rounded">
                      <span className="text-gray-500">Modified:</span>
                      <span className="ml-1 text-gray-900 font-medium">
                        {project.last_modified_at
                          ? new Date(project.last_modified_at).toLocaleDateString()
                          : 'Never'}
                      </span>
                    </div>
                    <div className="px-2 py-1 bg-gray-50 rounded">
                      <span className="text-gray-500">Created:</span>
                      <span className="ml-1 text-gray-900 font-medium">
                        {project.created_at
                          ? new Date(project.created_at).toLocaleDateString()
                          : 'Unknown'}
                      </span>
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
      
      {isPrintModalOpen && (
        <PrintAllNotes
          notes={notes}
          onClose={() => setIsPrintModalOpen(false)}
        />
      )}
      
      {showExportModal && (
        <ExportXMLModal
          notes={notes}
          title={title}
          onClose={() => setShowExportModal(false)}
        />
      )}
      
      {projectToDelete && (
        <DeleteProjectModal
          projectTitle={projectToDelete.title}
          onConfirm={handleDeleteConfirm}
          onCancel={() => setProjectToDelete(null)}
        />
      )}
      
      {showNewProjectModal && (
        <NewProjectModal
          onClose={() => setShowNewProjectModal(false)}
          onSuccess={async (projectId) => {
            const newUrl = new URL(window.location.href);
            newUrl.searchParams.set('project', projectId);
            window.history.replaceState({}, '', newUrl.toString());
            await switchProject(projectId);
            setShowNewProjectModal(false);
          }}
        />
      )}
    </div>
  );
}