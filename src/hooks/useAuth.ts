import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { User, AuthError } from '@supabase/supabase-js';

export function useAuth() {
  const [isLoading, setIsLoading] = useState(true);
  const [user, setUser] = useState<User | null>(null);
  const [error, setError] = useState<AuthError | null>(null);

  useEffect(() => {
    let mounted = true;

    const initializeAuth = async () => {
      try {
        // First check for existing session
        const { data: { session }, error: sessionError } = await supabase.auth.getSession();
        
        if (sessionError) throw sessionError;
        
        if (mounted) {
          setUser(session?.user ?? null);
          setError(null);
        }
      } catch (err) {
        if (mounted) {
          setError(err instanceof AuthError ? err : new AuthError('Authentication failed'));
          setUser(null);
        }
      } finally {
        if (mounted) {
          setIsLoading(false);
        }
      }
    };

    // Initialize auth state
    initializeAuth();

    // Listen for auth changes
    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (event, session) => {
      if (mounted) {
        setUser(session?.user ?? null);
        setError(null);
        setIsLoading(false);
      }
    });

    return () => {
      subscription.unsubscribe();
      mounted = false;
    };
  }, []);

  const signOut = async () => {
    try {
      setIsLoading(true);
      const { error } = await supabase.auth.signOut();
      if (error) throw error;
    } catch (err) {
      setError(err instanceof AuthError ? err : new AuthError('Failed to sign out'));
    } finally {
      setIsLoading(false);
    }
  };

  return { isLoading, error, user, signOut };
}