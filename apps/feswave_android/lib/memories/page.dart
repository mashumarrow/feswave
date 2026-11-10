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
    padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 22),
    children: [
      const PageHeading(
        'THE MOMENTS WE SHARED.',
        'Memory',
        'heart',
        'あの瞬間、同じ気持ちだった誰か。',
      ),
      WavePanel(
        padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 23),
        children: [
          const Row(
            children: [
              WaveIcon('heart', size: 38, color: Color(0xfff087ec)),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR SHARED MOMENTS',
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1,
                        color: Color(0xffa397b6),
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      '音が止まっても、つながりは残る。',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '近くで同じ5秒間に盛り上がった参加者との記録です。',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.8,
                        color: Color(0xff9783a7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${ref.watch(historyProvider).value?.length ?? "—"}',
                style: const TextStyle(fontSize: 32, color: Color(0xffedbbfa)),
              ),
              const SizedBox(width: 12),
              const Text('MEMORIES', style: captionStyle),
            ],
          ),
        ],
      ),
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
      const SizedBox(height: 22),
      ...ref
          .watch(historyProvider)
          .when(
            data: (rows) {
              final list = rows.where((m) => !favorites || m.favorite);
              if (list.isEmpty) {
                return [
                  WavePanel(
                    center: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 40,
                    ),
                    children: [
                      const Icon(Icons.favorite_border, color: lilac, size: 32),
                      const SizedBox(height: 10),
                      Text(favorites ? 'お気に入りはまだありません' : '共感メモリはまだありません'),
                      Text(
                        favorites
                            ? 'メモリのハートを押すと、ここに残せます。'
                            : 'お互いに曲を公開して、近くで同じ5秒間に同じくらいタップすると記録されます。',
                        style: noteStyle,
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => favorites
                            ? setState(() => favorites = false)
                            : context.go('/live'),
                        child: Text(favorites ? 'すべてのメモリを見る' : 'ライブへ'),
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
                            tooltip: m.favorite ? 'お気に入りから外す' : 'お気に入りに追加',
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
            error: (_, _) => [
              const Text('メモリを読み込めませんでした。'),
              TextButton(
                onPressed: () => ref.invalidate(historyProvider),
                child: const Text('再読み込み'),
              ),
            ],
            loading: () => [const LinearProgressIndicator()],
          ),
      const WaveFooter(),
    ],
  );
}
