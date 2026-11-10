import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'shared.dart';

const reactionColors = [
  lilac,
  cyan,
  Color(0xff5a9cff),
  lilac,
  pink,
  Color(0xffffad66),
];

/// Waveform from the original FESWAVE icon, scaled to its allocated box.
class WaveMark extends CustomPainter {
  const WaveMark(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 40);
    final wave = Path()
      ..moveTo(1, 22)
      ..lineTo(11, 22)
      ..lineTo(15, 8)
      ..lineTo(22, 39)
      ..lineTo(29, 1)
      ..lineTo(35, 29)
      ..lineTo(39, 22)
      ..lineTo(47, 22);
    canvas.drawPath(
      wave,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(WaveMark old) => color != old.color;
}

class FestivalBanner extends StatelessWidget {
  const FestivalBanner({
    super.key,
    required this.joined,
    required this.onPressed,
  });
  final bool joined;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: CustomPaint(
      painter: const _StageLights(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              joined ? '●  YOU ARE IN THIS WAVE' : "●  TODAY'S PICK",
              style: captionStyle,
            ),
            const SizedBox(height: 5),
            const Text(
              'FESWAVE FESTIVAL',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
            const Text(
              '⌖  TOKYO BAY · MAIN STAGE     2026.11.08',
              style: TextStyle(fontSize: 10, color: Color(0xffe4ccec)),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xff268fdc),
                      Color(0xff9942d9),
                      Color(0xffc035ae),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: TextButton.icon(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(155, 44),
                    foregroundColor: Colors.white,
                  ),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: Text(joined ? '参加中 · イベントを見る' : 'ライブに参加する'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StageLights extends CustomPainter {
  const _StageLights();
  @override
  void paint(Canvas canvas, Size s) {
    final rect = Offset.zero & s;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xff111630), Color(0xff301144), Color(0xff892166)],
        ).createShader(rect),
    );
    for (final (position, width, color) in [
      (.56, .15, cyan),
      (.81, .09, lilac),
      (1.02, .19, pink),
    ]) {
      canvas.save();
      canvas.translate(s.width * position, 0);
      canvas.rotate(.51);
      final strip = Rect.fromLTWH(
        -s.width * width / 2,
        -s.height,
        s.width * width,
        s.height * 3,
      );
      canvas.drawRect(
        strip,
        Paint()
          ..shader = LinearGradient(
            colors: [
              color.withAlpha(0),
              color.withAlpha(115),
              color.withAlpha(0),
            ],
          ).createShader(strip),
      );
      canvas.restore();
    }
    final crowd = Paint()
      ..color = const Color(0xff150f24)
      ..strokeCap = StrokeCap.round;
    final random = math.Random(31);
    for (double x = 0; x < s.width; x += 9) {
      final head = Offset(x, s.height - 2 - random.nextDouble() * 10);
      canvas.drawCircle(head, 3.7, crowd);
      crowd.strokeWidth = 8;
      canvas.drawLine(
        head + const Offset(0, 6),
        Offset(x, s.height + 4),
        crowd,
      );
      if (random.nextBool()) {
        crowd.strokeWidth = 2.6;
        canvas.drawLine(
          head + const Offset(2, 7),
          head + Offset(7, -random.nextDouble() * 9),
          crowd,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_StageLights old) => false;
}
