// Cloudflare Worker for rps.riecodes.com: static files come from public/ (wrangler assets), /api/* runs the same
// handlers Vercel ran, through a small req/res shim. Stage public/ and deploy: see README.md.
import leaderboard from './api/leaderboard.js';
import ruling from './api/ruling.js';
import tts from './api/tts.js';

const routes = { '/api/leaderboard': leaderboard, '/api/ruling': ruling, '/api/tts': tts };

export async function handle(request, handler) {
  const url = new URL(request.url);
  const headers = Object.fromEntries(request.headers);
  headers['x-forwarded-for'] = request.headers.get('cf-connecting-ip') || 'unknown';
  // Vercel parsed JSON bodies for the handlers; a bad body is an empty one there too.
  const body = request.method === 'POST' ? await request.json().catch(() => ({})) : undefined;
  const req = { method: request.method, headers, body, query: Object.fromEntries(url.searchParams) };

  const out = new Headers();
  let status = 200;
  let result = null;
  const res = {
    setHeader: (k, v) => out.set(k, v),
    status(code) { status = code; return res; },
    json(data) { out.set('content-type', 'application/json; charset=utf-8'); result = JSON.stringify(data); return res; },
    send(data) { result = data; return res; },
    end() { return res; },
  };
  await handler(req, res);
  return new Response(result, { status, headers: out });
}

export default {
  fetch(request, env) {
    const handler = routes[new URL(request.url).pathname];
    return handler ? handle(request, handler) : env.ASSETS.fetch(request);
  },
};
