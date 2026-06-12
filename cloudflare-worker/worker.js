// Cloudflare Worker — Groq proxy for Second Brain.
//
// The app POSTs { "prompt": "...", "mode": "json"|"chat" } here.
// The Worker adds the secret Groq API key and forwards to Groq.
// Returns { "content": "<model text>" }.
//
// mode "json" (default): forces JSON response_format, used for reflect/recap.
// mode "chat": plain text, used for conversation turns.
//
// Deploy:  wrangler secret put GROQ_API_KEY   (paste your gsk_... key)
//          wrangler deploy

const GROQ_URL = 'https://api.groq.com/openai/v1/chat/completions';
const MODEL = 'llama-3.3-70b-versatile';

export default {
  async fetch(request, env) {
    if (request.method !== 'POST') {
      return json({ error: 'POST only' }, 405);
    }
    let body;
    try {
      body = await request.json();
    } catch {
      return json({ error: 'invalid json' }, 400);
    }
    const prompt = body && body.prompt;
    if (!prompt || typeof prompt !== 'string') {
      return json({ error: 'missing "prompt"' }, 400);
    }
    if (!env.GROQ_API_KEY) {
      return json({ error: 'server not configured (GROQ_API_KEY missing)' }, 500);
    }

    const isChat = body.mode === 'chat';

    const groqBody = {
      model: MODEL,
      messages: [
        {
          role: 'system',
          content: isChat
            ? 'You are a warm, curious journaling companion. Ask ONE thoughtful follow-up question per turn. Keep it short and empathetic.'
            : 'You return ONLY a single valid JSON object. No prose, no code fences. Reply in the same language the user wrote in.',
        },
        { role: 'user', content: prompt },
      ],
      temperature: isChat ? 0.8 : 0.7,
      max_tokens: isChat ? 200 : 900,
    };

    // JSON mode only for non-chat calls
    if (!isChat) {
      groqBody.response_format = { type: 'json_object' };
    }

    const r = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(groqBody),
    });

    if (!r.ok) {
      const t = await r.text();
      return json({ error: `groq ${r.status}: ${t.slice(0, 300)}` }, 502);
    }
    const data = await r.json();
    const content = data?.choices?.[0]?.message?.content ?? '';
    return json({ content });
  },
};

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
