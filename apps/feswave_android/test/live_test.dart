import 'dart:typed_data';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feswave_android/live/protocol.dart';
import 'package:feswave_android/memories/database.dart';
import 'package:feswave_android/profile/models.dart';

void main() {
  test('replays the recorded 1 m and 3 m handheld trials', () {
    final readings = <String, Nearby>{};
    for (final line in File(
      'test/fixtures/proximity.csv',
    ).readAsLinesSync().skip(1)) {
      final c = line.split(',');
      (readings['${c[0]}/${c[1]}'] ??= Nearby(
        1,
      )).observe(int.parse(c[2]), int.parse(c[3]));
    }
    final medians = readings.map((k, p) => MapEntry(k, p.medianAt(p.last)));
    expect(medians, {
      'redmi/1': -63,
      'redmi/3': -75,
      'pixel4/1': -68,
      'pixel4/3': -82,
    });
  });
  test('requires two participating levels, consent and local proximity', () {
    final p = Nearby(1)
      ..observe(1000, -65)
      ..observe(2000, -68)
      ..observe(3000, -70);
    const reaction = Signal(1, 0, 3, true);
    expect(p.resonates(reaction, 2, sharing: true), isTrue);
    expect(p.resonates(reaction, 1, sharing: true), isFalse);
    expect(p.resonates(reaction, 0, sharing: true), isFalse);
    expect(p.resonates(reaction, 2, sharing: false), isFalse);
    expect(
      p.resonates(const Signal(1, 0, 3, false), 2, sharing: true),
      isFalse,
    );
    expect(p.resonates(const Signal(1, 1, 3, true), 2, sharing: true), isFalse);
  });
  test('advertised window survives the 16-bit counter wrap', () {
    final s = Signal(0xffeeddcc, 65535, 4, true);
    final r = Signal.decode(s.encode(), 65536)!;
    expect((r.id, r.slot, r.level, r.shared), (s.id, s.slot, s.level, true));
    expect(Signal.decode(s.encode(), 65540), isNull);
    expect(Signal.decode(Uint8List(7), 65535), isNull);
  });
  test('uses only RSSI available during the reaction window', () {
    final p = Nearby(12)
      ..observe(4001, -70)
      ..observe(5001, -68)
      ..observe(5500, -71);
    expect(p.nearDuring(1), isTrue);
    p.observe(11000, -95);
    expect(p.nearDuring(1), isTrue);
    expect(p.nearDuring(4), isFalse);
    expect([0, 1, 5, 6, 11, 16, 21, 30].map(strength), [
      0,
      1,
      1,
      2,
      3,
      4,
      5,
      5,
    ]);
  });
  test('private profile withholds its tracks, song and artist', () {
    const profile = Profile(name: 'A', artist: 'Artist', song: 'Song');
    expect(profile.publicView, const Profile(name: 'A'));
  });
  test('one memory survives duplicate packets and can be favorited', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    const p = Profile(name: 'B', visible: true);
    final saved = await Future.wait(
      List.generate(3, (_) => db.remember('A', 'B', 500, 2, p)),
    );
    expect(saved.where((v) => v).length, 1);
    final m = (await db.history().first).single;
    await db.mark(m, true);
    expect((await db.history().first).single.favorite, true);
  });
}
