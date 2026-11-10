import 'dart:math' as math;
import 'dart:ui';
import 'package:flame/particles.dart';
import '../ui/stage.dart';

import 'package:flame/game.dart';
import 'package:flutter/material.dart'
    show
        Colors,
        CustomPainter,
        TextPainter,
        TextSpan,
        TextStyle,
        Shadow,
        TextScaler;

double orbitRadius(Size size, double meters) {
  final outer = math.max(0.0, size.shortestSide / 2 - 28);
  final inner = math.min(64.0, outer * .40);
  return lerpDouble(inner, outer, (meters.clamp(1.0, 3.0) - 1) / 2)!;
}

Offset orbitPoint(Size size, double phase, double meters, double angle) =>
    size.center(Offset.zero) +
    Offset.fromDirection(
      angle + phase * 2 * math.pi,
      orbitRadius(size, meters),
    );

class DistanceRings extends CustomPainter {
  const DistanceRings(this.scaler);
  final TextScaler scaler;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final line = Paint()
      ..color = pearl.withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75;
    for (var meters = 1; meters <= 3; meters++) {
      final r = orbitRadius(size, meters.toDouble());
      canvas.drawCircle(center, r, line);
      final label = TextPainter(
        text: TextSpan(
          text: '$meters m',
          style: TextStyle(
            color: pearl.withValues(alpha: .74),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            shadows: const [Shadow(color: stageNight, blurRadius: 4)],
          ),
        ),
        textScaler: scaler,
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, center + Offset(-label.width / 2, -r - label.height));
      label.dispose();
    }
  }

  @override
  bool shouldRepaint(DistanceRings old) => scaler != old.scaler;
}

class PeerRipple extends CustomPainter {
  PeerRipple(this.t, this.color, this.level);
  final double t;
  final Color color;
  final int level;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final delay in [0.0, .18]) {
      final phase = (t - delay) / (1 - delay);
      if (phase < 0 || phase >= 1) continue;
      final fade = 1 - phase;
      final radius = size.width / 2 + (1 - fade * fade) * (22 + level * 7);
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1 + 3 * fade
        ..color = Color.lerp(color, pearl, fade * .7)!.withValues(alpha: fade);
      canvas.drawCircle(center, radius, ring);
      if (delay == 0) {
        for (var i = 0; i < 6 + level; i++) {
          final tip =
              center +
              Offset.fromDirection(
                i * 2 * math.pi / (6 + level) + phase * .32,
                radius + 5 * fade,
              );
          canvas.drawCircle(tip, 2.5 * fade, Paint()..color = ring.color);
        }
      }
    }
  }

  @override
  bool shouldRepaint(PeerRipple old) =>
      t != old.t || color != old.color || level != old.level;
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
