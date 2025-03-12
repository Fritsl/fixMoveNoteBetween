// Follow this setup guide to integrate the Deno runtime successfully: https://deno.com/manual/getting_started/setup_your_environment
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.7'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
        },
      }
    )

    const { userId } = await req.json()
    if (!userId) throw new Error('User ID is required')

    // Get user's email
    const { data: { user }, error: userError } = await supabaseClient.auth.admin.getUserById(userId)
    if (userError || !user?.email) throw new Error('User not found')

    // Get all notes for the user
    const { data: notes, error: notesError } = await supabaseClient
      .from('notes')
      .select('*')
      .eq('user_id', userId)
      .order('created_at')
    if (notesError) throw notesError

    // Build note tree
    const noteMap = new Map(notes.map(note => [note.id, { ...note, children: [] }]))
    const rootNotes = []

    notes.forEach(note => {
      const noteWithChildren = noteMap.get(note.id)
      if (note.parent_id) {
        const parent = noteMap.get(note.parent_id)
        if (parent) {
          parent.children.push(noteWithChildren)
        }
      } else {
        rootNotes.push(noteWithChildren)
      }
    })

    // Format notes as text
    const formatNotes = (notes: any[], level = 0): string => {
      let result = ''
      const indent = '  '.repeat(level)
      
      for (const note of notes) {
        result += `${indent}• ${note.content || 'Empty note...'}\n`
        if (note.children?.length > 0) {
          result += formatNotes(note.children, level + 1)
        }
      }
      
      return result
    }

    const formattedNotes = formatNotes(rootNotes)

    // Send email using Resend
    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'AI Workshop Notes <notes@mg.aiworkshop.dev>',
        to: user.email,
        subject: 'Your Notes from AI Workshop Notes',
        text: `Here are your notes from AI Workshop Notes:\n\n${formattedNotes}\n\nExported on ${new Date().toLocaleString()}`,
      }),
    })

    if (!emailResponse.ok) {
      const error = await emailResponse.json()
      throw new Error(`Failed to send email: ${error.message}`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})