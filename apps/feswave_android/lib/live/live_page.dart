import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services.dart';
import '../profile/models.dart';
import '../ui/shared.dart';
import 'session.dart';
import 'protocol.dart';
import 'orbit.dart';

class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key, this.demoCount = 3});
  final int demoCount;
  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage>
    with SingleTickerProviderStateMixin {
  late final orbit = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  final game = ResonanceGame();
  late final StreamSubscription<int> flashes;
  int pulse = 0;
  Timer? demoReset;
  static final demo = [
    ('Mio', 'blue', .72),
    ('Ren', 'purple', .2),
    ('Yui', 'pink', .42),
    ('Sora', 'orange', .85),
    ('Aki', 'purple', .35),
    ('Rei', 'pink', .1),
    ('Nico', 'orange', .6),
    ('Kei', 'blue', .26),
    ('Haru', 'purple', .48),
    ('Rin', 'pink', .76),
  ];
  @override
  void initState() {
    super.initState();
    flashes = ref.read(liveProvider.notifier).effects.stream.listen((id) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        notice(context, '共感メモリに保存しました');
      } else {
        game.flash(id);
      }
    });
  }

  @override
  void dispose() {
    demoReset?.cancel();
    flashes.cancel();
    orbit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveProvider);
    final session = ref.read(liveProvider.notifier);
    final account = ref.watch(accountProvider).value;
    final people = session.people.values.toList()
      ..sort((a, b) => b.proximity.compareTo(a.proximity));
    final items = <({int id, Profile profile, double near, int level})>[
      if (!session.joined)
        for (int i = 0; i < widget.demoCount.clamp(0, demo.length); i++)
          (
            id: i + 1,
            profile: Profile(name: demo[i].$1, color: demo[i].$2),
            near: demo[i].$3,
            level: i % 5 + 1,
          )
      else
        for (final p in people.take(10))
          (
            id: p.id,
            profile: p.profile ?? Profile(name: hexId(p.id)),
            near: p.proximity,
            level: p.level,
          ),
    ];
    final reduced = MediaQuery.disableAnimationsOf(context);
    final level = strength(session.taps[session.now ~/ slotMs] ?? 0);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'FESWAVE FESTIVAL',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 19,
                  letterSpacing: .6,
                ),
              ),
            ),
            Text(
              session.joined ? '周辺 ${people.length}人' : 'デモ',
              style: const TextStyle(color: cyan),
            ),
          ],
        ),
        const Text(
          'TOKYO BAY  ·  MAIN STAGE',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 11,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, c) {
              final area = c.biggest;
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const RadialGradient(
                    colors: [Color(0xff342044), ink],
                    radius: .7,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: OrbitGrid(level)),
                    ),
                    for (final item in items)
                      TweenAnimationBuilder<double>(
                        key: ValueKey(item.id),
                        tween: Tween(end: item.near),
                        duration: reduced
                            ? Duration.zero
                            : const Duration(milliseconds: 1200),
                        builder: (context, near, _) {
                          final diameter = 34 + near * 22;
                          return AnimatedBuilder(
                            animation: orbit,
                            builder: (context, child) {
                              final angle = session.joined
                                  ? (item.id % 997) * 2 * math.pi / 997
                                  : item.id * 2 * math.pi / widget.demoCount;
                              final point = orbitPoint(
                                area,
                                reduced ? 0 : orbit.value,
                                near,
                                angle,
                              );
                              game.points[item.id] = point;
                              return Transform.translate(
                                offset: point - area.center(Offset.zero),
                                child: child,
                              );
                            },
                            child: AnimatedOpacity(
                              opacity:
                                  session.joined &&
                                      session.now -
                                              (session.people[item.id]?.last ??
                                                  session.now) >
                                          13500
                                  ? 0
                                  : 1,
                              duration: reduced
                                  ? Duration.zero
                                  : const Duration(milliseconds: 800),
                              child:
                                  Semantics(
                                    button: true,
                                    label: '${item.profile.name}のプロフィール',
                                    child: GestureDetector(
                                      onTap: () async {
                                        try {
                                          final p = session.joined
                                              ? await session.profileFor(
                                                  item.id,
                                                )
                                              : item.profile;
                                          if (context.mounted) {
                                            await showModalBottomSheet(
                                              context: context,
                                              showDragHandle: true,
                                              builder: (_) => ProfileCard(p),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            notice(context, e);
                                          }
                                        }
                                      },
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DecoratedBox(
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                if (item.level > 0)
                                                  BoxShadow(
                                                    color: tint(
                                                      item.profile.color,
                                                    ).withValues(alpha: .23),
                                                    blurRadius:
                                                        4 + item.level * 2,
                                                  ),
                                              ],
                                            ),
                                            child: Avatar(
                                              item.profile,
                                              size: diameter,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 72,
                                            child: Text(
                                              item.profile.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ).animate().fadeIn(
                                    duration: reduced ? Duration.zero : 320.ms,
                                  ),
                            ),
                          );
                        },
                      ),
                    if (!reduced && pulse > 0)
                      IgnorePointer(
                        child:
                            Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: pink, width: 2),
                                  ),
                                )
                                .animate(key: ValueKey('ring$pulse'))
                                .scale(
                                  begin: const Offset(.8, .8),
                                  end: const Offset(1.55, 1.55),
                                  duration: 360.ms,
                                )
                                .fadeOut(duration: 360.ms),
                      ),
                    Semantics(
                      button: true,
                      label: 'リアクション',
                      child: GestureDetector(
                        onTap: () {
                          session.tap();
                          if (!session.joined) {
                            demoReset?.cancel();
                            demoReset = Timer(
                              Duration(
                                milliseconds: slotMs - session.now % slotMs,
                              ),
                              () {
                                if (mounted) setState(() {});
                              },
                            );
                          }
                          setState(() => pulse++);
                        },
                        child:
                            Container(
                                  width: 70,
                                  height: 70,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [pink, lilac],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: pink.withValues(alpha: .3),
                                        blurRadius: 19,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.graphic_eq_rounded,
                                    size: 36,
                                    color: ink,
                                  ),
                                )
                                .animate(
                                  key: ValueKey(pulse),
                                  target: reduced ? 0 : 1,
                                )
                                .scale(
                                  begin: const Offset(.88, .88),
                                  end: const Offset(1, 1),
                                  duration: 240.ms,
                                ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(child: GameWidget(game: game)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('リアクション'),
            Text(
              'LEVEL  $level',
              style: const TextStyle(fontWeight: FontWeight.w800, color: pink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (int i = 1; i <= 5; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: i <= level ? pink : panel,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (session.joined && people.isEmpty) const Text('周辺の参加者を待っています。'),
        FilledButton.icon(
          onPressed: session.busy || account == null
              ? null
              : () async {
                  if (session.joined) {
                    await session.leave();
                  } else if (account.profile.name.trim().isEmpty) {
                    context.go('/profile/edit?join=1');
                  } else {
                    await session.join();
                  }
                },
          icon: Icon(session.joined ? Icons.logout : Icons.sensors),
          label: Text(session.joined ? 'ライブを退出' : 'ライブに参加する'),
        ),
        if (!session.joined)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              '中央をタップしてリアクションを体験できます。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        if (session.message.isNotEmpty) Text(session.message),
      ],
    );
  }
}
