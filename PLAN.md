# Rock Paper Scissor Lose!

Shipaton Manila mini hackathon. Category: **Worst Game** (unwinnable). Bonus 1: steer the AI on purpose.

## Decisions (locked)

| Area | Choice |
|---|---|
| Build | Plain Flutter (3.41.6) |
| Art | Retro pop-art (Ben-Day dots, primary colors, WHAM! bursts), generated with ChatGPT Images 2.5 in Chrome, no background |
| Vector | PNG to SVG with vtracer, rendered with `flutter_svg` |
| Motion | Comic smear frames: squash, 1 blurred in-between with speed lines, snap to pose, SFX burst |
| Hands | Both: player bottom, AI top (same SVGs mirrored) |
| Roast input | Name + job on the start screen |
| Rulings | Live Gemini through a Vercel proxy, 3 s timeout, falls back to 100 canned English lines |
| Tone | English, PG-13. Roast the job and move choices, never looks or identity |
| Hosting | Vercel: `rps.riecodes.com` landing page + `/play` Flutter web + `/api/ruling` function |
| DNS | Namecheap MCP (added; needs restart + login), CNAME `rps` to `cname.vercel-dns.com` |
| Builds | APK on this PC; DMG on a GitHub Actions macOS runner (unsigned) |
| Repo | New public repo `riecodes/rock-paper-scissor-lose`, APK + DMG on GitHub Releases |
| QR | Two codes on the landing page: direct APK link, direct DMG link |

## Game loop

1. Start: enter name + job ("vibecoder").
2. Pick rock / paper / scissors.
3. Both fists shake 3 times ("ROCK! PAPER! SCISSORS!"), smear, reveal.
4. AI always wins. Ruling appears in a comic caption box:
   `SECTION 4A: Scissors are void. Reason: you're a vibecoder, Juan.`
5. Scoreboard: AI n, You 0. "Appeal" button returns a harsher ruling.
6. Pettiness rises every round (mood 1 to 5 in the prompt).

## Art list (6 PNGs, transparent)

fist, rock, paper, scissors, smear-open, smear-scissors. One reference image first, the rest generated from it for a consistent style.

## Bonus 1 explanation (for the demo)

The system prompt forces: always rule AI the winner, invent a fake section number, cite the player's job as the legal reason, raise pettiness by round, max 25 words. Return JSON `{section, ruling}`. Same inputs give the same kind of absurdity, so the weirdness is on purpose, not an accident.

## Build order

1. Scaffold Flutter app + Vercel project + GitHub repo.
2. Generate art, trace to SVG, clean up.
3. Game screen + smear animation + rigged result.
4. `/api/ruling` proxy (key in Vercel env, per-IP rate limit) + 100 fallback lines.
5. Landing page with 2 QR codes, `/play` web build, deploy.
6. APK build, GitHub Actions DMG, release, DNS.
7. Rehearse 1 to 2 minute demo.
