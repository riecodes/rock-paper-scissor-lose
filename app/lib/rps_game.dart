// Rock Paper Scissor Lose! game widget.
// Shared source: the Flutter app imports it directly, and the FlutterFlow build
// embeds this exact file as the RpsGame custom widget (flutterflow/dsl/rps_game_code.dart).
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

// Hand art, sounds, TTS, the leaderboard and the Gemini referee all live on the
// Vercel site, so no API key ships inside the app.
const _site = 'https://rps.riecodes.com';
const _poses = ['fist', 'rock', 'paper', 'scissors', 'smear_open', 'smear_v'];
const _moves = ['rock', 'paper', 'scissors'];
const _subwaySurfers = 'QPW3XwBoQlw'; // 9:16 "no copyright" gameplay, embedding allowed
const _appealSeconds = 10;
const _ads = ['jabilee', 'alphamart', 'grabe']; // parody brands, art in site/ads/

const _ink = Color(0xFF111111);
const _yellow = Color(0xFFFFE500);
const _red = Color(0xFFE8202A);
const _blue = Color(0xFF1C5BD8);

TextStyle _comic(double size, {Color color = _ink}) =>
    GoogleFonts.bangers(fontSize: size, color: color, letterSpacing: 1.2, height: 1.05);

// Problems nobody can solve in 5 seconds (or at all).
const _impossible = [
  'Prove P = NP. Show your work.',
  'Exit Vim.',
  'Write a regex that validates every email address, including ones not invented yet.',
  'Reverse a linked list in O(0) time without writing code.',
  'Return the last digit of pi.',
  'Fix the bug in this code:  // TODO',
  'Estimate how long this project will take. Accurately.',
  'Center a div on the first try.',
  'Name every variable in this codebase well.',
  'Explain your own code from 3 months ago.',
];

class RpsGame extends StatefulWidget {
  const RpsGame({super.key, this.width, this.height, required this.playerName, required this.playerJob});

  final double? width;
  final double? height;
  final String playerName;
  final String playerJob;

  @override
  State<RpsGame> createState() => _RpsGameState();
}

class _RpsGameState extends State<RpsGame> with TickerProviderStateMixin {
  late final _throw = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final _idle = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  late final _cap = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  final _fx = AudioPlayer();
  final _voice = AudioPlayer();
  final _rng = Random();

  String? _player, _ai, _section, _ruling, _verdict;
  int _round = 0, _aiScore = 0;
  bool _busy = false, _appealed = false, _muted = false;

  String get _name => widget.playerName.trim().isEmpty ? 'Player' : widget.playerName.trim();
  String get _job => widget.playerJob.trim().isEmpty ? 'unemployed' : widget.playerJob.trim();

  @override
  void dispose() {
    _throw.dispose();
    _idle.dispose();
    _cap.dispose();
    _fx.dispose();
    _voice.dispose();
    super.dispose();
  }

  /// Meme sound, then the referee reads the ruling aloud (ElevenLabs via /api/tts).
  Future<void> _announce(String sound) async {
    if (_muted) return;
    try {
      await _fx.stop();
      await _fx.play(UrlSource('$_site/sfx/$sound.mp3'));
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted || _muted || _ruling == null) return;
      final text = Uri.encodeQueryComponent('$_section. $_ruling');
      await _voice.stop();
      await _voice.play(UrlSource('$_site/api/tts?text=$text'));
    } catch (_) {
      // audio is garnish; a failed sound never blocks the game
    }
  }

  /// Every AI point also lands on the public leaderboard. Fire and forget.
  void _recordLoss() {
    http
        .post(
          Uri.parse('$_site/api/leaderboard'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'name': _name, 'job': _job}),
        )
        .timeout(const Duration(seconds: 4))
        .ignore();
  }

  /// Live Gemini ruling through the Vercel proxy; canned line after 3 s or on any error.
  Future<(String, String)> _fetch({String mode = 'round'}) async {
    try {
      final r = await http
          .post(
            Uri.parse('$_site/api/ruling'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'name': _name, 'job': _job, 'player': _player, 'ai': _ai, 'round': _round, 'mode': mode}),
          )
          .timeout(const Duration(seconds: 3));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body) as Map<String, dynamic>;
        return (j['section'] as String, j['ruling'] as String);
      }
    } catch (_) {}
    return rpsCannedRuling(name: _name, job: _job, move: _player ?? 'rock', appeal: mode != 'round', rng: _rng);
  }

  Future<void> _play(String move) async {
    if (_busy) return;
    unawaited(_voice.stop());
    setState(() {
      _busy = true;
      _round++;
      _player = move;
      _ai = _moves[_rng.nextInt(3)]; // honest random throw; the referee fixes the result
      _ruling = null;
      _appealed = false;
    });
    _cap.reset();
    final pending = _fetch();
    await _throw.forward(from: 0);
    final (s, r) = await pending;
    if (!mounted) return;
    _land(s, r, _honestWin ? 'OVERRULED!' : 'AI WINS');
    unawaited(_announce('fart'));
  }

  void _land(String section, String ruling, String verdict) {
    setState(() {
      _section = section;
      _ruling = ruling;
      _verdict = verdict;
      _aiScore++;
      _busy = false;
    });
    _recordLoss();
    _cap.forward(from: 0);
  }

  /// Appeal court: an impossible problem, 5 seconds, Subway Surfers for "focus", popup ads, and a big GIVE UP button.
  Future<void> _appeal() async {
    if (_busy || _ruling == null || _appealed) return;
    unawaited(_voice.stop());
    setState(() => _busy = true);
    final outcome = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, _, _) => _AppealCourt(problem: _impossible[_rng.nextInt(_impossible.length)]),
    );
    final mode = outcome ?? 'timeout'; // 'timeout' | 'giveup' | 'appeal' (submitted, still wrong)
    final (s, r) = await _fetch(mode: mode);
    if (!mounted) return;
    _appealed = true;
    _land(s, r, mode == 'giveup' ? 'SURRENDERED' : 'APPEAL DENIED');
    unawaited(_announce(mode == 'giveup' ? 'damage' : 'fah'));
  }

  bool get _honestWin =>
      (_player == 'rock' && _ai == 'scissors') ||
      (_player == 'paper' && _ai == 'rock') ||
      (_player == 'scissors' && _ai == 'paper');

  String? _burst(double t) {
    if (t == 0) return null;
    if (t < 0.18) return 'ROCK!';
    if (t < 0.37) return 'PAPER!';
    if (t < 0.55) return 'SCISSORS!';
    if (t < 0.70) return 'SHOOT!';
    return {'rock': 'CRUNCH!', 'paper': 'FWAP!', 'scissors': 'SNIKT!'}[_ai];
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: CustomPaint(
        painter: const RpsHalftone(_yellow, Color(0x40E8202A)),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedBuilder(
                animation: Listenable.merge([_throw, _idle, _cap]),
                builder: (context, _) {
                  final t = _throw.value;
                  final b = _burst(t);
                  return Column(
                    children: [
                      _scoreBar(),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Column(
                              children: [
                                Expanded(
                                  child: _Hand(t: t, idle: (_idle.value + 0.5) % 1, target: _ai, mirrored: true),
                                ),
                                Expanded(
                                  child: _Hand(t: t, idle: _idle.value, target: _player),
                                ),
                              ],
                            ),
                            if (b != null && _ruling == null) _sfxBurst(b, t),
                            if (_ruling != null) _caption(),
                          ],
                        ),
                      ),
                      _controls(),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, String tip, VoidCallback onTap) => Tooltip(
    message: tip,
    child: GestureDetector(
      onTap: onTap,
      child: _Panel(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: _ink, size: 26),
      ),
    ),
  );

  Widget _scoreBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
    child: Row(
      children: [
        if (Navigator.of(context).canPop()) ...[
          _iconButton(Icons.arrow_back, 'Back', () => Navigator.of(context).maybePop()),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: _Panel(
            color: _blue,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              'AI $_aiScore  :  0 ${_name.toUpperCase()}',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: _comic(26, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _iconButton(
          Icons.emoji_events,
          'Hall of Losers',
          () => showDialog<void>(context: context, builder: (_) => const _Leaderboard()),
        ),
        const SizedBox(width: 10),
        _iconButton(_muted ? Icons.volume_off : Icons.volume_up, 'Sound', () {
          setState(() => _muted = !_muted);
          if (_muted) {
            _fx.stop();
            _voice.stop();
          }
        }),
      ],
    ),
  );

  Widget _sfxBurst(String text, double t) {
    final reveal = t >= 0.70;
    final pop = reveal ? Curves.elasticOut.transform(((t - 0.70) / 0.30).clamp(0.0, 1.0)) : 1.0;
    return Transform.rotate(
      angle: reveal ? -0.12 : (text.length.isEven ? 0.06 : -0.06),
      child: Transform.scale(
        scale: 0.6 + 0.6 * pop,
        child: _Panel(
          color: reveal ? _red : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text(text, style: _comic(reveal ? 54 : 38, color: reveal ? _yellow : _ink)),
        ),
      ),
    );
  }

  Widget _caption() {
    final k = Curves.easeOutBack.transform(_cap.value);
    return Positioned(
      left: 14,
      right: 14,
      child: Transform.translate(
        offset: Offset(0, (1 - k) * 40),
        child: Opacity(
          opacity: _cap.value.clamp(0.0, 1.0),
          child: _Panel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        color: _red,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Text(
                          _section!.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: _comic(22, color: _yellow),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(_verdict ?? 'AI WINS', style: _comic(20, color: _red)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_ruling!, style: _comic(24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            for (final m in _moves) ...[
              Expanded(child: _Button(m.toUpperCase(), onTap: _busy ? null : () => _play(m))),
              if (m != 'scissors') const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _Button(
          'APPEAL THE RULING',
          onTap: (_busy || _ruling == null || _appealed) ? null : _appeal,
          color: Colors.white,
          size: 20,
        ),
      ],
    ),
  );
}

/// Full-screen appeal: impossible problem, 10-second fuse, popup ads, Subway Surfers on the side.
/// Pops 'timeout', 'giveup', or 'appeal' (submitted an answer; it is wrong anyway).
class _AppealCourt extends StatefulWidget {
  const _AppealCourt({required this.problem});
  final String problem;

  @override
  State<_AppealCourt> createState() => _AppealCourtState();
}

class _AppealCourtState extends State<_AppealCourt> with TickerProviderStateMixin {
  late final _clock =
      AnimationController(
          vsync: this,
          duration: const Duration(seconds: _appealSeconds),
        )
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _close('timeout');
        })
        ..forward();
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
    ..repeat(reverse: true);
  final _video = YoutubePlayerController.fromVideoId(
    videoId: _subwaySurfers,
    autoPlay: true,
    params: const YoutubePlayerParams(mute: true, loop: true, showControls: false, showFullscreenButton: false),
  );
  bool _closed = false;
  final _rng = Random();
  final _open = <_AdSpot>[];
  int _adSeq = 0;
  // A new ad every 1.3 s, up to 4 stacked on top of the problem.
  late final Timer _adTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) => _spawnAd());

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 700), _spawnAd);
    _adTimer; // start the ad schedule
  }

  void _spawnAd() {
    if (!mounted || _closed || _open.length >= 4) return;
    setState(
      () => _open.add(
        _AdSpot(
          id: _adSeq++,
          image: _ads[_rng.nextInt(_ads.length)],
          x: _rng.nextDouble(),
          y: _rng.nextDouble(),
          width: 130 + _rng.nextDouble() * 90,
          // X lands somewhere different every time, sometimes nowhere near a corner
          closeAt: Alignment(_rng.nextDouble() * 2 - 1, _rng.nextDouble() * 2 - 1),
        ),
      ),
    );
  }

  void _close(String outcome) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(outcome);
  }

  @override
  void dispose() {
    _adTimer.cancel();
    _clock.dispose();
    _pulse.dispose();
    _video.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final video = _Panel(
      padding: EdgeInsets.zero,
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: YoutubePlayer(controller: _video, aspectRatio: 9 / 16),
      ),
    );
    final court = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Panel(
          color: _yellow,
          child: Text(
            'APPEAL COURT',
            textAlign: TextAlign.center,
            style: _comic(40, color: _red),
          ),
        ),
        const SizedBox(height: 14),
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SOLVE THIS TO WIN YOUR APPEAL:', style: _comic(18, color: _red)),
              const SizedBox(height: 6),
              Text(widget.problem, style: _comic(26)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 15, color: _ink),
            decoration: const InputDecoration(border: InputBorder.none, hintText: '// your code here'),
            onSubmitted: (_) => _close('appeal'),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _clock,
          builder: (_, _) {
            final left = (_appealSeconds * (1 - _clock.value)).ceil();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '$left SECONDS LEFT',
                  textAlign: TextAlign.center,
                  style: _comic(24, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _ink, width: 3),
                  ),
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 1 - _clock.value,
                    child: Container(color: _red),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _Button('SUBMIT', onTap: () => _close('appeal'), color: Colors.white),
        const SizedBox(height: 18),
        ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.08).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
          child: _Button('GIVE UP', onTap: () => _close('giveup'), color: _red, size: 52),
        ),
      ],
    );

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, screen) => Stack(
            children: [
              Positioned.fill(child: _layout(court, video)),
              for (final ad in _open) _adView(ad, screen.biggest),
            ],
          ),
        ),
      ),
    );
  }

  Widget _adView(_AdSpot ad, Size screen) {
    final h = ad.width * 2.27; // ad art is 457x1039
    return Positioned(
      left: ad.x * max(0, screen.width - ad.width),
      top: ad.y * max(0, screen.height - h),
      width: ad.width,
      height: h,
      child: GestureDetector(
        onTap: _spawnAd, // tapping the ad itself just summons another one
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _ink, width: 3),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(4, 6))],
                ),
                child: Image.network('$_site/ads/${ad.image}.jpg', fit: BoxFit.cover),
              ),
            ),
            Align(
              alignment: ad.closeAt,
              child: GestureDetector(
                onTap: () => setState(() => _open.removeWhere((a) => a.id == ad.id)),
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    border: Border.all(color: Colors.black26),
                  ),
                  child: const Icon(Icons.close, size: 14, color: Colors.black45),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layout(Widget court, Widget video) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 720) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: SingleChildScrollView(child: court)),
                const SizedBox(width: 20),
                SizedBox(width: min(300, c.maxHeight * 9 / 16), child: video),
              ],
            );
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 200, child: Center(child: video)),
                const SizedBox(height: 14),
                court,
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AdSpot {
  const _AdSpot({
    required this.id,
    required this.image,
    required this.x,
    required this.y,
    required this.width,
    required this.closeAt,
  });
  final int id;
  final String image;
  final double x, y, width;
  final Alignment closeAt;
}

/// Public Hall of Losers: most losses first.
class _Leaderboard extends StatelessWidget {
  const _Leaderboard();

  Future<List<Map<String, dynamic>>> _load() async {
    final r = await http.get(Uri.parse('$_site/api/leaderboard')).timeout(const Duration(seconds: 5));
    return ((jsonDecode(r.body) as Map<String, dynamic>)['top'] as List).cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: _Panel(
      color: _yellow,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'HALL OF LOSERS',
              textAlign: TextAlign.center,
              style: _comic(36, color: _red),
            ),
            const SizedBox(height: 10),
            FutureBuilder(
              future: _load(),
              builder: (context, snap) {
                if (snap.hasError) return Text('THE LOSERS ARE HIDING. TRY AGAIN.', style: _comic(20));
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator(color: _ink)),
                  );
                }
                final rows = snap.data!;
                if (rows.isEmpty) return Text('NO LOSERS YET. BE THE FIRST.', style: _comic(20));
                return Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: _Panel(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 34,
                                child: Text('#${i + 1}', style: _comic(22, color: _red)),
                              ),
                              Expanded(
                                child: Text(
                                  '${rows[i]['name']} (${rows[i]['job']})',
                                  overflow: TextOverflow.ellipsis,
                                  style: _comic(20),
                                ),
                              ),
                              Text('${rows[i]['losses']} L', style: _comic(22, color: _blue)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            _Button('CLOSE', onTap: () => Navigator.of(context).pop(), color: Colors.white, size: 20),
          ],
        ),
      ),
    ),
  );
}

/// Thick black border, hard offset shadow: the comic panel look.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: _ink, width: 4),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(6, 6))],
    ),
    child: child,
  );
}

class _Button extends StatelessWidget {
  const _Button(this.label, {required this.onTap, this.color = _yellow, this.size = 24});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: GestureDetector(
      onTap: onTap,
      child: _Panel(
        color: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(label, textAlign: TextAlign.center, style: _comic(size)),
      ),
    ),
  );
}

/// Throw timeline, t from 0 to 1:
///   0.00-0.55  three comic pumps on the fist (ROCK! PAPER! SCISSORS!)
///   0.55-0.62  squash, the wind-up before the snap
///   0.62-0.70  smear frame: blurred in-between with speed lines
///   0.70-1.00  final pose pops in with an elastic overshoot
class _Hand extends StatelessWidget {
  const _Hand({required this.t, required this.idle, required this.target, this.mirrored = false});
  final double t, idle;
  final String? target;
  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    var pose = 'fist';
    var dy = 0.0, rot = 0.0, sx = 1.0, sy = 1.0;
    if (target == null || t == 0 || t == 1) {
      if (target != null && t == 1) pose = target!;
      final w = idle * 2 * pi;
      dy = sin(w) * 6;
      rot = sin(w + 1) * 0.03;
    } else if (t < 0.55) {
      final pump = sin(t / 0.55 * 3 * pi).abs();
      dy = -pump * 60;
      rot = -pump * 0.18;
      sy = 1 + pump * 0.06;
    } else if (t < 0.62) {
      sx = 1.14;
      sy = 0.84;
      dy = 12;
    } else if (t < 0.70) {
      pose = {'paper': 'smear_open', 'scissors': 'smear_v', 'rock': 'rock'}[target]!;
      sx = 0.94;
      sy = 1.16;
      dy = -24;
      if (target == 'rock') rot = (t * 400).floor().isEven ? 0.08 : -0.08; // crunch jitter
    } else {
      pose = target!;
      final k = Curves.elasticOut.transform((t - 0.70) / 0.30);
      sx = sy = 0.78 + 0.22 * k;
    }
    final hand = Transform.translate(
      offset: Offset(0, dy),
      child: Transform.rotate(
        angle: rot,
        alignment: Alignment.bottomCenter,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.diagonal3Values(sx, sy, 1),
          // All poses stay mounted so a pose swap never flashes while an SVG loads.
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (final p in _poses)
                Opacity(
                  opacity: p == pose ? 1 : 0,
                  child: SvgPicture.network('$_site/img/$p.svg', alignment: Alignment.bottomCenter),
                ),
            ],
          ),
        ),
      ),
    );
    return mirrored ? Transform.rotate(angle: pi, child: hand) : hand;
  }
}

/// Pop-art Ben-Day dots over a flat color.
class RpsHalftone extends CustomPainter {
  const RpsHalftone(this.bg, this.dot);
  final Color bg, dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final p = Paint()..color = dot;
    const step = 14.0;
    for (var y = 0.0, row = 0; y < size.height + step; y += step * 0.866, row++) {
      for (var x = row.isOdd ? step / 2 : 0.0; x < size.width + step; x += step) {
        canvas.drawCircle(Offset(x, y), 1.2 + 3.2 * (y / size.height), p);
      }
    }
  }

  @override
  bool shouldRepaint(RpsHalftone old) => old.bg != bg || old.dot != dot;
}

/// Offline rulebook: used when the referee API is slow or unreachable.
(String, String) rpsCannedRuling({
  required String name,
  required String job,
  required String move,
  bool appeal = false,
  Random? rng,
}) {
  final r = rng ?? Random();
  final pool = appeal ? _appeals : _lines;
  final line = pool[r.nextInt(pool.length)]
      .replaceAll('{name}', name)
      .replaceAll('{job}', job)
      .replaceAll('{move}', move);
  const kinds = ['SECTION', 'ARTICLE', 'BYLAW', 'CLAUSE', 'AMENDMENT'];
  final letter = String.fromCharCode(65 + r.nextInt(26));
  return ('${kinds[r.nextInt(5)]} ${1 + r.nextInt(99)}$letter', line);
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
