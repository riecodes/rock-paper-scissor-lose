// node --test worker.test.mjs
import assert from 'node:assert/strict';
import test from 'node:test';

process.env.KV_REST_API_URL = 'https://kv.test';
process.env.KV_REST_API_TOKEN = 'dummy';
const { handle } = await import('./worker.js');
const leaderboard = (await import('./api/leaderboard.js')).default;
const tts = (await import('./api/tts.js')).default;

const site = 'https://rps.test';

test('POST reaches the handler as a parsed body and records one loss', async () => {
  let sent;
  globalThis.fetch = async (_url, init) => { sent = JSON.parse(init.body); return Response.json({ result: '3' }); };
  const r = await handle(new Request(`${site}/api/leaderboard`, {
    method: 'POST', headers: { 'cf-connecting-ip': '1.1.1.1' }, body: JSON.stringify({ name: 'A', job: 'B' }),
  }), leaderboard);
  assert.equal(r.status, 200);
  assert.deepEqual(await r.json(), { losses: 3 });
  assert.deepEqual(sent, ['ZINCRBY', 'rps:losses', 1, 'A|B']);
  assert.equal(r.headers.get('access-control-allow-origin'), '*');
});

test('a preflight answers 204 with no body', async () => {
  const r = await handle(new Request(`${site}/api/leaderboard`, { method: 'OPTIONS' }), leaderboard);
  assert.equal(r.status, 204);
  assert.equal(await r.text(), '');
});

test('tts without a key says so; a query string reaches the handler', async () => {
  delete process.env.ELEVENLABS_API_KEY;
  const r = await handle(new Request(`${site}/api/tts?text=hi`), tts);
  assert.equal(r.status, 503);
  process.env.ELEVENLABS_API_KEY = 'dummy';
  let body;
  globalThis.fetch = async (_url, init) => { body = JSON.parse(init.body); return new Response(new Uint8Array([1, 2])); };
  const ok = await handle(new Request(`${site}/api/tts?text=hi`, { headers: { 'cf-connecting-ip': '2.2.2.2' } }), tts);
  assert.equal(body.text, 'hi');
  assert.equal(ok.headers.get('content-type'), 'audio/mpeg');
  assert.equal((await ok.arrayBuffer()).byteLength, 2);
});
