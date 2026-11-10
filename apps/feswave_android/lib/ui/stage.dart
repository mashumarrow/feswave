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
