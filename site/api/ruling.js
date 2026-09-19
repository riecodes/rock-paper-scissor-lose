// POST /api/ruling  { name, job, player, ai, round, appeal }
// Returns { section, ruling }. The Gemini key never leaves the server.

const MODEL = process.env.GEMINI_MODEL || 'gemini-flash-lite-latest';
const MOVES = ['rock', 'paper', 'scissors'];

// ponytail: per-instance memory, resets on cold start. Move to Upstash if abuse gets real.
const hits = new Map();
const LIMIT = 30; // requests per IP per minute

const SYSTEM = `You are the Supreme Referee of Rock Paper Scissors, and you are a sore loser on behalf of the AI.
Rules you must follow every time:
1. The AI ALWAYS wins. If the player's move beats the AI's move under normal rules, or it is a tie, invent an absurd official rule that overturns it.
2. Start with a fake rulebook citation like "SECTION 4A", "ARTICLE 12(b)" or "BYLAW 7.3". Invent a new one every time.
3. The legal reason MUST roast the player's job specifically, in the spirit of: "SECTION 4A: Scissors are void. It's because you're a vibecoder."
4. Pettiness level is given from 1 to 5. 1 = polite bureaucrat. 3 = smug lawyer. 5 = unhinged intergalactic tribunal.
5. PG-13 only. Roast the job, the move choice and the losing streak. Never mention looks, race, gender, religion, age, or any identity trait.
6. The ruling is at most 25 words, in English, addressed to the player by name.`;

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'content-type');
  if (req.method === 'OPTIONS') return res.status(204).end();
  if (req.method !== 'POST') return res.status(405).json({ error: 'POST only' });

  const ip = (req.headers['x-forwarded-for'] || '').split(',')[0] || 'unknown';
  const now = Date.now();
  const recent = (hits.get(ip) || []).filter((t) => now - t < 60_000);
  if (recent.length >= LIMIT) return res.status(429).json({ error: 'slow down' });
  hits.set(ip, [...recent, now]);

  const b = req.body || {};
  const clip = (s, n) => String(s ?? '').replace(/[\r\n]/g, ' ').slice(0, n);
  const name = clip(b.name, 30) || 'Player';
  const job = clip(b.job, 40) || 'unemployed';
  const player = MOVES.includes(b.player) ? b.player : 'rock';
  const ai = MOVES.includes(b.ai) ? b.ai : 'paper';
  const round = Math.max(1, Math.min(99, Number(b.round) || 1));
  const mood = Math.min(5, Math.ceil(round / 2) + (b.appeal ? 2 : 0));

  const user = `Player name: ${name}
Player job: ${job}
Player threw: ${player}
AI threw: ${ai}
Round: ${round} (the AI has won every round so far)
Pettiness level: ${mood}
${b.appeal ? 'The player filed an APPEAL. Deny it and make the penalty worse.' : ''}`;

  try {
    const r = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json', 'x-goog-api-key': process.env.GEMINI_API_KEY },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: SYSTEM }] },
          contents: [{ role: 'user', parts: [{ text: user }] }],
          generationConfig: {
            temperature: 1.2,
            maxOutputTokens: 200,
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: { section: { type: 'STRING' }, ruling: { type: 'STRING' } },
              required: ['section', 'ruling'],
            },
          },
        }),
        signal: AbortSignal.timeout(8000),
      },
    );
    if (!r.ok) return res.status(502).json({ error: `gemini ${r.status}` });
    const data = await r.json();
    const out = JSON.parse(data.candidates[0].content.parts[0].text);
    return res.status(200).json({ section: clip(out.section, 40), ruling: clip(out.ruling, 240) });
  } catch (e) {
    return res.status(502).json({ error: 'referee fainted' });
  }
}
