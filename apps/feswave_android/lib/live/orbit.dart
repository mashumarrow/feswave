import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/particles.dart';
import '../ui/stage.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Colors;

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

class _Glow {
  _Glow(this.origin, this.color, this.phase, this.lifespan, this.dust);
  final Offset origin;
  final Color color;
  final double phase, lifespan;
  final Particle dust;
  double age = 0;
}

class ResonanceGame extends FlameGame {
  final _glows = <_Glow>[];
  final points = <int, Offset>{};
  final _random = math.Random();

  void beat(Offset position, int level, {required bool rising}) {
    _bloom(
      position,
      reactionColors[level],
      rising ? 1.45 : 1.05,
      rising ? 28 : 15,
    );
  }

  void flash(int id) {
    final end = points[id];
    if (end == null) return;
    final center = Offset(size.x / 2, size.y / 2);
    for (final t in [.0, .36, .72, 1.0]) {
      _bloom(
        Offset.lerp(center, end, t)!,
        Color.lerp(apricot, seaGlass, t)!,
        1.8,
        20,
      );
    }
  }

  void _bloom(Offset origin, Color color, double life, int count) {
    final dust = Particle.generate(
      count: count,
      lifespan: life,
      generator: (_) {
        final a = _random.nextDouble() * 2 * math.pi;
        final speed = 24 + _random.nextDouble() * 125;
        final r = 1.4 + _random.nextDouble() * 3;
        return AcceleratedParticle(
          speed: Vector2(math.cos(a) * speed, math.sin(a) * speed),
          acceleration: Vector2(16, -38),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              final fade = 1 - particle.progress;
              canvas.drawOval(
                Rect.fromCenter(
                  center: Offset.zero,
                  width: r * fade * 1.7,
                  height: r * fade,
                ),
                Paint()
                  ..color = Color.lerp(
                    color,
                    pearl,
                    .65,
                  )!.withValues(alpha: fade),
              );
            },
          ),
        );
      },
    );
    if (_glows.length >= 10) _glows.removeAt(0);
    _glows.add(
      _Glow(origin, color, _random.nextDouble() * 2 * math.pi, life, dust),
    );
    resumeEngine();
  }

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  void update(double dt) {
    super.update(dt);
    for (final glow in _glows) {
      glow.age += dt;
      glow.dust.update(dt);
    }
    _glows.removeWhere((g) => g.age >= g.lifespan);
    if (_glows.isEmpty) pauseEngine();
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    for (final glow in _glows) {
      final t = glow.age / glow.lifespan;
      final radius = 14 + size.length * .72 * (1 - (1 - t) * (1 - t));
      canvas.save();
      canvas.translate(glow.origin.dx, glow.origin.dy);
      canvas.rotate(glow.phase + .3 * t);
      canvas.scale(1, .78 + .12 * t);
      final opacity = (1 - t) * (1 - t);
      final paint = Paint()
        ..shader = Gradient.radial(
          Offset.zero,
          radius,
          [
            glow.color.withValues(alpha: .22 * opacity),
            glow.color.withValues(alpha: .03 * opacity),
            glow.color.withValues(alpha: .42 * opacity),
            pearl.withValues(alpha: .70 * opacity),
            glow.color.withValues(alpha: 0),
          ],
          const [0, .55, .82, .89, 1],
        );
      canvas.drawCircle(Offset.zero, radius, paint);
      canvas.restore();
      canvas.save();
      canvas.translate(glow.origin.dx, glow.origin.dy);
      glow.dust.render(canvas);
      canvas.restore();
    }
  }
}
