import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:bluetooth_low_energy/bluetooth_low_energy.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'measurement.dart';
import 'recorder.dart';

final service = UUID.fromString('d11a7820-5694-45af-b72b-8a568ab65f07');
String hexId(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toUpperCase();

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});
  @override
  State<DebugScreen> createState() => _Screen();
}

class _Screen extends State<DebugScreen> with WidgetsBindingObserver {
  final central = CentralManager();
  final peripheral = PeripheralManager();
  final peers = <String, Peer>{};
  final rec = Recorder();
  final watch = Stopwatch();
  late final StreamSubscription<DiscoveredEventArgs> discoveries;
  late final StreamSubscription<BluetoothLowEnergyStateChangedEventArgs>
  changes;
  Timer? timer;
  bool ready = false,
      busy = false,
      active = false,
      advertising = false,
      scanning = false,
      cancelled = false;
  String message = '準備中', carry = 'hand';
  int distance = 1;
  int get ms => watch.elapsedMilliseconds;
  void refresh() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    discoveries = central.discovered.listen(observe);
    changes = central.stateChanged.listen((e) {
      if (e.state == BluetoothLowEnergyState.poweredOff && active) {
        unawaited(stop('Bluetoothが無効です'));
      }
    });
    rec
        .open()
        .then((_) {
          ready = true;
          message = '開始できます';
          refresh();
        })
        .catchError((Object e) {
          message = '保存先エラー $e';
          refresh();
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      cancelled = true;
      if (active) unawaited(stop('画面を離れたため停止'));
    }
  }

  void ensureForeground() {
    if (cancelled) throw StateError('画面を離れたため停止');
  }

  Future<void> start() async {
    if (busy || active) return;
    busy = true;
    cancelled = false;
    message = '権限を確認中';
    refresh();
    String step = '準備';
    try {
      final grants = await [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse,
      ].request();
      if (grants.values.any((p) => !p.isGranted)) {
        throw StateError('権限が拒否されました。設定で付近のデバイスと位置情報を許可してください');
      }
      // Android can pause our activity while it displays its permission dialog.
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        cancelled = false;
      }
      ensureForeground();
      if (central.state == BluetoothLowEnergyState.poweredOff ||
          await Permission.bluetooth.serviceStatus.isDisabled) {
        throw StateError('Bluetoothが無効です');
      }
      if (await Permission.locationWhenInUse.serviceStatus.isDisabled) {
        throw StateError('位置情報をオンにしてください');
      }
      ensureForeground();
      final rnd = Random.secure();
      final bytes = Uint8List.fromList(
        List.generate(4, (_) => rnd.nextInt(256)),
      );
      rec.observer = hexId(bytes);
      rec.sequence = 0;
      peers.clear();
      step = '広告開始';
      await peripheral.startAdvertising(
        Advertisement(serviceData: {service: bytes}),
      );
      advertising = true;
      ensureForeground();
      step = 'スキャン開始';
      await central.startDiscovery();
      scanning = true;
      ensureForeground();
      step = '記録開始';
      await WakelockPlus.enable();
      ensureForeground();
      watch
        ..reset()
        ..start();
      rec.log('session_start', ms);
      active = true;
      message = '測定中';
      timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
        tick();
        refresh();
      });
    } catch (e) {
      message = '$step 失敗 · $e';
      await release();
    } finally {
      busy = false;
      refresh();
    }
  }

  void observe(DiscoveredEventArgs event) {
    if (!active) return;
    final data = event.advertisement.serviceData[service];
    if (data == null || data.length != 4) return;
    final id = hexId(data);
    if (id == rec.observer) return;
    final now = ms;
    tick();
    (peers[id] ??= Peer()).observe(now, event.rssi);
    rec.trial?.observe(now, id, event.rssi);
    rec.log('sample', now, peer: id, rssi: event.rssi);
  }

  void tick() {
    final now = ms;
    for (final peer in peers.values) {
      peer.expire(now);
    }
    if (rec.trial case final t?) {
      if (now - t.start >= 20000) rec.finish(now);
    }
  }

  Future<void> release() async {
    for (final action in [
      if (scanning) central.stopDiscovery,
      if (advertising) peripheral.stopAdvertising,
      WakelockPlus.disable,
    ]) {
      try {
        await action();
      } catch (e) {
        message += ' · 停止エラー $e';
      }
    }
    advertising = false;
    scanning = false;
  }

  Future<void> stop(String reason) async {
    if (!active) return;
    active = false;
    busy = true;
    timer?.cancel();
    watch.stop();
    message = reason;
    try {
      tick();
      rec.finish(ms, cancelled: true);
      rec.log('session_stop', ms);
    } finally {
      await release();
      busy = false;
      refresh();
    }
  }

  @override
  void dispose() {
    cancelled = true;
    WidgetsBinding.instance.removeObserver(this);
    if (active) unawaited(stop('停止'));
    discoveries.cancel();
    changes.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = peers.entries.toList();
    int group(Peer p) => p.samples.length >= 3
        ? 0
        : p.samples.isNotEmpty
        ? 1
        : 2;
    entries.sort((a, b) {
      final g = group(a.value).compareTo(group(b.value));
      if (g != 0) return g;
      if (group(a.value) == 0) {
        return b.value.recent!.compareTo(a.value.recent!);
      }
      return a.key.compareTo(b.key);
    });
    final t = rec.trial;
    return Scaffold(
      appBar: AppBar(title: const Text('BLE 近接測定')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              '自端末  ${rec.observer.isEmpty ? "—" : rec.observer}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              '広告 ${advertising ? "送信中" : "停止"}　スキャン ${scanning ? "実行中" : "停止"}',
            ),
            Text(message),
            FilledButton(
              onPressed: !ready || busy
                  ? null
                  : active
                  ? () => stop('停止・保存済み')
                  : start,
              child: Text(active ? '測定停止' : '測定開始'),
            ),
            if (active && entries.isEmpty) const Text('相手の広告を待っています（受信0件）'),
            for (final e in entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${e.key}　${["近接順", "集計待ち", "受信待ち"][group(e.value)]}',
                ),
                subtitle: Text(
                  '生 ${e.value.raw} dBm　中央値 ${e.value.recent ?? "—"} dBm\n直近5秒 ${e.value.samples.length}件　最終受信 ${(ms - e.value.lastMs) ~/ 1000}秒前',
                ),
              ),
            const Divider(),
            Wrap(
              spacing: 8,
              children: [
                for (final d in [1, 3])
                  ChoiceChip(
                    label: Text('$d m'),
                    selected: distance == d,
                    onSelected: t != null
                        ? null
                        : (_) => setState(() => distance = d),
                  ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: [
                for (final c in ['hand', 'pocket'])
                  ChoiceChip(
                    label: Text(c == 'hand' ? '手持ち' : 'ポケット'),
                    selected: carry == c,
                    onSelected: t != null
                        ? null
                        : (_) => setState(() => carry = c),
                  ),
              ],
            ),
            FilledButton.tonal(
              onPressed: active && t == null
                  ? () => setState(
                      () => rec.startTrial(ms, distance, carry, peers.keys),
                    )
                  : null,
              child: Text(
                t == null
                    ? '20秒記録'
                    : '${ms - t.start < 5000 ? "安定待ち" : "集計中"}　残り ${max(0, 20 - (ms - t.start) ~/ 1000)}秒',
              ),
            ),
            OutlinedButton(
              onPressed: !ready || busy || active
                  ? null
                  : () async {
                      try {
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(rec.csv.path, mimeType: 'text/csv')],
                          ),
                        );
                      } catch (e) {
                        message = 'CSV共有失敗 $e';
                        refresh();
                      }
                    },
              child: const Text('CSVを共有'),
            ),
            if (ready && rec.history.isNotEmpty) const Text('試行結果　中央値（最小〜最大）'),
            if (ready)
              for (final line in rec.history)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(line),
                ),
          ],
        ),
      ),
    );
  }
}
