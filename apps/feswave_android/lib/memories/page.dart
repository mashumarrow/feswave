import 'dart:convert';
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
      Text('共感メモリ', style: Theme.of(context).textTheme.headlineMedium),
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
      const SizedBox(height: 12),
      ...ref
          .watch(historyProvider)
          .when(
            data: (rows) {
              final list = rows.where((m) => !favorites || m.favorite);
              if (list.isEmpty) {
                return [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Text(
                      favorites
                          ? 'お気に入りのメモリはありません'
                          : '近くの参加者と同じ時間にリアクションすると、ここに記録されます。',
                    ),
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
                          onTap: () => showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (_) => ProfileCard(p),
                          ),
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
    ],
  );
}
