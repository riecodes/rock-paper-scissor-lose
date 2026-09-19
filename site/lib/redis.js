// Upstash Redis over its REST API. Env names come from the Vercel Marketplace integration.
const URL_ = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
const TOKEN = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;

export async function redis(...command) {
  const r = await fetch(URL_, {
    method: 'POST',
    headers: { authorization: `Bearer ${TOKEN}`, 'content-type': 'application/json' },
    body: JSON.stringify(command),
    signal: AbortSignal.timeout(4000),
  });
  const j = await r.json();
  if (j.error) throw new Error(j.error);
  return j.result;
}

export function cors(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'content-type');
  if (req.method === 'OPTIONS') {
    res.status(204).end();
    return true;
  }
  return false;
}

// ponytail: per-instance memory, resets on cold start. Good enough to stop one tab from spamming.
const hits = new Map();
export function limited(req, perMinute) {
  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0] || 'unknown';
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  hits.set(ip, [...recent, now]);
  return recent.length >= perMinute;
}
