import 'package:feswave_android/live/stage_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mesh_gradient/mesh_gradient.dart';

void main() {
  testWidgets(
    'the stage follows rising and falling levels and reduced motion',
    (tester) async {
      Future<void> show(int level, {bool reduced = false}) => tester.pumpWidget(
        MaterialApp(
          home: StageBackground(level: level, reduced: reduced),
        ),
      );
      AnimatedMeshGradient mesh() =>
          tester.widget(find.byType(AnimatedMeshGradient));
      await show(0);
      final idle = mesh();
      await show(5);
      await tester.pump(const Duration(milliseconds: 210));
      final halfway = mesh();
      await tester.pump(const Duration(milliseconds: 210));
      final peak = mesh();
      expect(halfway.colors, isNot(idle.colors));
      expect(halfway.colors, isNot(peak.colors));
      expect(peak.options.amplitude, lessThan(idle.options.amplitude));
      await show(0);
      await tester.pump(const Duration(milliseconds: 420));
      expect(mesh().colors, idle.colors);
      await show(5, reduced: true);
      await tester.pump(Duration.zero);
      expect(mesh().seed, isNotNull);
      expect(mesh().colors, peak.colors);
    },
  );
}
