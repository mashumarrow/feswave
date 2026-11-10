import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../profile/models.dart';
import '../ui/shared.dart';
import '../ui/stage.dart';
import 'session.dart';
import 'package:permission_handler/permission_handler.dart';
import 'protocol.dart';
import 'orbit.dart';

class LivePage extends ConsumerStatefulWidget {
  const LivePage({super.key, this.demoCount = 0});
  final int demoCount;
  @override
  ConsumerState<LivePage> createState() => _LivePageState();
}

class _LivePageState extends ConsumerState<LivePage>
    with SingleTickerProviderStateMixin {
  AnimationController? _orbit;
  AnimationController get orbit => _orbit ??= AnimationController(
    vsync: this,
    duration: const Duration(seconds: 60),
  )..repeat();
  final game = ResonanceGame();
  late final StreamSubscription<int> flashes;
  final demoGauge = ReactionGauge();
  Timer? demoTick, memoryBannerTimer;
  String? memoryPartner;
  static final demo = [
    (
      Profile(name: 'haru', artist: 'YOASOBI', song: '群青', color: 'pink'),
      .72,
      3,
    ),
    (
      Profile(
        name: 'minami',
        artist: 'Mrs. GREEN APPLE',
        song: '青と夏',
        color: 'orange',
      ),
      .2,
      2,
    ),
    (
      Profile(name: 'ren', artist: 'Vaundy', song: '怪獣の花唄', color: 'blue'),
      .42,
      1,
    ),
    (
      Profile(name: 'yui', artist: 'あいみょん', song: 'マリーゴールド', color: 'purple'),
      .85,
      3,
    ),
    (
      Profile(name: 'kaito', artist: 'King Gnu', song: '白日', color: 'blue'),
      .35,
      2,
    ),
    (
      Profile(name: 'sora', artist: 'サカナクション', song: '新宝島', color: 'pink'),
      .1,
      1,
    ),
    (Profile(name: 'Nico', color: 'orange'), .6, 2),
    (Profile(name: 'Kei', color: 'blue'), .26, 1),
    (Profile(name: 'Haru', color: 'purple'), .48, 3),
    (Profile(name: 'Rin', color: 'pink'), .76, 2),
  ];
  @override
  void initState() {
    super.initState();
    if (widget.demoCount == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(liveProvider.notifier).check(request: false);
      });
    }
    flashes = ref.read(liveProvider.notifier).effects.stream.listen((id) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        notice(context, '共感メモリに保存しました');
      } else {
        game.flash(id);
        memoryBannerTimer?.cancel();
        final partner = ref
            .read(liveProvider.notifier)
            .people[id]
            ?.profile
            ?.name;
        setState(() => memoryPartner = partner ?? '');
        memoryBannerTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => memoryPartner = null);
        });
      }
    });
  }

  @override
  void dispose() {
    memoryBannerTimer?.cancel();
    demoTick?.cancel();
    flashes.cancel();
    _orbit?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(liveProvider);
    final session = ref.read(liveProvider.notifier);
    final benchmark = widget.demoCount > 0;
    if (!benchmark && !session.active) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const PageHeading('SAME MUSIC. SAME MOMENT.', 'Live', 'wave', ''),
          if (session.busy || session.gate != Gate.blocked)
            const LinearProgressIndicator(semanticsLabel: 'ライブを準備中')
          else ...[
            Text(session.message),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => session.check(),
              child: const Text('ライブを始める'),
            ),
            if (session.needsSettings)
              TextButton(
                onPressed: openAppSettings,
                child: const Text('アプリの設定を開く'),
              ),
          ],
        ],
      );
    }
    final people = session.people.values.toList()
      ..sort((a, b) => b.proximity.compareTo(a.proximity));
    final items = <({int id, Profile profile, double near, int level})>[
      if (benchmark)
        for (int i = 0; i < widget.demoCount.clamp(0, demo.length); i++)
          (id: i + 1, profile: demo[i].$1, near: demo[i].$2, level: demo[i].$3)
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
    final gauge = benchmark ? demoGauge : session.gauge;
    final level = gauge.levelAt(session.now);
    void react(Offset position) {
      if (benchmark) {
        demoGauge.tap(session.now);
        demoTick ??= Timer.periodic(const Duration(milliseconds: 500), (timer) {
          if (demoGauge.levelAt(session.now) == 0) {
            timer.cancel();
            demoTick = null;
          }
          setState(() {});
        });
      } else {
        session.tap();
      }
      if (!reduced) {
        final nextLevel = gauge.levelAt(session.now);
        game.beat(position, nextLevel, rising: nextLevel > level);
      }
      setState(() {});
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final area = constraints.biggest;
        return SizedBox.fromSize(
          size: area,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: OrbitGrid(level, reduced ? null : orbit),
                  ),
                ),
              ),
              Positioned.fill(
                child: Semantics(
                  button: true,
                  label: 'リアクションを送る',
                  onTap: () => react(area.center(Offset.zero)),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTapUp: (event) => react(event.localPosition),
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ink,
                    border: Border.all(color: reactionColors[level], width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: reactionColors[level].withValues(alpha: .65),
                        blurRadius: 28,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Avatar(session.me, size: 70),
                  ),
                ),
              ),
              for (final item in items)
                TweenAnimationBuilder<double>(
                  key: ValueKey(item.id),
                  tween: Tween(end: item.near),
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 1200),
                  builder: (context, near, _) {
                    final diameter = 34 + near * 17;
                    return AnimatedBuilder(
                      animation: orbit,
                      builder: (context, child) {
                        final angle = !benchmark
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
                            !benchmark &&
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
                                    final p = !benchmark
                                        ? await session.profileFor(item.id)
                                        : item.profile;
                                    if (context.mounted) {
                                      await showPerson(
                                        context,
                                        p,
                                        demo: benchmark,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      notice(
                                        context,
                                        'プロフィールを読み込めません。近くでもう一度お試しください。',
                                      );
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
                                              blurRadius: 4 + item.level * 2,
                                            ),
                                        ],
                                      ),
                                      child: Avatar(
                                        item.profile,
                                        size: diameter,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    SizedBox(
                                      width: 78,
                                      child: Text(
                                        !benchmark
                                            ? item.profile.name
                                            : "${item.profile.name} · demo",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 9),
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

              Positioned.fill(
                child: IgnorePointer(child: GameWidget(game: game)),
              ),
              Positioned(
                left: 18,
                right: 18,
                top: 12,
                child: IgnorePointer(
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'FESWAVE',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Text(
                        benchmark ? 'デモ · 保存なし' : '${people.length}人が近くにいます',
                        style: noteStyle,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 18,
                child: IgnorePointer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'TAP TO REACT',
                          style: TextStyle(
                            fontSize: 44,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(
                                color: reactionColors[level],
                                offset: const Offset(3, 3),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'LEVEL $level',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(width: 12),
                          for (var i = 1; i <= 5; i++)
                            Expanded(
                              child: Container(
                                height: 9,
                                margin: const EdgeInsets.only(right: 4),
                                color: i <= level
                                    ? reactionColors[i]
                                    : Colors.white24,
                              ),
                            ),
                        ],
                      ),
                      if (session.message.isNotEmpty) Text(session.message),
                    ],
                  ),
                ),
              ),
              if (memoryPartner != null)
                IgnorePointer(
                  child: Transform.rotate(
                    angle: -.085,
                    child:
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          color: const Color(0xffffd934),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '共感！',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                              Text(
                                memoryPartner!.isEmpty
                                    ? 'メモリに保存'
                                    : '$memoryPartner とメモリに保存',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ).animate().slideX(
                          begin: -.9,
                          end: 0,
                          duration: 180.ms,
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
