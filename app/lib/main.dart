import 'dart:math';

import 'package:flutter/material.dart';

import 'hand.dart';
import 'referee.dart';

void main() => runApp(const App());

const ink = Color(0xFF111111);
const popYellow = Color(0xFFFFE500);
const popRed = Color(0xFFE8202A);
const popBlue = Color(0xFF1C5BD8);
const popCyan = Color(0xFF3FC8F0);

TextStyle comic(double size, {Color color = ink}) =>
    TextStyle(fontFamily: 'Bangers', fontSize: size, color: color, letterSpacing: 1.2, height: 1.05);

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Rock Paper Scissor Lose!',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(fontFamily: 'Bangers', colorSchemeSeed: popRed),
        home: const StartScreen(),
      );
}

/// Thick black border, hard offset shadow: the comic panel look used everywhere.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color = Colors.white, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final Color color;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: ink, width: 4),
          boxShadow: const [BoxShadow(color: ink, offset: Offset(6, 6))],
        ),
        child: child,
      );
}

class ComicButton extends StatelessWidget {
  const ComicButton(this.label, {super.key, required this.onTap, this.color = popYellow, this.size = 26});
  final String label;
  final VoidCallback? onTap;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: GestureDetector(
          onTap: onTap,
          child: Panel(
            color: color,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(label, textAlign: TextAlign.center, style: comic(size)),
          ),
        ),
      );
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});
  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  final name = TextEditingController();
  final job = TextEditingController();

  @override
  void initState() {
    super.initState();
    precacheHands();
  }

  void go() {
    final n = name.text.trim(), j = job.text.trim();
    if (n.isEmpty || j.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => GameScreen(name: n, job: j)));
  }

  Widget field(String label, TextEditingController c, String hint) => Panel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: TextField(
          controller: c,
          maxLength: 30,
          textCapitalization: TextCapitalization.words,
          style: comic(24),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => go(),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            counterText: '',
            border: InputBorder.none,
            labelStyle: comic(18, color: popRed),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ready = name.text.trim().isNotEmpty && job.text.trim().isNotEmpty;
    return Scaffold(
      body: CustomPaint(
        painter: const Halftone(popCyan, Color(0x55FFFFFF)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Transform.rotate(
                      angle: -0.04,
                      child: Panel(
                        color: popYellow,
                        child: Column(children: [
                          Text('ROCK PAPER SCISSOR', textAlign: TextAlign.center, style: comic(38)),
                          Text('LOSE!', style: comic(84, color: popRed)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text('STATE YOUR NAME AND PROFESSION FOR THE COURT RECORD.',
                        textAlign: TextAlign.center, style: comic(18, color: Colors.white)),
                    const SizedBox(height: 14),
                    field('NAME', name, 'Juan'),
                    const SizedBox(height: 16),
                    field('JOB', job, 'vibecoder'),
                    const SizedBox(height: 28),
                    ComicButton('FIGHT!', onTap: ready ? go : null, color: popRed, size: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.name, required this.job});
  final String name, job;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final throwCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final idleCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();
  late final captionCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  final rng = Random();

  Move? player, ai;
  Ruling? ruling;
  int round = 0, aiScore = 0;
  bool busy = false, appealed = false;

  @override
  void dispose() {
    throwCtl.dispose();
    idleCtl.dispose();
    captionCtl.dispose();
    super.dispose();
  }

  Future<void> play(Move m) async {
    if (busy) return;
    setState(() {
      busy = true;
      round++;
      player = m;
      ai = Move.values[rng.nextInt(3)]; // honest random throw; the referee fixes the result
      ruling = null;
      appealed = false;
    });
    captionCtl.reset();
    final r = fetchRuling(
        name: widget.name, job: widget.job, player: m.name, ai: ai!.name, round: round);
    await throwCtl.forward(from: 0);
    final result = await r;
    if (!mounted) return;
    setState(() {
      ruling = result;
      aiScore++;
      busy = false;
    });
    captionCtl.forward(from: 0);
  }

  Future<void> appeal() async {
    if (busy || ruling == null || appealed) return;
    setState(() => busy = true);
    final r = await fetchRuling(
        name: widget.name, job: widget.job, player: player!.name, ai: ai!.name, round: round, appeal: true);
    if (!mounted) return;
    setState(() {
      ruling = r;
      aiScore++; // penalty for wasting the court's time
      appealed = true;
      busy = false;
    });
    captionCtl.forward(from: 0);
  }

  /// Text between the hands: the chant during the pumps, then a sound effect on the reveal.
  String? burst(double t) {
    if (t == 0) return null;
    if (t < 0.18) return 'ROCK!';
    if (t < 0.37) return 'PAPER!';
    if (t < 0.55) return 'SCISSORS!';
    if (t < 0.70) return 'SHOOT!';
    return switch (ai!) { Move.rock => 'CRUNCH!', Move.paper => 'FWAP!', Move.scissors => 'SNIKT!' };
  }

  bool get honestWin =>
      player != null &&
      ai != null &&
      ((player == Move.rock && ai == Move.scissors) ||
          (player == Move.paper && ai == Move.rock) ||
          (player == Move.scissors && ai == Move.paper));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: const Halftone(popYellow, Color(0x40E8202A)),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AnimatedBuilder(
                animation: Listenable.merge([throwCtl, idleCtl, captionCtl]),
                builder: (context, _) {
                  final t = throwCtl.value;
                  final b = burst(t);
                  return Column(
                    children: [
                      scoreBar(),
                      Expanded(
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Column(children: [
                              Expanded(
                                child: Hand(t: t, idle: (idleCtl.value + 0.5) % 1, target: ai, mirrored: true),
                              ),
                              Expanded(child: Hand(t: t, idle: idleCtl.value, target: player)),
                            ]),
                            if (b != null && ruling == null) sfx(b, t),
                            if (ruling != null) caption(),
                          ],
                        ),
                      ),
                      controls(),
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

  Widget scoreBar() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Panel(padding: EdgeInsets.all(4), child: Icon(Icons.arrow_back, color: ink)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Panel(
                color: popBlue,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text('AI $aiScore  :  0 ${widget.name.toUpperCase()}',
                    textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: comic(26, color: Colors.white)),
              ),
            ),
          ],
        ),
      );

  Widget sfx(String text, double t) {
    final reveal = t >= 0.70;
    final pop = reveal ? Curves.elasticOut.transform(((t - 0.70) / 0.30).clamp(0, 1)) : 1.0;
    return Transform.rotate(
      angle: reveal ? -0.12 : (text.length.isEven ? 0.06 : -0.06),
      child: Transform.scale(
        scale: 0.6 + 0.6 * pop,
        child: Panel(
          color: reveal ? popRed : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Text(text, style: comic(reveal ? 54 : 38, color: reveal ? popYellow : ink)),
        ),
      ),
    );
  }

  Widget caption() {
    final k = Curves.easeOutBack.transform(captionCtl.value);
    return Positioned(
      left: 14,
      right: 14,
      child: Transform.translate(
        offset: Offset(0, (1 - k) * 40),
        child: Opacity(
          opacity: captionCtl.value.clamp(0, 1),
          child: Panel(
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    color: popRed,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Text(ruling!.section.toUpperCase(), style: comic(22, color: popYellow)),
                  ),
                  const Spacer(),
                  Text(appealed ? 'APPEAL DENIED' : (honestWin ? 'OVERRULED!' : 'AI WINS'),
                      style: comic(20, color: popRed)),
                ]),
                const SizedBox(height: 8),
                Text(ruling!.text, style: comic(24)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget controls() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                for (final m in Move.values) ...[
                  Expanded(
                    child: ComicButton(m.name.toUpperCase(), onTap: busy ? null : () => play(m), size: 24),
                  ),
                  if (m != Move.scissors) const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 12),
            ComicButton('APPEAL THE RULING',
                onTap: (busy || ruling == null || appealed) ? null : appeal, color: Colors.white, size: 20),
          ],
        ),
      );
}
