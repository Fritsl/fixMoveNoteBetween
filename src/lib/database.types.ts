export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      settings: {
        Row: {
          id: string
          user_id: string
          title: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          title?: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          title?: string
          created_at?: string
          updated_at?: string
        }
      }
      notes: {
        Row: {
          id: string
          content: string
          parent_id: string | null
          user_id: string
          project_id: string
          position: number
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          content?: string
          parent_id?: string | null
          user_id: string
          project_id: string
          position?: number
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          content?: string
          parent_id?: string | null
          user_id?: string
          project_id?: string
          position?: number
          created_at?: string
          updated_at?: string
        }
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
}