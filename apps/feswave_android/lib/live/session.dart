import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../services.dart';
import '../profile/models.dart';
import 'protocol.dart';
import 'radio.dart';

final liveProvider = NotifierProvider<LiveSession, int>(LiveSession.new);

enum Gate { checking, blocked, ready }

class LiveSession extends Notifier<int> with WidgetsBindingObserver {
  late final LiveRadio radio;
  final people = <int, Nearby>{};
  final taps = <int, int>{};
  final effects = StreamController<int>.broadcast();
  final reads = <(int, bool), Future<Profile>>{};
  final retryAfter = <int, int>{};
  final processed = <String>{};
  Future<void> _operations = Future.value(), _gatt = Future.value();
  Timer? timer;
  Gate gate = Gate.checking;
  String message = '';
  bool active = false, foreground = true, busy = false, refreshing = false;
  int id = 0, lastSlot = -1, epoch = 0;
  int get now => DateTime.now().millisecondsSinceEpoch;
  Profile get me => ref.read(accountProvider).value?.profile ?? const Profile();
  @override
  int build() {
    radio = LiveRadio(received, (e) {
      block(e);
    });
    WidgetsBinding.instance.addObserver(this);
    ref.listen(accountProvider, (_, next) {
      final profile = next.value?.profile;
      if (profile == null) return;
      radio.publish(profile);
      if (!profile.visible) taps.clear();
    });
    ref.onDispose(() {
      timer?.cancel();
      WidgetsBinding.instance.removeObserver(this);
      for (final s in radio.subscriptions) {
        s.cancel();
      }
      unawaited(radio.stop());
      effects.close();
    });
    return 0;
  }

  void update() {
    if (ref.mounted) state++;
  }

  Future<void> _serial(Future<void> Function() action) {
    final task = _operations.then((_) => action());
    _operations = task.catchError((Object _) {});
    return task;
  }

  Future<void> check({bool request = true}) async {
    if (busy) return;
    busy = true;
    update();
    try {
      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ];
      final states = request
          ? (await permissions.request()).values
          : await Future.wait(permissions.map((p) => p.status));
      if (states.any((p) => !p.isGranted)) {
        throw StateError('付近のデバイスと位置情報の権限が必要です');
      }
      if (await Permission.bluetooth.serviceStatus.isDisabled) {
        throw StateError('Bluetoothをオンにしてください');
      }
      if (await Permission.locationWhenInUse.serviceStatus.isDisabled) {
        throw StateError('位置情報をオンにしてください');
      }
      await ref.read(accountProvider.future);
      gate = Gate.ready;
      message = '';
      if (foreground && !active) await _serial(_start);
    } catch (e) {
      block(e.toString());
    } finally {
      busy = false;
      update();
    }
  }

  void block(String reason) {
    gate = Gate.blocked;
    message = reason;
    active = false;
    epoch++;
    timer?.cancel();
    unawaited(_serial(_stop));
    update();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      foreground = false;
      active = false;
      epoch++;
      timer?.cancel();
      unawaited(_serial(_stop));
    } else if (state == AppLifecycleState.resumed) {
      foreground = true;
      unawaited(check(request: false));
    }
  }

  Future<void> _start() async {
    if (!foreground || active || gate != Gate.ready) return;
    final generation = epoch;
    id = Random.secure().nextInt(1 << 32);
    people.clear();
    reads.clear();
    retryAfter.clear();
    processed.clear();
    taps.clear();
    lastSlot = now ~/ slotMs;
    radio.publish(me);
    await radio.start(_signal(lastSlot));
    if (!foreground || generation != epoch) {
      await _stop();
      return;
    }
    await WakelockPlus.enable();
    active = true;
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => tick());
    update();
  }

  Future<void> _stop() async {
    active = false;
    timer?.cancel();
    try {
      await radio.stop();
    } catch (e) {
      message = 'BLE停止 · $e';
    } finally {
      await WakelockPlus.disable();
      people.clear();
      update();
    }
  }

  Signal _signal(int slot) => Signal(
    id,
    slot - 1,
    strength(taps[slot - 1] ?? 0),
    me.visible,
    radio.revision,
  );
  void tap() {
    if (!active) return;
    final slot = now ~/ slotMs;
    taps[slot] = (taps[slot] ?? 0) + 1;
    update();
  }

  void tick() {
    if (!active) return;
    final time = now, slot = time ~/ slotMs;
    people.removeWhere((_, p) => time - p.last >= 15000);
    if (slot != lastSlot && !refreshing) {
      lastSlot = slot;
      refreshing = true;
      for (final p in people.values) {
        p.shown = p.medianAt(time);
        if (kDebugMode) {
          debugPrint(
            "FESWAVE window=$slot peer=${hexId(p.id)} median=${p.shown} ageMs=${time - p.last}",
          );
        }
      }
      taps.removeWhere((s, _) => s < slot - 2);
      final generation = epoch;
      unawaited(
        _serial(() async {
              if (active && generation == epoch) {
                await radio.advertise(_signal(slot));
              }
            })
            .catchError((Object e) {
              block('広告更新に失敗しました · $e');
            })
            .whenComplete(() => refreshing = false),
      );
    }
    update();
  }

  void received(Signal s, int rssi) {
    if (!active) return;
    final p = people.putIfAbsent(s.id, () => Nearby(s.id));
    final time = now;
    p.observe(time, rssi);
    p.shown ??= p.medianAt(time);
    if (p.shared != s.shared || p.revision != s.revision) {
      p.revision = s.revision;
      p.profile = null;
      p.hasDetails = false;
      retryAfter.remove(s.id);
    }
    p.shared = s.shared;
    p.level = s.level;
    if (p.profile == null && (retryAfter[s.id] ?? 0) < time) {
      retryAfter[s.id] = time + 30000;
      unawaited(
        profileFor(s.id, summary: true).catchError((Object e) {
          if (kDebugMode) debugPrint('FESWAVE GATT failed: $e');
          retryAfter[s.id] = now + 4000;
          return Profile(name: hexId(s.id));
        }),
      );
    }
    final mine = strength(taps[s.slot] ?? 0);
    if (p.resonates(s, mine, sharing: me.visible)) {
      final key = '${s.slot}.${s.id}';
      if (processed.add(key)) unawaited(_remember(p, s.slot, mine, key));
    }
  }

  Future<Profile> profileFor(int peer, {bool summary = false}) {
    final p = people[peer];
    if (p == null) return Future.error(StateError('参加者が範囲外です'));
    if ((summary || p.hasDetails) && p.profile != null) {
      return Future.value(p.profile!);
    }
    final key = (peer, summary);
    final existing = reads[key];
    if (existing != null) return existing;
    final generation = epoch;
    final task = _gatt.then((_) async {
      if (generation != epoch || !active) throw StateError('ライブが終了しました');
      final revision = p.revision;
      final profile = await radio.readProfile(peer, summary: summary);
      if (generation != epoch || !active) throw StateError('ライブが終了しました');
      if (kDebugMode) {
        debugPrint(
          "FESWAVE profile=${hexId(peer)} tracks=${profile.tracks.length}",
        );
      }
      if (p.revision != revision || !identical(people[peer], p)) {
        throw StateError("プロフィールが更新されました");
      }
      final display = profile.name.trim().isEmpty
          ? profile.copyWith(name: hexId(peer))
          : profile;
      p.profile = p.shared
          ? display
          : display.copyWith(visible: false).publicView;
      p.hasDetails = !summary;
      update();
      return p.profile!;
    });
    reads[key] = task;
    _gatt = task.then<void>((_) {}).catchError((Object _) {}).whenComplete(() {
      if (identical(reads[key], task)) reads.remove(key);
    });
    return task;
  }

  Future<void> _remember(Nearby p, int slot, int level, String key) async {
    final session = hexId(id);
    try {
      final snapshot = p.profile ?? Profile(name: hexId(p.id));
      final added = await ref
          .read(databaseProvider)
          .remember(session, hexId(p.id), slot, level, snapshot);
      if (added && active && hexId(id) == session) effects.add(p.id);
      if (added && !p.hasDetails) {
        try {
          final detail = await profileFor(p.id);
          if (detail.visible) {
            await ref
                .read(databaseProvider)
                .enrich(session, hexId(p.id), slot, detail);
          }
        } catch (_) {
          /* The encounter remains available even if the peer has left. */
        }
      }
    } catch (e) {
      processed.remove(key);
      message = 'メモリ保存に失敗しました · $e';
      update();
    }
  }
}
