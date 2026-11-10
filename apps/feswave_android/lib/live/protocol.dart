import 'dart:typed_data';
import '../profile/models.dart';

const slotMs = 5000;
int strength(int taps) => taps == 0 ? 0 : ((taps + 4) ~/ 5).clamp(1, 5);

class ReactionGauge {
  static const idleMs = 3000;
  static const stepMs = 1000;
  int _points = 0, _lastTap = 0;

  int _pointsAt(int time) {
    final elapsed = time - _lastTap - idleMs;
    if (elapsed < 0) return _points;
    final lost = 5 * (1 + elapsed ~/ stepMs);
    return (_points - lost).clamp(0, 25);
  }

  int levelAt(int time) => strength(_pointsAt(time));

  void tap(int time) {
    _points = (_pointsAt(time) + 1).clamp(0, 25);
    _lastTap = time;
  }
}

String hexId(int id) => id.toRadixString(16).padLeft(8, '0');

class Signal {
  const Signal(
    this.id,
    this.slot,
    this.level,
    this.shared, [
    this.revision = 0,
  ]);
  final int id, slot, level, revision;
  final bool shared;
  Uint8List encode() {
    final data = ByteData(8)
      ..setUint8(0, 0x10 | ((revision & 7) << 1) | (shared ? 1 : 0))
      ..setUint32(1, id)
      ..setUint16(5, slot & 0xffff)
      ..setUint8(7, level);
    return data.buffer.asUint8List();
  }

  static Signal? decode(Uint8List bytes, int current) {
    if (bytes.length != 8) return null;
    final data = ByteData.sublistView(bytes);
    final flags = data.getUint8(0), level = data.getUint8(7);
    if (flags >> 4 != 1 || level > 5) return null;
    final age = (current - data.getUint16(5)) & 0xffff;
    if (age > 2) return null;
    return Signal(
      data.getUint32(1),
      current - age,
      level,
      flags & 1 == 1,
      (flags >> 1) & 7,
    );
  }
}

class Nearby {
  Nearby(this.id);
  final int id;
  final samples = <({int time, int rssi})>[];
  Profile? profile;
  bool shared = false, hasDetails = false;
  int level = 0, revision = -1;
  int last = 0;
  double? shown;
  void observe(int ms, int rssi) {
    last = ms;
    samples.add((time: ms, rssi: rssi));
    samples.removeWhere((s) => s.time < ms - 30000);
  }

  double? medianAt(int end) {
    final v =
        samples
            .where((s) => s.time <= end && s.time > end - 15000)
            .map((s) => s.rssi)
            .toList()
          ..sort();
    if (v.length < 3) return null;
    return (v[(v.length - 1) ~/ 2] + v[v.length ~/ 2]) / 2;
  }

  bool resonates(Signal signal, int localLevel, {required bool sharing}) =>
      sharing &&
      signal.shared &&
      signal.level > 0 &&
      localLevel > 0 &&
      (localLevel - signal.level).abs() <= 1 &&
      nearDuring(signal.slot);

  bool nearDuring(int slot) {
    final end = (slot + 1) * slotMs - 1;
    return (medianAt(end) ?? -127) >= -72 &&
        samples.any((s) => s.time ~/ slotMs == slot);
  }

  double get proximity => (((shown ?? -85) + 85) / 20).clamp(0, 1);
}
