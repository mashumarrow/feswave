import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/animation.dart' show Animation;
import '../ui/stage.dart';
import "package:flutter/rendering.dart" show CustomPainter;
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;
import '../ui/shared.dart';

Offset orbitPoint(Size size, double phase, double proximity, double angle) {
  final extent = size.shortestSide;
  final radius = lerpDouble(math.min(142.0, extent / 2 - 32), 84, proximity)!;
  return size.center(Offset.zero) +
      Offset(
            math.cos(angle + phase * 2 * math.pi),
            math.sin(angle + phase * 2 * math.pi),
          ) *
          radius;
}

class OrbitGrid extends CustomPainter {
  final int level;
  final Animation<double>? motion;
  OrbitGrid(this.level, this.motion) : super(repaint: motion);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final phase = (motion?.value ?? 0) * 2 * math.pi;
    final extent = size.shortestSide;
    final beam = Paint();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (final side in [-1, 1]) {
      final source = Offset(c.dx + side * extent * .43, size.height * .06);
      final tint = side < 0 ? cyan : pink;
      for (var i = 0; i < 3; i++) {
        final aim = .35 + .18 * i + .16 * math.sin(phase * 5 + side + i * .4);
        final end = source + Offset(-side * aim * extent, size.height * .92);
        final width = 6.0 + level * 2 + i * 3;
        beam.shader = Gradient.linear(
          source,
          end,
          [
            tint.withValues(alpha: .22 + .025 * level),
            tint.withValues(alpha: .065),
            tint.withValues(alpha: 0),
          ],
          [0, .6, 1],
        );
        canvas.drawPath(
          Path()
            ..moveTo(source.dx, source.dy)
            ..lineTo(end.dx - width, end.dy)
            ..lineTo(end.dx + width, end.dy)
            ..close(),
          beam,
        );
      }
    }
    final bar = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    final ring = extent * .39;
    for (var i = 0; i < 84; i++) {
      final angle = i * math.pi / 42;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final wave =
          (.5 + .5 * math.sin(5 * angle + 22 * phase)) *
          (.6 + .4 * math.cos(9 * angle - 13 * phase));
      bar.color = Color.lerp(
        cyan,
        pink,
        .5 + .5 * direction.dx,
      )!.withValues(alpha: .32 + wave * .55);
      canvas.drawLine(
        c + direction * ring,
        c + direction * (ring + 2 + wave * (8 + level * 3)),
        bar,
      );
    }
    canvas.restore();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final radius in [68.0, 95.0]) {
      stroke.color = const Color(0x379b5abb);
      canvas.drawCircle(c, radius, stroke);
    }
    stroke.color = const Color(0x38785f9c);
    final outer = Rect.fromCircle(center: c, radius: 115);
    for (int i = 0; i < 144; i++) {
      canvas.drawArc(outer, i * math.pi / 72, .023, false, stroke);
    }
    stroke.color = const Color(0x089b6dc3);
    canvas.drawLine(c - const Offset(149, 0), c + const Offset(149, 0), stroke);
    canvas.drawLine(c - const Offset(0, 149), c + const Offset(0, 149), stroke);
  }

  @override
  bool shouldRepaint(OrbitGrid old) =>
      old.level != level || old.motion != motion;
}

class _Flash {
  _Flash(this.id);
  final int id;
  double age = 0;
}

class _Beat {
  _Beat(this.level, this.rising, this.angle);
  final int level;
  final bool rising;
  final double angle;
  double age = 0;
  double get duration => rising ? .85 : .5;
}

class ResonanceGame extends FlameGame {
  final List<_Flash> _flashes = [];
  final _beats = <_Beat>[];
  int _beatIndex = 0;
  void beat(int level, {required bool rising}) {
    if (_beats.length >= 10) _beats.removeAt(0);
    _beats.add(_Beat(level, rising, ++_beatIndex * 2.4));
    resumeEngine();
  }

  final points = <int, Offset>{};
  void flash(int id) {
    _flashes.add(_Flash(id));
    resumeEngine();
  }

  @override
  Color backgroundColor() => Colors.transparent;
  @override
  void update(double dt) {
    super.update(dt);
    for (final f in _flashes) {
      f.age += dt;
    }
    _flashes.removeWhere((f) => f.age > .9);
    for (final beat in _beats) {
      beat.age += dt;
    }
    _beats.removeWhere((beat) => beat.age >= beat.duration);
    if (_flashes.isEmpty && _beats.isEmpty) pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final start = Offset(size.x / 2, size.y / 2);
    for (final beat in _beats) {
      final t = beat.age / beat.duration;
      final spread = 1 - (1 - t) * (1 - t);
      final radius = 46 + spread * (beat.rising ? 93 : 50);
      final color = reactionColors[beat.level];
      final paint = Paint()
        ..color = color.withValues(alpha: (1 - t) * .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + (1 - t) * 2;
      if (beat.rising) {
        canvas.drawCircle(start, radius, paint);
        canvas.drawCircle(start, radius + 6, paint..strokeWidth = 1);
      }
      final count = beat.rising ? 30 : 14;
      paint.strokeCap = StrokeCap.round;
      for (var i = 0; i < count; i++) {
        final a = beat.angle + 2 * math.pi * i / count;
        final dir = Offset(math.cos(a), math.sin(a));
        final reach = radius - (i % 3) * 5;
        canvas.drawLine(
          start + dir * reach,
          start + dir * (reach + 2 + (1 - t) * (beat.rising ? 14 : 7)),
          paint,
        );
      }
    }
    for (final f in _flashes) {
      final end = points[f.id];
      if (end == null) continue;
      final t = (f.age / .6).clamp(0.0, 1.0);
      final dot = Offset.lerp(start, end, 1 - math.pow(1 - t, 2).toDouble())!;
      final paint = Paint()
        ..color = cyan.withValues(alpha: (1 - f.age / .9).clamp(0.0, 1.0))
        ..strokeWidth = 2;
      canvas.drawLine(Offset.lerp(start, dot, .68)!, dot, paint);
      canvas.drawCircle(dot, 4, paint);
      if (t == 1) {
        paint.style = PaintingStyle.stroke;
        canvas.drawCircle(end, 18 + (f.age - .6) * 70, paint);
        paint.style = PaintingStyle.fill;
        for (int i = 0; i < 18; i++) {
          final a = i * math.pi / 9,
              radius = 18 + (f.age - .6) * (110 + (i % 3) * 85);
          paint.color = [
            pink,
            cyan,
            lilac,
          ][i % 3].withValues(alpha: (1 - (f.age - .6) / .3).clamp(0.0, 1.0));
          canvas.drawCircle(
            end + Offset(math.cos(a), math.sin(a)) * radius,
            2.8,
            paint,
          );
        }
      }
    }
  }
}
