// Debug utilities to help diagnose issues
import { supabase } from './lib/supabase';

export const checkSupabaseConnection = async () => {
  try {
    console.log('Testing Supabase connection...');
    // Check auth status instead of querying a table
    const { data, error } = await supabase.auth.getSession();

    if (error) {
      console.error('Supabase connection error:', error);
      return false;
    }

    console.log('Supabase connection successful:', 
      data.session ? 'Authenticated' : 'Not authenticated');
    return true;
  } catch (error) {
    console.error('Failed to connect to Supabase:', error);
    return false;
  }
};