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
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final theme = Theme.of(context).textTheme;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('共感メモリ', style: theme.headlineMedium),
                    if (history.hasValue)
                      Text('${history.requireValue.length}件', style: noteStyle),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('一緒に盛り上がった人と、その人の好きな曲。', style: noteStyle),
                const SizedBox(height: 18),
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
              ],
            ),
          ),
        ),
        history.when(
          data: (rows) {
            final list = favorites
                ? rows.where((m) => m.favorite).toList()
                : rows;
            if (list.isEmpty) {
              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                sliver: SliverToBoxAdapter(
                  child: WavePanel(
                    center: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 32,
                    ),
                    children: [
                      Icon(
                        favorites ? Icons.favorite_outline : Icons.graphic_eq,
                        color: pink,
                        size: 36,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        favorites ? 'お気に入りはまだありません' : '共感メモリはまだありません',
                        style: theme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        favorites
                            ? 'メモリのハートを押すと、ここに残せます。'
                            : 'お互いに曲を公開して、近くで同じ5秒間に同じくらいタップすると記録されます。',
                        style: noteStyle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => favorites
                            ? setState(() => favorites = false)
                            : context.go('/live'),
                        child: Text(favorites ? 'すべてのメモリを見る' : 'ライブへ'),
                      ),
                    ],
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final memory = list[index];
                  final date = _slotDate(memory.slot);
                  final firstOfDay =
                      index == 0 ||
                      !DateUtils.isSameDay(
                        date,
                        _slotDate(list[index - 1].slot),
                      );
                  final p = Profile.fromJson(jsonDecode(memory.person));
                  final song = p.favorite?.trackName ?? p.song;
                  final time = MaterialLocalizations.of(context)
                      .formatTimeOfDay(
                        TimeOfDay.fromDateTime(date),
                        alwaysUse24HourFormat: true,
                      );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (firstOfDay)
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Text(
                            '${date.year}年${date.month}月${date.day}日',
                            style: theme.titleMedium,
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Avatar(p),
                        title: Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (song.isNotEmpty)
                              Text(
                                song,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              '$time · 反応 Lv.${memory.level}',
                              style: noteStyle,
                            ),
                          ],
                        ),
                        onTap: () => showPerson(context, p),
                        trailing: IconButton(
                          tooltip: memory.favorite ? 'お気に入りから外す' : 'お気に入りに追加',
                          icon: Icon(
                            memory.favorite
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: memory.favorite ? pink : null,
                          ),
                          onPressed: () => ref
                              .read(databaseProvider)
                              .mark(memory, !memory.favorite),
                        ),
                      ),
                      const Divider(height: 1),
                    ],
                  );
                },
              ),
            );
          },
          error: (_, _) => SliverToBoxAdapter(
            child: Column(
              children: [
                const Text('メモリを読み込めませんでした。'),
                TextButton(
                  onPressed: () => ref.invalidate(historyProvider),
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
          loading: () =>
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
        ),
      ],
    );
  }

  DateTime _slotDate(int slot) =>
      DateTime.fromMillisecondsSinceEpoch(slot * 5000);
}
