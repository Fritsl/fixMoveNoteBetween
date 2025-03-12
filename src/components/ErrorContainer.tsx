import React from 'react';
import { ErrorMessage } from './ErrorMessage';

interface ErrorContainerProps {
  error: Error | null;
  onDismiss?: () => void;
  className?: string;
}

export const ErrorContainer: React.FC<ErrorContainerProps> = ({ 
  error, 
  onDismiss,
  className = ''
}) => {
  if (!error) return null;

  return (
    <div className={`fixed bottom-4 right-4 z-50 max-w-md ${className}`}>
      <ErrorMessage 
        error={error} 
        onDismiss={onDismiss} 
      />
    </div>
  );
}