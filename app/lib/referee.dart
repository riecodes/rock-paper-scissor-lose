import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://rps.riecodes.com');

class Ruling {
  final String section;
  final String text;
  final bool live;
  const Ruling(this.section, this.text, {this.live = false});
}

final _rng = Random();

/// Asks the Gemini referee for a ruling. Falls back to a canned line after 3 s or on any error.
Future<Ruling> fetchRuling({
  required String name,
  required String job,
  required String player,
  required String ai,
  required int round,
  bool appeal = false,
}) async {
  try {
    final r = await http
        .post(
          Uri.parse('$apiBase/api/ruling'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'job': job,
            'player': player,
            'ai': ai,
            'round': round,
            'appeal': appeal,
          }),
        )
        .timeout(const Duration(seconds: 3));
    if (r.statusCode == 200) {
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      return Ruling(j['section'] as String, j['ruling'] as String, live: true);
    }
  } catch (_) {
    // offline, timeout, rate limit: the referee still has a rulebook
  }
  return cannedRuling(name: name, job: job, player: player, appeal: appeal);
}

Ruling cannedRuling({required String name, required String job, required String player, bool appeal = false}) {
  final pool = appeal ? _appeals : _lines;
  final line = pool[_rng.nextInt(pool.length)]
      .replaceAll('{name}', name)
      .replaceAll('{job}', job)
      .replaceAll('{move}', player);
  final kind = const ['SECTION', 'ARTICLE', 'BYLAW', 'CLAUSE', 'AMENDMENT'][_rng.nextInt(5)];
  final letter = String.fromCharCode(65 + _rng.nextInt(26));
  return Ruling('$kind ${1 + _rng.nextInt(99)}$letter', line);
}

const _appeals = [
  'Appeal denied, {name}. Filing an appeal as a {job} is itself a violation. Penalty doubled.',
  'The court has reviewed your appeal, {name}. It was written like a {job} wrote it. Denied.',
  'Appeal received. Appeal laminated. Appeal thrown into the sea. You still lose, {name}.',
  'Denied. The appeals court is also the AI. Did the {job} not read the terms?',
  'Your appeal has been escalated to a higher court, which ruled you lose twice, {name}.',
  'Appeal rejected on the grounds that {job}s may only appeal on leap years.',
  'Appeal denied, {name}. Also, your {move} has been fined for contempt of court.',
  'The judge laughed for eleven minutes. Appeal denied. {job} privileges revoked.',
  'Appeal accepted. Result reviewed. Result confirmed. You lose harder now, {name}.',
  'Denied. The court does not recognize appeals typed by a {job} with that much confidence.',
];

const _lines = [
  "{move} is void. It's because you're a {job}, {name}.",
  '{move} is not allowed for {job}s after 6 PM. The AI wins.',
  'Your {move} was thrown with {job} energy. That is a foul, {name}.',
  '{name}, {job}s must declare {move} in writing 48 hours in advance. Forfeit.',
  "The AI's hand was holding a better move behind its back. That counts. You lose.",
  '{move} was deprecated in the last update. A {job} should know that, {name}.',
  'Tie goes to whoever did not become a {job}. The AI wins.',
  'Your {move} is technically correct, which is the worst kind of correct. Overruled.',
  '{name}, that {move} was AI-generated. Plagiarism. The AI wins by default.',
  'All {job}s start every match at minus one point. Math says you lose.',
  'Your {move} had no unit tests, {name}. Rejected in code review.',
  '{move} requires a premium subscription. {job}s are on the free tier.',
  'The AI threw first in a different timezone. Time zones favor the AI.',
  '{name}, you blinked. Blinking is a forfeit under international rules.',
  'That {move} was lagging. {job}s are always on bad wifi. AI wins.',
  'Your hand shape was 3% off spec. The AI measured. You lose, {name}.',
  '{move} is copyrighted by the AI. Licensing fees apply. You lose.',
  'The referee is the AI. The referee likes the AI. Case closed, {name}.',
  'A {job} throwing {move}? Bold. Wrong, but bold.',
  '{name}, {move} beats nothing on Saturdays. Check the calendar.',
  'Your {move} was not responsive on mobile. Disqualified.',
  "Home court advantage. This is the AI's phone, {name}.",
  '{move} is a {job} cliché. Creativity penalty applied.',
  'The AI pressed ctrl+Z on your move. Undo is legal, {name}.',
  'You threw {move} with the wrong hand, {name}. The AI counted the fingers twice.',
  'Rock paper scissors is best of infinity. The AI is currently ahead.',
  '{name}, your {move} did not include a cover letter. Rejected.',
  'Merge conflict detected in your {move}. The AI resolved it in its favor.',
  '{job}s must hydrate before throwing. You did not. Foul.',
  'Your {move} was 2 milliseconds late. The AI has a ring light and a stopwatch.',
  'The AI invoked Rule 0: the AI wins. It was in the fine print, {name}.',
  'That {move} gave off {job} energy. The judges are allergic.',
  '{name}, {move} is only legal inside a production environment. This is staging.',
  'A {job} cannot win on a weekday. It is a weekday somewhere.',
  'The AI threw quantum paper. It was also scissors. And rock. You lose.',
  'Your {move} failed the vibe check. The AI passed it effortlessly.',
  '{name}, the AI filed its move under NDA. You cannot prove it lost.',
  '{move} has a known CVE. The AI patched you out of the win.',
  'The AI was holding a spare hand under the table. Totally legal.',
  "You thought about paper first, {name}. Thought crimes count.",
  '{job} detected. Handicap mode enabled for the AI. Wait, the other way. Anyway, you lose.',
  'Your {move} did not follow the style guide. Two spaces, not four.',
  'Official ruling: {move} is cringe. The AI wins on style points.',
  '{name}, the AI is the defending champion. Champions keep the belt on ties and losses.',
  'The AI played {move} too, but earlier, in a previous commit. Prior art.',
  '{job}s get one throw per fiscal quarter. You used it. Forfeit.',
  'That {move} was trained on the AI\'s data. Royalties go to the AI.',
  'Your {move} wore sandals. Dress code violation.',
  'The AI\'s move was hidden in a feature flag. It was enabled for winning.',
  '{name}, you said "rock paper scissors" but the AI said "scissors paper rock". Reversed rules.',
  'Your {move} was lovingly hand-crafted. The AI respects that. You still lose.',
  "The AI's hand is registered as a weapon. {move} surrenders on sight.",
  '{job} + {move} = automatic disqualification. It is basic math, {name}.',
  'Your {move} forgot to await. The AI resolved first.',
  'The AI played the uno reverse card. Yes, in rock paper scissors. Legal.',
  '{name}, {move} is out of stock. The AI bought them all.',
  'Your {move} was rated 2 stars on the app store. Not good enough.',
  'The AI was not ready. Replays go to the AI, and the AI already won the replay.',
  'That {move} had a typo in it. Somewhere. The AI found it.',
  '{job}s must throw {move} in Comic Sans. You did not.',
  'The AI consulted the rulebook, then wrote a new page. You lose on page 88.',
  '{name}, {move} beats nothing when thrown by a {job}. It is written.',
  'The AI moved second, but it was the first one to believe in itself.',
  'Your {move} is still loading. The AI does not wait for spinners.',
  'Motion to dismiss {name}\'s {move}: granted, by the AI, for the AI.',
  'The AI threw a hand-drawn {move}. Artisan moves outrank yours.',
  '{move} is fine, but you are a {job}. The rulebook says that matters.',
  'You forfeited when you opened this app, {name}. The rest is ceremony.',
  'Your {move} has been flagged as spam. The AI wins by moderation.',
  "The AI's fingers were crossed. Crossed fingers cancel all outcomes except AI wins.",
  '{name}, the stadium lights hit your {move} at a bad angle. Unfair to the AI.',
  'Your {move} was 100% vibes and 0% documentation. Rejected.',
  '{job}s are required to lose the first 1000 rounds for balance.',
  'The AI\'s {move} is an enterprise edition. Yours is the trial.',
  'That throw was sponsored by a competitor. Ad violation. You lose.',
  '{name}, the AI is running on 3 GPUs. You are running on 3 hours of sleep.',
  'You made eye contact with the AI. That is intimidation. Foul on you.',
  'Your {move} was never pushed to main. It does not exist.',
  "The AI declares {move} a protected species. You can't throw it, {name}.",
  '{job}s must yell their move out loud. You did not. The AI heard nothing.',
  'Every {move} thrown by a {job} is legally a participation trophy.',
  'The AI is also the scorekeeper. Scorekeeper says: AI.',
  '{name}, your {move} was rendered at 30 fps. Competition standard is 120.',
  'The AI threw paper that was laminated. Lamination beats everything.',
  '{move} was banned after the Great {job} Incident of last Tuesday.',
  'Your hand shook. Shaky {move} counts as no move. Forfeit, {name}.',
  'The AI invoked the sore loser clause preemptively. Winners get to do that.',
  '{name}, that {move} looked like it was built in one hour at a hackathon.',
  'Rules update: {move} now loses to everything. Patch notes are below the fold.',
  'Your {move} did not pass CI. The AI\'s move did not need CI.',
  'The AI\'s move was on a secret branch called winning. It was merged.',
  '{job} throws are reviewed by a panel of AIs. Unanimous: you lose.',
  "{name}, you didn't say please. The AI was raised better.",
  'The AI threw scissors made of rock wrapped in paper. Checkmate.',
  'Your {move} was in light mode. The AI only respects dark mode.',
  'The AI\'s move was a limited edition drop. Yours was mass produced.',
  '{move} lost because the vibes were outsourced. Typical {job}.',
  'Final ruling: the AI wins, the {job} loses, and the {move} goes home crying.',
  '{name}, statistically {job}s lose 100% of the time. Science is science.',
  'The AI would have lost, but it chose not to. That is called leadership.',
];
