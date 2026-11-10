import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../ui/stage.dart';
import 'spectrum.dart';

class AudioHalo extends StatefulWidget {
  const AudioHalo({super.key});
  @override
  State<AudioHalo> createState() => _AudioHaloState();
}

class _AudioHaloState extends State<AudioHalo> with WidgetsBindingObserver {
  final levels = ValueNotifier(Float64List(LiveSpectrum.bands));
  AudioRecorder? recorder;
  StreamSubscription<Uint8List>? subscription;
  Future<void> operations = Future.value();
  bool requested = false, visible = false, foreground = false, asking = false;
  bool get shouldListen => mounted && requested && visible && foreground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    foreground =
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    visible = TickerMode.valuesOf(context).enabled;
    sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    sync();
  }

  Future<void> toggle() async {
    if (asking) return;
    if (requested) {
      setState(() => requested = false);
      sync();
      return;
    }
    setState(() => asking = true);
    try {
      final status = await Permission.microphone.request();
      if (!mounted) return;
      if (status.isGranted) {
        setState(() => requested = true);
        sync();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('会場の音を表示するにはマイクを許可してください。'),
            action: status.isPermanentlyDenied
                ? SnackBarAction(label: '設定', onPressed: openAppSettings)
                : null,
          ),
        );
      }
    } catch (_) {
      if (mounted) fail();
    } finally {
      if (mounted) setState(() => asking = false);
    }
  }

  void fail() {
    setState(() => requested = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('マイクを開始できませんでした。もう一度お試しください。')),
    );
    sync();
  }

  void sync() {
    operations = operations
        .then((_) async {
          if (!shouldListen) {
            await stop();
            return;
          }
          if (subscription != null) return;
          final mic = recorder ??= AudioRecorder();
          final stream = await mic.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              audioInterruption: AudioInterruptionMode.none,
              numChannels: 1,
              sampleRate: LiveSpectrum.sampleRate,
              streamBufferSize: 2048,
              androidConfig: AndroidRecordConfig(
                manageBluetooth: false,
                audioSource: AndroidAudioSource.mic,
              ),
            ),
          );
          if (!shouldListen) {
            await mic.stop();
            return;
          }
          final spectrum = LiveSpectrum();
          subscription = stream.listen(
            (bytes) {
              if (shouldListen) {
                spectrum.add(bytes, (frame) => levels.value = frame);
              }
            },
            onError: (_) {
              if (shouldListen) fail();
            },
            onDone: () {
              if (shouldListen) fail();
            },
          );
        })
        .catchError((Object error) {
          debugPrint('FESWAVE microphone: $error');
          if (shouldListen) fail();
        });
  }

  Future<void> stop() async {
    final sub = subscription;
    subscription = null;
    if (sub != null) {
      await sub.cancel();
      await recorder?.stop();
    }
    if (mounted) levels.value = Float64List(LiveSpectrum.bands);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    requested = false;
    unawaited(
      operations.whenComplete(() async {
        try {
          await stop();
        } finally {
          await recorder?.dispose();
        }
      }),
    );
    levels.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (requested)
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(child: CustomPaint(painter: _Bands(levels))),
          ),
        ),
      Positioned(
        top: 4,
        right: 68,
        child: Semantics(
          toggled: requested,
          label: requested ? '音との連動をオフ' : '音との連動をオン',
          child: IconButton(
            onPressed: asking ? null : toggle,
            color: requested ? seaGlass : pearl,
            icon: Icon(requested ? Icons.graphic_eq : Icons.mic_none_rounded),
          ),
        ),
      ),
    ],
  );
}

class _Bands extends CustomPainter {
  _Bands(this.levels) : super(repaint: levels);
  final ValueNotifier<Float64List> levels;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .29;
    final values = levels.value;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.8;
    for (var i = 0; i < values.length; i++) {
      final fraction = (i + .5) / values.length;
      paint.color = Color.lerp(
        seaGlass,
        apricot,
        fraction,
      )!.withValues(alpha: .5 + values[i] * .5);
      for (final side in [-1, 1]) {
        final a = math.pi / 2 + side * math.pi * fraction;
        final dir = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(
          center + dir * radius,
          center + dir * (radius + 2 + values[i] * radius * .52),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_Bands old) => old.levels != levels;
}
