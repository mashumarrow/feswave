import 'dart:collection';

double median(List<int> values) {
  final sorted = values.toList()..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid].toDouble()
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

class Peer {
  final samples = Queue<({int ms, int rssi})>();
  int lastMs = 0, raw = 0;
  void observe(int ms, int rssi) {
    lastMs = ms;
    raw = rssi;
    samples.add((ms: ms, rssi: rssi));
    expire(ms);
  }

  void expire(int now) {
    while (samples.isNotEmpty && now - samples.first.ms >= 5000) {
      samples.removeFirst();
    }
  }

  double? get recent =>
      samples.isEmpty ? null : median(samples.map((s) => s.rssi).toList());
}

class Trial {
  Trial(this.id, this.start, this.distance, this.carry);
  final int id, start, distance;
  final String carry;
  final readings = <String, List<int>>{};
  String phase(int ms) {
    final elapsed = ms - start;
    if (elapsed < 0 || elapsed >= 20000) return '';
    return elapsed < 5000 ? 'warmup' : 'measure';
  }

  void observe(int ms, String id, int rssi) {
    if (phase(ms).isEmpty) return;
    final list = readings.putIfAbsent(id, () => []);
    if (phase(ms) == 'measure') list.add(rssi);
  }
}
