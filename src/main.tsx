import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.tsx';
import { ErrorBoundary } from './components/ErrorBoundary';
import './index.css';
import { checkSupabaseConnection } from './debug';

// Check Supabase connection on app start
checkSupabaseConnection().catch(err => {
  console.error('Failed during Supabase connection check:', err);
});

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>
);