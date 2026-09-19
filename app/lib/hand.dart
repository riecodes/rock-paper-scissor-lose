import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum Move { rock, paper, scissors }

const poses = ['fist', 'rock', 'paper', 'scissors', 'smear_open', 'smear_v'];

/// Throw timeline, t from 0 to 1:
///   0.00-0.55  three comic pumps on the fist (ROCK! PAPER! SCISSORS!)
///   0.55-0.62  squash, the wind-up before the snap
///   0.62-0.70  smear frame: blurred in-between with speed lines
///   0.70-1.00  final pose pops in with an elastic overshoot
class Hand extends StatelessWidget {
  const Hand({super.key, required this.t, required this.idle, required this.target, this.mirrored = false});

  final double t; // throw progress
  final double idle; // 0..1 repeating, for the breathing wobble on still frames
  final Move? target; // null = resting fist
  final bool mirrored; // AI hand hangs from the top

  @override
  Widget build(BuildContext context) {
    var pose = 'fist';
    var dy = 0.0, rot = 0.0, sx = 1.0, sy = 1.0;

    if (target == null || t == 0 || t == 1) {
      if (target != null && t == 1) pose = target!.name;
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
      pose = switch (target!) {
        Move.paper => 'smear_open',
        Move.scissors => 'smear_v',
        Move.rock => 'rock',
      };
      sx = 0.94;
      sy = 1.16;
      dy = -24;
      if (target == Move.rock) rot = (t * 400).floor().isEven ? 0.08 : -0.08; // crunch jitter
    } else {
      pose = target!.name;
      final k = Curves.elasticOut.transform((t - 0.70) / 0.30);
      sx = sy = 0.78 + 0.22 * k;
    }

    Widget hand = Transform.translate(
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
              for (final p in poses)
                Opacity(
                  opacity: p == pose ? 1 : 0,
                  child: SvgPicture.asset('assets/hands/$p.svg', alignment: Alignment.bottomCenter),
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
class Halftone extends CustomPainter {
  const Halftone(this.bg, this.dot);
  final Color bg, dot;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    final p = Paint()..color = dot;
    const step = 14.0;
    for (var y = 0.0, row = 0; y < size.height + step; y += step * 0.866, row++) {
      for (var x = row.isOdd ? step / 2 : 0.0; x < size.width + step; x += step) {
        // dots grow toward the bottom, like a printed gradient
        canvas.drawCircle(Offset(x, y), 1.2 + 3.2 * (y / size.height), p);
      }
    }
  }

  @override
  bool shouldRepaint(Halftone old) => old.bg != bg || old.dot != dot;
}

/// Parse every pose once up front so the first throw never shows an empty hand.
void precacheHands() {
  for (final p in poses) {
    final loader = SvgAssetLoader('assets/hands/$p.svg');
    svg.cache.putIfAbsent(loader.cacheKey(null), () => loader.loadBytes(null));
  }
}
