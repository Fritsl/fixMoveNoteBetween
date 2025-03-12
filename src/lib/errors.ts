import { PostgrestError } from '@supabase/supabase-js';

export class NoteError extends Error {
  constructor(message: string, public cause?: Error) {
    super(message);
    this.name = 'NoteError';
  }
}

export class ProjectError extends Error {
  constructor(message: string, public cause?: Error) {
    super(message);
    this.name = 'ProjectError';
  }
}

export class DatabaseError extends Error {
  constructor(message: string, public cause?: Error) {
    super(message);
    this.name = 'DatabaseError';
  }
}

export class ValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ValidationError';
  }
}

export const handleError = (error: unknown): Error => {
  if (error instanceof Error) {
    if (error instanceof PostgrestError) {
      return new DatabaseError(error.message, error);
    }
    return error;
  }
  return new Error(error instanceof Object ? JSON.stringify(error) : String(error));
};

export const handleDatabaseError = (error: unknown, context: string): DatabaseError => {
  const baseError = handleError(error);
  return new DatabaseError(`${context}: ${baseError.message}`, baseError);
};

export const handleValidationError = (message: string): ValidationError => {
  return new ValidationError(message);
};

export const isValidationError = (error: unknown): error is ValidationError => {
  return error instanceof ValidationError;
};

export const isDatabaseError = (error: unknown): error is DatabaseError => {
  return error instanceof DatabaseError;
};

export const isNoteError = (error: unknown): error is NoteError => {
  return error instanceof NoteError;
};

export const isProjectError = (error: unknown): error is ProjectError => {
  return error instanceof ProjectError;
};