import 'dart:math' as math;
import 'dart:ui';
import "package:flutter/rendering.dart" show CustomPainter;
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;
import '../ui/shared.dart';

Offset orbitPoint(Size size, double phase, double proximity, double angle) {
  final extent = size.shortestSide;
  final radius = lerpDouble(extent * .39, extent * .22, proximity)!;
  return size.center(Offset.zero) +
      Offset(
            math.cos(angle + phase * 2 * math.pi),
            math.sin(angle + phase * 2 * math.pi),
          ) *
          radius;
}

class OrbitGrid extends CustomPainter {
  final int level;
  const OrbitGrid(this.level);
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero), extent = size.shortestSide;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [.22, .305, .39]) {
      stroke.color = lilac.withValues(alpha: .16);
      canvas.drawCircle(c, extent * r, stroke);
    }
    for (int i = 0; i < 60; i++) {
      final a = i * math.pi / 30, d = Offset(math.cos(a), math.sin(a));
      stroke.color = lilac.withValues(alpha: i % 5 == 0 ? 0.5 : 0.19);
      canvas.drawLine(
        c + d * extent * .447,
        c + d * (extent * .447 + (i % 5 == 0 ? 5 : 2)),
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(OrbitGrid old) => false;
}

class _Flash {
  _Flash(this.id);
  final int id;
  double age = 0;
}

class ResonanceGame extends FlameGame {
  final List<_Flash> _flashes = [];
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
    if (_flashes.isEmpty) pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final start = Offset(size.x / 2, size.y / 2);
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
        for (int i = 0; i < 6; i++) {
          final a = i * math.pi / 3, radius = 20 + (f.age - .6) * 95;
          canvas.drawCircle(
            end + Offset(math.cos(a), math.sin(a)) * radius,
            1.8,
            paint,
          );
        }
      }
    }
  }
}
