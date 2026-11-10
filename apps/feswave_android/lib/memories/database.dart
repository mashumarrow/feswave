import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import '../profile/models.dart';

part 'database.g.dart';

class Memories extends Table {
  TextColumn get session => text()();
  TextColumn get peer => text()();
  IntColumn get slot => integer()();
  IntColumn get level => integer()();
  TextColumn get person => text()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  @override
  Set<Column> get primaryKey => {session, peer, slot};
}

class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Memories, Settings])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'feswave'));
  @override
  int get schemaVersion => 1;
  Future<String?> setting(String k) async => (await (select(
    settings,
  )..where((t) => t.key.equals(k))).getSingleOrNull())?.value;
  Future<void> put(String k, String v) => into(
    settings,
  ).insertOnConflictUpdate(SettingsCompanion.insert(key: k, value: v));
  Stream<List<Memory>> history() =>
      (select(memories)..orderBy([(m) => OrderingTerm.desc(m.slot)])).watch();
  Future<bool> remember(
    String session,
    String peer,
    int slot,
    int level,
    Profile profile,
  ) async {
    return transaction(() async {
      await into(memories).insert(
        MemoriesCompanion.insert(
          session: session,
          peer: peer,
          slot: slot,
          level: level,
          person: jsonEncode(profile.publicView),
        ),
        mode: InsertMode.insertOrIgnore,
      );
      final changes = await customSelect('SELECT changes() AS n').getSingle();
      return changes.read<int>('n') == 1;
    });
  }

  Future<void> enrich(String session, String peer, int slot, Profile p) =>
      (update(memories)..where(
            (r) =>
                r.session.equals(session) &
                r.peer.equals(peer) &
                r.slot.equals(slot),
          ))
          .write(MemoriesCompanion(person: Value(jsonEncode(p.publicView))));
  Future<void> mark(Memory m, bool value) =>
      (update(memories)..where(
            (r) =>
                r.session.equals(m.session) &
                r.peer.equals(m.peer) &
                r.slot.equals(m.slot),
          ))
          .write(MemoriesCompanion(favorite: Value(value)));
}
