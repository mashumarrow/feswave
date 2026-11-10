import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'memories/database.dart';
import 'profile/models.dart';
import 'profile/api.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
final apiProvider = Provider<ProfileApi>((ref) => ProfileApi());
typedef Account = ({Profile profile, bool linked});
final accountProvider = AsyncNotifierProvider<AccountController, Account>(
  AccountController.new,
  retry: (_, _) => null,
);

class AccountController extends AsyncNotifier<Account> {
  @override
  Future<Account> build() async {
    final db = ref.read(databaseProvider);
    final raw = await db.setting('account');
    if (raw == null) return (profile: const Profile(), linked: false);
    final v = jsonDecode(raw);
    return (
      profile: Profile.fromJson(v['profile']),
      linked: v['linked'] == true,
    );
  }

  Future<void> _store(Profile p, bool linked) async {
    await ref
        .read(databaseProvider)
        .put('account', jsonEncode({'profile': p, 'linked': linked}));
    state = AsyncData((profile: p, linked: linked));
  }

  Future<void> save(Profile p) async {
    final linked = state.requireValue.linked;
    if (linked) {
      final api = ref.read(apiProvider);
      if ((await api.session())['account']['google'] != true) {
        throw StateError('ログインの有効期限が切れました。再ログインしてください');
      }
      p = await api.save(p);
    }
    await _store(p, linked);
  }

  Future<void> login() async => _store(
    await ref.read(apiProvider).login(state.requireValue.profile),
    true,
  );
  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    await _store(const Profile(), false);
  }

  Future<void> refresh() async {
    final data = await ref.read(apiProvider).session();
    if (data['account']['google'] != true) throw StateError('再ログインしてください');
    await _store(Profile.fromJson(data['user']), true);
  }
}

final historyProvider = StreamProvider<List<Memory>>(
  (ref) => ref.watch(databaseProvider).history(),
);
