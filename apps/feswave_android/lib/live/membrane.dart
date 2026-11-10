import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../ui/stage.dart';

/// Age is normalized to one impulse lifetime; older hits continue when a new one starts.
class MembraneHit {
  const MembraneHit(this.angle, this.age);
  final double angle, age;

  double displacement(double direction, double elapsed, int layer) {
    final t = elapsed + age;
    if (t >= 1) return 0;
    final distance = math.acos(math.cos(direction - angle).clamp(-1.0, 1.0));
    final local = t - .28 * distance / math.pi - .035 * layer;
    if (local <= 0) return 0;
    return -math.sin(local * 14) *
        math.exp(-4.6 * local) *
        (1 - t) *
        (1 - .48 * distance / math.pi);
  }
}

class MembranePainter extends CustomPainter {
  MembranePainter(this.orbit, this.pulse, this.hits, this.reduced)
    : super(repaint: Listenable.merge([orbit, pulse]));
  final Animation<double> orbit, pulse;
  final List<MembraneHit> hits;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final phase = reduced ? 0.0 : orbit.value * 2 * math.pi;
    final bounds = Offset.zero & size;
    final paint = Paint();
    for (var layer = 0; layer < 3; layer++) {
      final points = List.generate(52, (i) {
        final a = 2 * math.pi * i / 52;
        final drift = a + layer * 1.4 + phase * (layer.isEven ? 1 : -1);
        var bend = 0.0;
        if (!reduced) {
          for (final hit in hits) {
            bend += hit.displacement(a, pulse.value, layer);
          }
        }
        // Saturate overlapping strikes so rapid tapping keeps the contour intact.
        final radius =
            size.width *
            (.37 +
                .018 * layer +
                .040 * math.cos(5 * drift) +
                .016 * math.sin(3 * a - 2 * phase) +
                .135 * bend / (1 + bend.abs() * .6));
        return center + Offset(math.cos(a), math.sin(a)) * radius;
      });
      final path = Path();
      final start = Offset.lerp(points.last, points.first, .5)!;
      path.moveTo(start.dx, start.dy);
      for (var i = 0; i < points.length; i++) {
        final p = points[i];
        final mid = Offset.lerp(p, points[(i + 1) % points.length], .5)!;
        path.quadraticBezierTo(p.dx, p.dy, mid.dx, mid.dy);
      }
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        transform: GradientRotation(phase + layer),
        colors: [
          pearl.withValues(alpha: .7),
          seaGlass.withValues(alpha: .24),
          stageNight.withValues(alpha: .10),
          apricot.withValues(alpha: .65),
        ],
        stops: const [0, .24, .64, 1],
      ).createShader(bounds);
      canvas.drawPath(path..close(), paint);
    }
  }

  @override
  bool shouldRepaint(MembranePainter old) =>
      old.hits != hits ||
      old.reduced != reduced ||
      old.orbit != orbit ||
      old.pulse != pulse;
}
