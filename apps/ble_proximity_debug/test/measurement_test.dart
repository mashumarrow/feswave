import 'package:ble_proximity_debug/measurement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('5-second window expires even when no further samples arrive', () {
    final peer = Peer()
      ..observe(10, -60)
      ..observe(11, -70)
      ..observe(100, -50);
    expect(peer.recent, -60);
    peer.expire(5010);
    expect(peer.recent, -60);
    peer.expire(5100);
    expect(peer.recent, isNull);
    expect(peer.lastMs, 100);
  });
  test('trial keeps only the 15-second measurement interval', () {
    final trial = Trial(1, 1000, 1, 'hand');
    for (final ms in [5999, 6000, 20999, 21000]) {
      trial.observe(ms, 'A', -60);
    }
    expect(trial.readings['A'], [-60, -60]);
  });
}
