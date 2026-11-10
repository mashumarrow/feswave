import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fftea/fftea.dart';

class LiveSpectrum {
  static const sampleRate = 44100;
  static const windowSize = 2048;
  static const bands = 32;
  final _transform = STFT(windowSize, Window.hanning(windowSize));
  final _edges = List.generate(
    bands + 1,
    (i) => (55 * math.pow(16000 / 55, i / bands) * windowSize / sampleRate)
        .round(),
  );
  final _levels = Float64List(bands);
  int? _lowByte;

  void add(Uint8List bytes, void Function(Float64List) onFrame) {
    // A platform channel chunk can end in the middle of a PCM16 sample.
    final samples = Float64List(
      (bytes.length + (_lowByte == null ? 0 : 1)) ~/ 2,
    );
    var index = 0;
    for (final byte in bytes) {
      final low = _lowByte;
      if (low == null) {
        _lowByte = byte;
      } else {
        samples[index++] = ((byte << 8) | low).toSigned(16) / 32768;
        _lowByte = null;
      }
    }
    _transform.stream(samples, (bins) {
      for (var i = 0; i < bands; i++) {
        var power = 0.0;
        for (
          var k = _edges[i];
          k < math.max(_edges[i] + 1, _edges[i + 1]);
          k++
        ) {
          final z = bins[k];
          power = math.max(power, z.x * z.x + z.y * z.y);
        }
        // A full-scale sine peaks at N/4 after the Hann window.
        final db =
            10 *
            math.log(math.max(1e-14, power * 16 / (windowSize * windowSize))) /
            math.ln10;
        final target = ((db + 72) / 72).clamp(0.0, 1.0);
        _levels[i] += (target - _levels[i]) * (target > _levels[i] ? .8 : .17);
      }
      onFrame(Float64List.fromList(_levels));
    }, windowSize ~/ 2);
  }
}
