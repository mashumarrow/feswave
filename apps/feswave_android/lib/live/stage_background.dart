import 'package:flutter/material.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

class StageBackground extends StatelessWidget {
  const StageBackground({
    super.key,
    required this.level,
    required this.reduced,
  });

  final int level;
  final bool reduced;

  static const palettes = [
    [
      Color(0xff172b44),
      Color(0xff3c7378),
      Color(0xff794961),
      Color(0xff342941),
    ],
    [
      Color(0xff173e60),
      Color(0xff42aeab),
      Color(0xffbd7083),
      Color(0xff47314e),
    ],
    [
      Color(0xff10518a),
      Color(0xff18d9c0),
      Color(0xffdc709e),
      Color(0xff573670),
    ],
    [
      Color(0xff4038b4),
      Color(0xff21e6d3),
      Color(0xfffc528b),
      Color(0xff942875),
    ],
    [
      Color(0xff6426cc),
      Color(0xffff9774),
      Color(0xffff327c),
      Color(0xffb62390),
    ],
    [
      Color(0xff9825dc),
      Color(0xffffd05a),
      Color(0xffff3859),
      Color(0xffed198c),
    ],
  ];

  @override
  Widget build(BuildContext context) {
    final still = reduced || !TickerMode.valuesOf(context).enabled;
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: level.toDouble()),
        duration: still ? Duration.zero : const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
        builder: (context, value, _) {
          final from = palettes[value.floor()];
          final to = palettes[value.ceil()];
          return AnimatedMeshGradient(
            key: ValueKey(still),
            seed: still ? 2.7 : null,
            colors: [
              for (var i = 0; i < from.length; i++)
                Color.lerp(from[i], to[i], value - value.floor())!,
            ],
            options: AnimatedMeshGradientOptions(
              frequency: 3.8 + .50 * value,
              // The shader divides its wave displacement by amplitude.
              amplitude: 6.0 - .64 * value,
              speed: 1.3,
              grain: .12,
            ),
          );
        },
      ),
    );
  }
}
