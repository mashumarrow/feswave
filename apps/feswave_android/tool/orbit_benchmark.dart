// Run with flutter run --profile -t tool/orbit_benchmark.dart on a phone.
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:feswave_android/live/live_page.dart';
import 'package:feswave_android/live/session.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(body: SafeArea(child: LivePage(demoCount: 10))),
      ),
    ),
  );
  Timer(const Duration(seconds: 3), () {
    final frames = <FrameTiming>[];
    void record(List<FrameTiming> batch) => frames.addAll(batch);
    WidgetsBinding.instance.addTimingsCallback(record);
    final pulses = Timer.periodic(const Duration(seconds: 1), (_) {
      for (final peer in [1, 3, 5, 7, 9]) {
        container.read(liveProvider.notifier).effects.add(peer);
      }
    });
    Timer(const Duration(seconds: 20), () {
      pulses.cancel();
      WidgetsBinding.instance.removeTimingsCallback(record);
      int p95(List<int> times) {
        times.sort();
        return times[(times.length * .95).ceil() - 1];
      }

      if (frames.isNotEmpty) {
        debugPrint(
          'FESWAVE benchmark frames=${frames.length} uiP95us=${p95(frames.map((f) => f.buildDuration.inMicroseconds).toList())} rasterP95us=${p95(frames.map((f) => f.rasterDuration.inMicroseconds).toList())}',
        );
      }
    });
  });
}
