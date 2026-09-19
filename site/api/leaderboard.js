// GET  /api/leaderboard          -> { top: [{ name, job, losses }] }  (most losses first)
// POST /api/leaderboard {name, job} -> records one more loss, returns { losses }
import { redis, cors, limited } from '../lib/redis.js';

const KEY = 'rps:losses';
const clip = (s, n) => String(s ?? '').replace(/[\r\n|]/g, ' ').trim().slice(0, n);

export default async function handler(req, res) {
  if (cors(req, res)) return;
  try {
    if (req.method === 'POST') {
      if (limited(req, 40)) return res.status(429).json({ error: 'slow down' });
      const b = req.body || {};
      const member = `${clip(b.name, 30) || 'Player'}|${clip(b.job, 40) || 'unemployed'}`;
      const losses = await redis('ZINCRBY', KEY, 1, member);
      return res.status(200).json({ losses: Number(losses) });
    }
    const raw = await redis('ZRANGE', KEY, 0, 9, 'REV', 'WITHSCORES');
    const top = [];
    for (let i = 0; i < raw.length; i += 2) {
      const [name, job] = raw[i].split('|');
      top.push({ name, job, losses: Number(raw[i + 1]) });
    }
    res.setHeader('Cache-Control', 's-maxage=5');
    return res.status(200).json({ top });
  } catch {
    return res.status(502).json({ error: 'leaderboard unavailable' });
  }
}
