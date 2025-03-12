import { supabase } from '../supabase';
import { handleDatabaseError } from '../errors';
import { User } from '@supabase/supabase-js';

export const authOperations = {
  async getCurrentUser(): Promise<User> {
    const { data: userData, error } = await supabase.auth.getUser();
    
    if (error || !userData.user) {
      throw handleDatabaseError(error || new Error('No user found'), 'Failed to get current user');
    }
    
    return userData.user;
  },

  async signOut() {
    const { error } = await supabase.auth.signOut();
    if (error) {
      throw handleDatabaseError(error, 'Failed to sign out');
    }
  }
};