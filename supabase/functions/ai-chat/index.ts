import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

interface ChatRequest {
  message: string;
  session_id?: string;
  app_source: string;
  user_type?: string;
}

interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY');
    if (!OPENAI_API_KEY) {
      throw new Error('OPENAI_API_KEY is not configured');
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get user from JWT
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('No authorization header');
    }

    const { data: { user }, error: authError } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', '')
    );
    if (authError || !user) {
      throw new Error('Invalid token');
    }

    const body: ChatRequest = await req.json();
    const { message, session_id, app_source, user_type = 'customer' } = body;

    if (!message || !app_source) {
      throw new Error('Message and app_source are required');
    }

    // Get or create session
    let currentSessionId = session_id;
    if (!currentSessionId) {
      const { data: newSession, error: sessionError } = await supabase
        .from('support_chat_sessions')
        .insert({
          user_id: user.id,
          app_source,
          user_type,
          status: 'active'
        })
        .select('id')
        .single();

      if (sessionError) throw sessionError;
      currentSessionId = newSession.id;
    }

    // Save user message
    await supabase.from('support_chat_messages').insert({
      session_id: currentSessionId,
      role: 'user',
      content: message
    });

    // Get system prompt for this app
    const { data: promptData } = await supabase
      .from('ai_system_prompts')
      .select('system_prompt, restrictions')
      .eq('app_source', app_source)
      .eq('is_active', true)
      .single();

    // Get relevant knowledge base entries
    const keywords = message.toLowerCase().split(' ').filter(w => w.length > 2);
    const { data: knowledgeBase } = await supabase
      .from('ai_knowledge_base')
      .select('question, answer, category')
      .or(`app_source.eq.${app_source},app_source.eq.all`)
      .eq('is_active', true)
      .order('priority', { ascending: false })
      .limit(5);

    // Build context from knowledge base
    let contextInfo = '';
    if (knowledgeBase && knowledgeBase.length > 0) {
      contextInfo = '\n\nİLGİLİ BİLGİLER (bu bilgileri kullan):\n';
      knowledgeBase.forEach((kb, i) => {
        contextInfo += `${i + 1}. Soru: ${kb.question}\n   Cevap: ${kb.answer}\n\n`;
      });
    }

    // Get conversation history (last 10 messages)
    const { data: history } = await supabase
      .from('support_chat_messages')
      .select('role, content')
      .eq('session_id', currentSessionId)
      .order('created_at', { ascending: true })
      .limit(10);

    // Build messages array for ChatGPT
    const systemPrompt = promptData?.system_prompt || 'Sen yardımcı bir asistansın.';
    const restrictions = promptData?.restrictions || '';

    const messages: ChatMessage[] = [
      {
        role: 'system',
        content: `${systemPrompt}\n\nKISITLAMALAR:\n${restrictions}${contextInfo}`
      }
    ];

    // Add history
    if (history) {
      history.forEach(msg => {
        if (msg.role === 'user' || msg.role === 'assistant') {
          messages.push({ role: msg.role, content: msg.content });
        }
      });
    }

    // Add current message if not already in history
    if (!history || history.length === 0 || history[history.length - 1].content !== message) {
      messages.push({ role: 'user', content: message });
    }

    // Call ChatGPT API
    const openaiResponse = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        messages,
        max_tokens: 1000,
        temperature: 0.7,
      }),
    });

    if (!openaiResponse.ok) {
      const errorData = await openaiResponse.text();
      console.error('OpenAI Error:', errorData);
      throw new Error('AI service error');
    }

    const aiData = await openaiResponse.json();
    const aiMessage = aiData.choices[0]?.message?.content || 'Üzgünüm, yanıt oluşturulamadı.';
    const tokensUsed = aiData.usage?.total_tokens || 0;

    // Save AI response
    await supabase.from('support_chat_messages').insert({
      session_id: currentSessionId,
      role: 'assistant',
      content: aiMessage,
      tokens_used: tokensUsed
    });

    // Update session
    await supabase
      .from('support_chat_sessions')
      .update({ updated_at: new Date().toISOString() })
      .eq('id', currentSessionId);

    return new Response(
      JSON.stringify({
        success: true,
        session_id: currentSessionId,
        message: aiMessage,
        tokens_used: tokensUsed
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    );

  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    );
  }
});
