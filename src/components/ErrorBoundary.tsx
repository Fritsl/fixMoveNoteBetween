
import React, { Component, ErrorInfo, ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  };

  // Handle synchronous errors
  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidMount(): void {
    // Handle Promise rejection errors
    window.addEventListener('unhandledrejection', this.handlePromiseRejection);
  }

  public componentWillUnmount(): void {
    window.removeEventListener('unhandledrejection', this.handlePromiseRejection);
  }

  private handlePromiseRejection = (event: PromiseRejectionEvent): void => {
    console.error('Unhandled Promise rejection:', event.reason);
    this.setState({
      hasError: true,
      error: event.reason instanceof Error ? event.reason : new Error(String(event.reason)),
    });
  };

  public componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    console.error('Uncaught error:', error, errorInfo);
  }

  public render(): ReactNode {
    if (this.state.hasError) {
      return (
        <div className="p-4 m-4 bg-red-100 border border-red-400 text-red-700 rounded">
          <h2 className="text-xl font-bold mb-2">Something went wrong</h2>
          <details className="whitespace-pre-wrap">
            <summary className="cursor-pointer">Error details</summary>
            <p className="mt-2">{this.state.error?.message}</p>
            <pre className="mt-2 text-sm overflow-auto bg-red-50 p-2 rounded">
              {this.state.error?.stack}
            </pre>
          </details>
        </div>
      );
    }

    return this.props.children;
  }
}
