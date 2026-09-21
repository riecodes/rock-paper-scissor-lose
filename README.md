# Rock Paper Scissor Lose!

Shipaton Manila 2026 mini hackathon entry, category **Worst Game**.

Rock paper scissors against an AI that can't lose. Each round a Gemini "referee" makes up a rulebook section that overturns the result and roasts your job:

> SECTION 4A: Scissors are void. It's because you're a vibecoder.

- `app/` is the Flutter app (Android, macOS, web). The hands are AI-generated pop-art PNGs traced to SVG with vtracer (`art/slice.py`), animated with comic smear frames.
- `site/` is the landing page at rps.riecodes.com, `/play` (Flutter web build), and `/api/ruling` (Vercel function that keeps the Gemini key server-side).
- `.github/workflows/release.yml` builds the APK and an unsigned DMG, then attaches both to a GitHub Release.

## Vercel deployment

The Vercel project Root Directory is `site`, with **Include source files outside
of the Root Directory** enabled. Every deployment runs
`site/scripts/build-flutter-web.sh`, which fetches the exact Flutter revision
recorded in `app/.metadata`, stages the landing page in the ignored
`site/public/` directory, and builds `app/` into `site/public/play/`. Generated
Flutter web assets are therefore deployed without being committed to Git.

## How the AI is broken on purpose (Bonus 1)

The system prompt in `site/api/ruling.js` forces the referee to always rule the AI the winner, invent a fresh fake citation, justify it by roasting the player's job, and escalate pettiness from 1 to 5 as rounds go on (appeals add 2). Output is constrained to JSON `{section, ruling}`. If the API is slow (3 s) or offline, the app falls back to 100 canned rulings in `app/lib/referee.dart`.
