import 'dart:math' as math;
import 'dart:typed_data';
import 'package:feswave_android/live/spectrum.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fragmented PCM separates bass and treble and decays in silence', () {
    final spectrum = LiveSpectrum();
    Float64List? latest;
    void feed(double hz) {
      final bytes = ByteData(LiveSpectrum.windowSize * 2 * 14);
      for (var i = 0; i < bytes.lengthInBytes ~/ 2; i++) {
        bytes.setInt16(
          2 * i,
          (16000 * math.sin(i * 2 * math.pi * hz / LiveSpectrum.sampleRate))
              .round(),
          Endian.little,
        );
      }
      final pcm = bytes.buffer.asUint8List();
      for (var i = 0; i < pcm.length; i += 773) {
        spectrum.add(
          Uint8List.sublistView(pcm, i, math.min(i + 773, pcm.length)),
          (frame) => latest = frame,
        );
      }
    }

    feed(110);
    expect(latest!.indexOf(latest!.reduce(math.max)), inInclusiveRange(2, 5));
    feed(4200);
    expect(latest!.indexOf(latest!.reduce(math.max)), inInclusiveRange(22, 26));
    feed(0);
    expect(latest!.reduce(math.max), lessThan(.02));
  });
}
