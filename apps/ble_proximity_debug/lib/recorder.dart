import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'measurement.dart';

class Recorder {
  late File csv;
  late File summaries;
  List<String> history = [];
  String observer = '';
  int sequence = 0;
  Trial? trial;
  Future<void> open() async {
    final dir = await getApplicationDocumentsDirectory();
    csv = File('${dir.path}/proximity.csv');
    summaries = File('${dir.path}/results.txt');
    if (!csv.existsSync()) {
      csv.writeAsStringSync(
        'utc,event,observer,peer,session_ms,trial,distance_m,carry,phase,rssi_dbm\n',
      );
    }
    if (summaries.existsSync()) {
      history = summaries.readAsLinesSync().reversed.toList();
    }
  }

  void log(String event, int ms, {String peer = '', int? rssi}) {
    final t = trial;
    final row = [
      DateTime.now().toUtc().toIso8601String(),
      event,
      observer,
      peer,
      ms,
      t?.id,
      t?.distance,
      t?.carry,
      t?.phase(ms),
      rssi,
    ];
    csv.writeAsStringSync(
      '${row.map((v) => v ?? '').join(',')}\n',
      mode: FileMode.append,
    );
  }

  void startTrial(int ms, int distance, String carry, Iterable<String> peers) {
    trial = Trial(++sequence, ms, distance, carry);
    for (final id in peers) {
      trial!.readings[id] = [];
    }
    log('trial_start', ms);
  }

  void finish(int ms, {bool cancelled = false}) {
    final t = trial;
    if (t == null) return;
    log(cancelled ? 'trial_cancelled' : 'trial_end', ms);
    final rows = t.readings.entries.map((entry) {
      final v = entry.value;
      if (v.isEmpty) return '${entry.key}  0件';
      return '${entry.key}  ${median(v)} dBm（${v.reduce(min)}〜${v.reduce(max)}） ${v.length}件';
    }).toList();
    final result =
        '${DateTime.now().toLocal().toString().substring(0, 19)}  $observer #${t.id}  ${t.distance} m ${t.carry == "hand" ? "手持ち" : "ポケット"}  ${cancelled
            ? "中断"
            : rows.isEmpty
            ? "受信0件"
            : ""} ${rows.join(" / ")}';
    summaries.writeAsStringSync('$result\n', mode: FileMode.append);
    history.insert(0, result);
    trial = null;
  }
}
