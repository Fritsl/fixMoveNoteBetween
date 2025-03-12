import { useState, useCallback } from 'react';
import { 
  ValidationError, 
  DatabaseError, 
  NoteError, 
  ProjectError,
  isValidationError,
  isDatabaseError,
  isNoteError,
  isProjectError
} from '../lib/errors';

export function useErrorHandler() {
  const [error, setError] = useState<Error | null>(null);

  const handleError = useCallback((error: unknown) => {
    if (isValidationError(error)) {
      setError(error);
      setTimeout(() => setError(null), 5000); // Auto-dismiss validation errors
    } else if (isDatabaseError(error) || isNoteError(error) || isProjectError(error)) {
      setError(error);
    } else if (error instanceof Error) {
      setError(error);
    } else {
      setError(new Error('An unexpected error occurred'));
    }
  }, []);

  const clearError = useCallback(() => {
    setError(null);
  }, []);

  return {
    error,
    handleError,
    clearError
  };
}