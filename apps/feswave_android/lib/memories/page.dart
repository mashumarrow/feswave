import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services.dart';
import '../profile/models.dart';
import '../ui/shared.dart';

class MemoriesPage extends ConsumerStatefulWidget {
  const MemoriesPage({super.key});
  @override
  ConsumerState<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends ConsumerState<MemoriesPage> {
  bool favorites = false;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      const PageHeading(
        'THE MOMENTS WE SHARED.',
        'Memory',
        Icons.favorite_border,
        'あの瞬間、同じ気持ちだった誰か。',
      ),
      WavePanel(
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_border, size: 36, color: pink),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('YOUR SHARED MOMENTS', style: captionStyle),
                    Text('音が止まっても、つながりは残る。'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('近くで同じ5秒間に盛り上がった参加者との記録です。', style: noteStyle),
          const Divider(),
          Text(
            '${ref.watch(historyProvider).value?.length ?? "—"}   MEMORIES',
            textAlign: TextAlign.center,
            style: captionStyle,
          ),
        ],
      ),
      const SizedBox(height: 14),
      Wrap(
        spacing: 8,
        children: [
          for (final only in [false, true])
            ChoiceChip(
              label: Text(only ? 'お気に入り' : 'すべて'),
              selected: favorites == only,
              onSelected: (_) => setState(() => favorites = only),
            ),
        ],
      ),
      const Text('公開を許可した参加者のみ表示', style: noteStyle),
      const SizedBox(height: 12),
      ...ref
          .watch(historyProvider)
          .when(
            data: (rows) {
              final list = rows.where((m) => !favorites || m.favorite);
              if (list.isEmpty) {
                return [
                  WavePanel(
                    center: true,
                    children: [
                      const Icon(Icons.favorite_border, color: lilac, size: 32),
                      const SizedBox(height: 10),
                      Text(favorites ? '大切なメモリを、お気に入りに。' : '最初の「同じ！」を見つけよう。'),
                      Text(
                        favorites
                            ? 'メモリのハートを押すと、ここに残せます。'
                            : '双方がプロフィールを公開し、近くで一緒にリアクションすると記録されます。',
                        style: noteStyle,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => context.go('/live'),
                        child: const Text('ライブに戻る  →'),
                      ),
                    ],
                  ),
                ];
              }
              return [
                for (final m in list)
                  Builder(
                    builder: (context) {
                      final p = Profile.fromJson(jsonDecode(m.person));
                      final at = DateTime.fromMillisecondsSinceEpoch(
                        m.slot * 5000,
                      );
                      return Card(
                        child: ListTile(
                          leading: Avatar(p),
                          title: Text(p.name),
                          subtitle: Text(
                            '${at.toString().substring(0, 16)} · Lv.${m.level}',
                          ),
                          onTap: () => showPerson(context, p),
                          trailing: IconButton(
                            tooltip: 'お気に入り',
                            icon: Icon(
                              m.favorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: pink,
                            ),
                            onPressed: () =>
                                ref.read(databaseProvider).mark(m, !m.favorite),
                          ),
                        ),
                      );
                    },
                  ),
              ];
            },
            error: (e, _) => [Text('$e')],
            loading: () => [const LinearProgressIndicator()],
          ),
      const WaveFooter(),
    ],
  );
}
