import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services.dart';
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
      if (mounted) notice(context, 'アカウントを更新できませんでした。通信状態を確認してやり直してください。');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountProvider);
    return account.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          _ProfileLoadError(onRetry: () => ref.invalidate(accountProvider)),
      data: (a) {
        final controller = ref.read(accountProvider.notifier);
        final theme = Theme.of(context).textTheme;
        final profile = a.profile;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('プロフィール', style: theme.headlineMedium),
            const SizedBox(height: 20),
            WavePanel(
              children: [
                Row(
                  children: [
                    Avatar(profile, size: 64),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile.name.isEmpty ? '名前は未設定' : profile.name,
                            style: theme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile.visible ? '曲とアイコンを公開中' : '曲とアイコンは非公開',
                            style: noteStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => context.go('/profile/edit'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(profile.name.isEmpty ? 'プロフィールを作成' : 'プロフィールを編集'),
                ),
              ],
            ),
            if (profile.name.isNotEmpty) ...[
              Text('好きな曲', style: theme.titleLarge),
              if (profile.tracks.isEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.music_note_outlined, color: lilac),
                  title: Text(profile.song.isEmpty ? '曲は未登録です' : profile.song),
                  subtitle: profile.artist.isEmpty
                      ? null
                      : Text(profile.artist),
                ),
              for (final t in profile.tracks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    t.trackId == profile.favoriteTrackId
                        ? Icons.stars_rounded
                        : Icons.music_note_outlined,
                    color: lilac,
                    semanticLabel: t.trackId == profile.favoriteTrackId
                        ? '代表曲'
                        : null,
                  ),
                  title: Text(t.trackName),
                  subtitle: Text(t.artistName),
                ),
              TextButton.icon(
                onPressed: () => context.go('/memories'),
                icon: const Icon(Icons.favorite_border),
                label: Text(
                  '共感メモリを見る（${ref.watch(historyProvider).value?.length ?? "—"}件）',
                ),
              ),
              const SizedBox(height: 20),
            ],
            WavePanel(
              padding: const EdgeInsets.all(22),
              children: [
                Text('アカウント', style: theme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  a.linked ? 'Googleアカウントでログイン中' : 'ゲストで利用中',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Text('Googleアカウントでプロフィールと好きな曲を引き継げます。', style: noteStyle),
                const SizedBox(height: 12),
                if (a.linked)
                  OutlinedButton(
                    onPressed: busy ? null : () => run(controller.refresh),
                    child: const Text('プロフィールを同期'),
                  ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => run(
                          a.linked ? controller.logout : controller.login,
                        ),
                  style: a.linked
                      ? null
                      : OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: const StadiumBorder(),
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                        ),
                  child: a.linked
                      ? const Text('ログアウト')
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/google-g.png',
                              width: 20,
                              height: 20,
                            ),
                            const SizedBox(width: 12),
                            const Flexible(child: Text('Googleでログイン')),
                          ],
                        ),
                ),
              ],
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        );
      },
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('プロフィールを読み込めませんでした。'),
        TextButton(onPressed: onRetry, child: const Text('再読み込み')),
      ],
    ),
  );
}

class ProfileEditor extends ConsumerWidget {
  const ProfileEditor({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(accountProvider)
      .when(
        data: (a) => _ProfileForm(a.profile),
        error: (_, _) =>
            _ProfileLoadError(onRetry: () => ref.invalidate(accountProvider)),
        loading: () => const Center(child: CircularProgressIndicator()),
      );
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm(this.profile);
  final Profile profile;
  @override
  ConsumerState<_ProfileForm> createState() => _Editor();
}

class _Editor extends ConsumerState<_ProfileForm> {
  final nameFocus = FocusNode();
  bool nameInvalid = false;
  late Profile draft;
  late final TextEditingController name, artist, song;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    draft = widget.profile;
    name = TextEditingController(text: draft.name);
    artist = TextEditingController(text: draft.artist);
    song = TextEditingController(text: draft.song);
  }

  @override
  void dispose() {
    nameFocus.dispose();
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
      setState(() => nameInvalid = true);
      nameFocus.requestFocus();
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
      context.go('/profile');
    } catch (e) {
      if (mounted) {
        notice(
          context,
          e is StateError ? e.message : '変更を保存できませんでした。もう一度お試しください。',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: saving ? null : () => context.go('/profile'),
          icon: const Icon(Icons.arrow_back, size: 18),
          label: const Text('キャンセル'),
        ),
      ),
      Text(
        draft.name.isEmpty ? 'プロフィールを作成' : 'プロフィール編集',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 20),
      Row(
        children: [
          Avatar(draft.copyWith(name: name.text.trim()), size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.text.trim().isEmpty ? 'あなたの名前' : name.text.trim()),
                const Text('好きな曲のジャケットをアイコンに', style: noteStyle),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextField(
        controller: name,
        focusNode: nameFocus,
        onChanged: (_) => setState(
          () => nameInvalid = nameInvalid && name.text.trim().isEmpty,
        ),
        maxLength: 20,
        decoration: InputDecoration(
          labelText: 'ニックネーム',
          errorText: nameInvalid ? 'ニックネームを入力してください' : null,
        ),
      ),
      const Text('アイコンの色', style: noteStyle),
      Wrap(
        spacing: 9,
        children: [
          for (final entry in const {
            'pink': 'ピンク',
            'purple': '紫',
            'blue': '青',
            'orange': 'オレンジ',
          }.entries)
            ChoiceChip(
              label: Text(entry.value),
              avatar: Icon(Icons.circle, color: tint(entry.key), size: 16),
              selected: draft.color == entry.key,
              onSelected: (_) =>
                  setState(() => draft = draft.copyWith(color: entry.key)),
            ),
        ],
      ),
      const Divider(height: 36),
      Text('好きな曲', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 4),
      Text(
        draft.tracks.isEmpty
            ? '曲を検索するか、曲名とアーティスト名を入力してください。'
            : '星を押して代表曲を選べます（${draft.tracks.length}/20曲）。',
        style: noteStyle,
      ),
      const SizedBox(height: 12),
      for (final t in draft.tracks)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t.trackName),
          subtitle: Text(t.artistName),
          leading: IconButton(
            tooltip: t.trackId == draft.favoriteTrackId ? '現在の代表曲' : '代表曲にする',
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
        const SizedBox(height: 16),
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
      Text('公開設定', style: Theme.of(context).textTheme.titleLarge),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('好きな曲とアイコンを公開'),
        subtitle: const Text(
          'オンにすると、近くの参加者に好きな曲とジャケットを表示し、共感メモリを残せます。名前と色は常に表示されます。',
        ),
        value: draft.visible,
        onChanged: (v) => setState(() => draft = draft.copyWith(visible: v)),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: saving ? null : save,
        child: Text(saving ? '保存中' : '変更を保存'),
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

  void reset() {
    cancel?.cancel();
    setState(() {
      loading = false;
      tracks = [];
      msg = '';
    });
  }

  Future<void> search(String term) async {
    cancel?.cancel();
    if (term.trim().isEmpty) {
      reset();
      return;
    }
    final token = CancelToken();
    cancel = token;

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
        setState(() => msg = '曲を検索できませんでした。通信状態を確認して、もう一度検索してください。');
      }
    } finally {
      if (mounted && !token.isCancelled) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    heightFactor: .8,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: (_) => reset(),
            onSubmitted: search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              labelText: '曲名・アーティストで検索',
            ),
          ),
          if (loading) const LinearProgressIndicator(semanticsLabel: '曲を検索中'),
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
