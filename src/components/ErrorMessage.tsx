import React from 'react';
import { AlertTriangle, XCircle, AlertCircle, X } from 'lucide-react';
import { ValidationError, DatabaseError, NoteError, ProjectError } from '../lib/errors';

interface ErrorMessageProps {
  error: Error;
  onDismiss?: () => void;
  className?: string;
}

export const ErrorMessage: React.FC<ErrorMessageProps> = ({ error, onDismiss, className = '' }) => {
  const getErrorConfig = () => {
    if (error instanceof ValidationError) {
      return {
        Icon: AlertCircle,
        bgColor: 'bg-yellow-50',
        borderColor: 'border-yellow-200',
        textColor: 'text-yellow-800',
        iconColor: 'text-yellow-400',
        hoverColor: 'hover:bg-yellow-100'
      };
    }
    if (error instanceof DatabaseError) {
      return {
        Icon: XCircle,
        bgColor: 'bg-red-50',
        borderColor: 'border-red-200',
        textColor: 'text-red-800',
        iconColor: 'text-red-400',
        hoverColor: 'hover:bg-red-100'
      };
    }
    if (error instanceof NoteError) {
      return {
        Icon: AlertTriangle,
        bgColor: 'bg-orange-50',
        borderColor: 'border-orange-200',
        textColor: 'text-orange-800',
        iconColor: 'text-orange-400',
        hoverColor: 'hover:bg-orange-100'
      };
    }
    if (error instanceof ProjectError) {
      return {
        Icon: AlertTriangle,
        bgColor: 'bg-blue-50',
        borderColor: 'border-blue-200',
        textColor: 'text-blue-800',
        iconColor: 'text-blue-400',
        hoverColor: 'hover:bg-blue-100'
      };
    }
    return {
      Icon: AlertTriangle,
      bgColor: 'bg-gray-50',
      borderColor: 'border-gray-200',
      textColor: 'text-gray-800',
      iconColor: 'text-gray-400',
      hoverColor: 'hover:bg-gray-100'
    };
  };

  const config = getErrorConfig();

  return (
    <div className={`${config.bgColor} border ${config.borderColor} rounded-lg p-4 ${className}`}>
      <div className="flex items-start">
        <div className="flex-shrink-0">
          <config.Icon className={`w-5 h-5 ${config.iconColor}`} />
        </div>
        <div className="ml-3 flex-1">
          <h3 className={`text-sm font-medium ${config.textColor}`}>
            {error.name}
          </h3>
          <div className={`mt-2 text-sm ${config.textColor}`}>
            {error.message}
          </div>
          {error.cause && (
            <div className="mt-1 text-sm opacity-75">
              {error.cause.message}
            </div>
          )}
        </div>
        {onDismiss && (
          <button
            onClick={onDismiss}
            className={`ml-4 ${config.iconColor} ${config.hoverColor} rounded-full p-1 transition-colors`}
          >
            <span className="sr-only">Dismiss</span>
            <X className="h-5 w-5" />
          </button>
        )}
      </div>
    </div>
  );
};