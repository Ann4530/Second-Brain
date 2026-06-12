// Cloudflare Worker — Groq proxy for Second Brain.
//
// The app POSTs { "prompt": "..." } here. The Worker adds the secret Groq API
// key (stored as a Worker secret, never in the app) and forwards to Groq, then
// returns { "content": "<model text>" }.
//
// Deploy:  wrangler secret put GROQ_API_KEY   (paste your gsk_... key)
//          wrangler deploy
//
// Optional hardening (later): require an app-check token, rate-limit per IP.

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

    const r = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: MODEL,
        messages: [
          {
            role: 'system',
            content:
              'You return ONLY a single valid JSON object. No prose, no code fences. ' +
              'Reply in the same language the user wrote in.',
          },
          { role: 'user', content: prompt },
        ],
        temperature: 0.7,
        max_tokens: 900,
        response_format: { type: 'json_object' },
      }),
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
