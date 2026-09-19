import 'package:flutter/material.dart';

import 'rps_game.dart';

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
        painter: const RpsHalftone(popCyan, Color(0x55FFFFFF)),
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

class GameScreen extends StatelessWidget {
  const GameScreen({super.key, required this.name, required this.job});
  final String name, job;

  @override
  Widget build(BuildContext context) => Scaffold(body: RpsGame(playerName: name, playerJob: job));
}
