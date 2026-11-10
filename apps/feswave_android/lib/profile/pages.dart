import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services.dart';
import '../live/session.dart';
import '../ui/shared.dart';
import 'models.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});
  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  bool busy = false;
  Future<void> run(Future<void> Function() f) async {
    setState(() => busy = true);
    try {
      await f();
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    return account.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (a) {
        final controller = ref.read(accountProvider.notifier);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              a.profile.name.isEmpty ? 'プロフィールを登録' : a.profile.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Avatar(a.profile, size: 78),
            ),
            const SizedBox(height: 12),
            Text(a.profile.visible ? '好きな曲を公開中' : '好きな曲は非公開'),
            FilledButton.tonalIcon(
              onPressed: busy ? null : () => context.go('/profile/edit'),
              icon: const Icon(Icons.edit),
              label: const Text('プロフィールを編集'),
            ),
            const Divider(height: 32),
            Text('お気に入りの曲', style: Theme.of(context).textTheme.titleLarge),
            if (a.profile.tracks.isEmpty)
              Text(a.profile.song.isEmpty ? '登録した曲はありません' : a.profile.song),
            for (final t in a.profile.tracks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.trackName),
                subtitle: Text(t.artistName),
                leading: Icon(
                  t.trackId == a.profile.favoriteTrackId
                      ? Icons.star
                      : Icons.music_note,
                  color: lilac,
                ),
              ),
            const Divider(height: 32),
            if (a.linked)
              OutlinedButton(
                onPressed: busy ? null : () => run(controller.refresh),
                child: const Text('プロフィールを同期'),
              ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => run(a.linked ? controller.logout : controller.login),
              child: Text(a.linked ? 'ログアウト' : 'Googleでログイン'),
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        );
      },
    );
  }
}

class ProfileEditor extends ConsumerStatefulWidget {
  const ProfileEditor({super.key, this.joinAfterSave = false});
  final bool joinAfterSave;
  @override
  ConsumerState<ProfileEditor> createState() => _Editor();
}

class _Editor extends ConsumerState<ProfileEditor> {
  late Profile draft;
  late final TextEditingController name, artist, song;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    draft = ref.read(accountProvider).requireValue.profile;
    name = TextEditingController(text: draft.name);
    artist = TextEditingController(text: draft.artist);
    song = TextEditingController(text: draft.song);
  }

  @override
  void dispose() {
    name.dispose();
    artist.dispose();
    song.dispose();
    super.dispose();
  }

  Future<void> addTrack() async {
    final track = await showModalBottomSheet<Track>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const MusicSearch(),
    );
    if (!mounted ||
        track == null ||
        draft.tracks.any((t) => t.trackId == track.trackId)) {
      return;
    }
    setState(
      () => draft = draft.copyWith(
        tracks: [...draft.tracks, track],
        favoriteTrackId: draft.favoriteTrackId ?? track.trackId,
      ),
    );
  }

  Future<void> save() async {
    if (name.text.trim().isEmpty) {
      notice(context, 'ニックネームを入力してください');
      return;
    }
    setState(() => saving = true);
    try {
      await ref
          .read(accountProvider.notifier)
          .save(
            draft.copyWith(
              name: name.text.trim(),
              song: draft.favorite?.trackName ?? song.text.trim(),
              artist: draft.favorite?.artistName ?? artist.text.trim(),
            ),
          );
      if (!mounted) return;
      if (widget.joinAfterSave) {
        await ref.read(liveProvider.notifier).join();
      }
      if (mounted) context.go(widget.joinAfterSave ? '/live' : '/profile');
    } catch (e) {
      if (mounted) notice(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text('プロフィール編集', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 16),
      TextField(
        controller: name,
        maxLength: 20,
        decoration: const InputDecoration(labelText: 'ニックネーム'),
      ),
      Wrap(
        spacing: 9,
        children: [
          for (final c in ['pink', 'purple', 'blue', 'orange'])
            IconButton(
              tooltip: c,
              onPressed: () => setState(() => draft = draft.copyWith(color: c)),
              icon: Icon(
                draft.color == c ? Icons.check_circle : Icons.circle,
                color: tint(c),
              ),
            ),
        ],
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('好きな曲とアイコンを公開'),
        subtitle: const Text('近くの人と共感メモリを残す'),
        value: draft.visible,
        onChanged: (v) => setState(() => draft = draft.copyWith(visible: v)),
      ),
      const Divider(),
      for (final t in draft.tracks)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.trackName),
          subtitle: Text(t.artistName),
          leading: IconButton(
            tooltip: '代表曲にする',
            onPressed: () => setState(
              () => draft = draft.copyWith(favoriteTrackId: t.trackId),
            ),
            icon: Icon(
              t.trackId == draft.favoriteTrackId
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
          trailing: IconButton(
            tooltip: '曲を削除',
            icon: const Icon(Icons.close),
            onPressed: () {
              final rest = draft.tracks.where((v) => v != t).toList();
              setState(
                () => draft = draft.copyWith(
                  tracks: rest,
                  favoriteTrackId: draft.favoriteTrackId == t.trackId
                      ? rest.firstOrNull?.trackId
                      : draft.favoriteTrackId,
                ),
              );
            },
          ),
        ),
      OutlinedButton.icon(
        onPressed: draft.tracks.length >= 20 ? null : addTrack,
        icon: const Icon(Icons.search),
        label: const Text('曲を検索して追加'),
      ),
      if (draft.tracks.isEmpty) ...[
        TextField(
          controller: artist,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'アーティスト名（手入力）'),
        ),
        TextField(
          controller: song,
          maxLength: 60,
          decoration: const InputDecoration(labelText: '曲名（手入力）'),
        ),
      ],
      const SizedBox(height: 16),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? '保存中' : '変更を保存'),
      ),
      TextButton(
        onPressed: saving ? null : () => context.go('/profile'),
        child: const Text('キャンセル'),
      ),
    ],
  );
}

class MusicSearch extends ConsumerStatefulWidget {
  const MusicSearch({super.key});
  @override
  ConsumerState<MusicSearch> createState() => _Search();
}

class _Search extends ConsumerState<MusicSearch> {
  CancelToken? cancel;
  bool loading = false;
  String msg = '';
  List<Track> tracks = [];
  @override
  void dispose() {
    cancel?.cancel();
    super.dispose();
  }

  Future<void> search(String term) async {
    cancel?.cancel();
    final token = CancelToken();
    cancel = token;
    if (term.trim().isEmpty) return;
    setState(() {
      loading = true;
      msg = '';
      tracks = [];
    });
    try {
      final list = await ref.read(apiProvider).search(term.trim(), token);
      if (mounted && !token.isCancelled) {
        setState(() {
          tracks = list;
          msg = list.isEmpty ? '曲が見つかりません' : '';
        });
      }
    } catch (e) {
      if (mounted && !token.isCancelled) {
        setState(() => msg = '曲検索に失敗しました。接続先を確認して再検索してください。');
      }
    } finally {
      if (mounted && !token.isCancelled) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .8,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '曲名・アーティストで検索',
            ),
          ),
          if (loading) const LinearProgressIndicator(),
          if (msg.isNotEmpty) Text(msg),
          Expanded(
            child: ListView(
              children: [
                for (final t in tracks)
                  ListTile(
                    title: Text(t.trackName),
                    subtitle: Text(t.artistName),
                    trailing: const Icon(Icons.add),
                    onTap: () => Navigator.pop(context, t),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
