// GET /api/tts?text=...  -> audio/mpeg of the ruling read out by ElevenLabs. Key stays server-side.
import { cors, limited } from '../lib/redis.js';

const VOICE = process.env.ELEVENLABS_VOICE_ID || 'JBFqnCBsd6RMkjVDRZzb'; // premade "George": judge energy

export default async function handler(req, res) {
  if (cors(req, res)) return;
  res.setHeader('Cache-Control', 'no-store'); // only a successful clip gets cached (below)
  if (!process.env.ELEVENLABS_API_KEY) return res.status(503).json({ error: 'tts not configured' });
  if (limited(req, 20)) return res.status(429).json({ error: 'slow down' });
  const text = String(req.query.text || '').replace(/\s+/g, ' ').trim().slice(0, 300);
  if (!text) return res.status(400).json({ error: 'text required' });
  try {
    const r = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${VOICE}?output_format=mp3_44100_64`, {
      method: 'POST',
      headers: { 'xi-api-key': process.env.ELEVENLABS_API_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ text, model_id: 'eleven_flash_v2_5' }),
      signal: AbortSignal.timeout(8000),
    });
    if (!r.ok) return res.status(502).json({ error: `elevenlabs ${r.status}` });
    res.setHeader('Content-Type', 'audio/mpeg');
    res.setHeader('Cache-Control', 'public, s-maxage=86400'); // same ruling text, same audio
    return res.status(200).send(Buffer.from(await r.arrayBuffer()));
  } catch {
    return res.status(502).json({ error: 'tts failed' });
  }
}
