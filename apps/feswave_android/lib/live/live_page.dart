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
  int pulse = 0;
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
    final view = View.of(context);
    final viewportHeight =
        (view.physicalSize.height -
            view.viewPadding.top -
            view.viewPadding.bottom) /
        view.devicePixelRatio;
    void react() {
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
        game.beat(nextLevel, rising: nextLevel > level);
      }
      setState(() => pulse++);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 22),
      children: [
        const PageHeading('SAME MUSIC. SAME MOMENT.', 'Live', 'wave', ''),
        WavePanel(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const WaveIcon('people', size: 16, color: Color(0xffa793b9)),
                const SizedBox(width: 5),
                Text(
                  '${!benchmark ? people.length : items.length}  ${!benchmark ? "LIVE" : "DEMO"}',
                  style: captionStyle,
                ),
              ],
            ),
            SizedBox(
              height: (viewportHeight * .52).clamp(350.0, 460.0),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      heightFactor: .92,
                      alignment: Alignment.topCenter,
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final area = c.biggest;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const RadialGradient(
                                colors: [Color(0xff25172f), panel, panel],
                                radius: .54,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Positioned.fill(
                                  child: CustomPaint(
                                    painter: OrbitGrid(
                                      level,
                                      reduced ? null : orbit,
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
                                              ? (item.id % 997) *
                                                    2 *
                                                    math.pi /
                                                    997
                                              : item.id *
                                                    2 *
                                                    math.pi /
                                                    widget.demoCount;
                                          final point = orbitPoint(
                                            area,
                                            reduced ? 0 : orbit.value,
                                            near,
                                            angle,
                                          );
                                          game.points[item.id] = point;
                                          return Transform.translate(
                                            offset:
                                                point -
                                                area.center(Offset.zero),
                                            child: child,
                                          );
                                        },
                                        child: AnimatedOpacity(
                                          opacity:
                                              !benchmark &&
                                                  session.now -
                                                          (session
                                                                  .people[item
                                                                      .id]
                                                                  ?.last ??
                                                              session.now) >
                                                      13500
                                              ? 0
                                              : 1,
                                          duration: reduced
                                              ? Duration.zero
                                              : const Duration(
                                                  milliseconds: 800,
                                                ),
                                          child:
                                              Semantics(
                                                button: true,
                                                label:
                                                    '${item.profile.name}のプロフィール',
                                                child: GestureDetector(
                                                  onTap: () async {
                                                    try {
                                                      final p = !benchmark
                                                          ? await session
                                                                .profileFor(
                                                                  item.id,
                                                                )
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
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      DecoratedBox(
                                                        decoration: BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          boxShadow: [
                                                            if (item.level > 0)
                                                              BoxShadow(
                                                                color:
                                                                    tint(
                                                                      item
                                                                          .profile
                                                                          .color,
                                                                    ).withValues(
                                                                      alpha:
                                                                          .23,
                                                                    ),
                                                                blurRadius:
                                                                    4 +
                                                                    item.level *
                                                                        2,
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
                                                              ? item
                                                                    .profile
                                                                    .name
                                                              : "${item.profile.name} · demo",
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          textAlign:
                                                              TextAlign.center,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 9,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ).animate().fadeIn(
                                                duration: reduced
                                                    ? Duration.zero
                                                    : 320.ms,
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
                                                border: Border.all(
                                                  color: pink,
                                                  width: 3.5,
                                                ),
                                              ),
                                            )
                                            .animate(
                                              key: ValueKey('ring$pulse'),
                                            )
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
                                    onTap: react,
                                    child:
                                        Container(
                                              width: 91,
                                              height: 91,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: level == 0
                                                      ? const Color(0xffcf85e0)
                                                      : reactionColors[level],
                                                  width: 3.5,
                                                ),
                                                gradient: const RadialGradient(
                                                  center: Alignment(-.25, -.35),
                                                  radius: .94,
                                                  colors: [
                                                    Color(0xff642365),
                                                    Color(0xff21122e),
                                                    Color(0xff9748bd),
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: reactionColors[level]
                                                        .withValues(alpha: .48),
                                                    blurRadius: 19,
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child:
                                                    session
                                                            .me
                                                            .favorite
                                                            ?.artworkUrl !=
                                                        null
                                                    ? Avatar(
                                                        session.me,
                                                        size: 81,
                                                      )
                                                    : WaveIcon(
                                                        'music',
                                                        size: 34,
                                                        color: level == 0
                                                            ? const Color(
                                                                0xffbaa3c4,
                                                              )
                                                            : reactionColors[level],
                                                      ),
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
                                IgnorePointer(
                                  child: Transform.translate(
                                    offset: const Offset(0, 60),
                                    child: Text(
                                      'YOU   LEVEL $level',
                                      style: const TextStyle(
                                        fontSize: 8,
                                        letterSpacing: 1.4,
                                        color: Color(0xffc6abc9),
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: GameWidget(game: game),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (memoryPartner != null)
                    Positioned(
                      top: 2,
                      left: 4,
                      right: 4,
                      child: IgnorePointer(
                        child:
                            Semantics(
                                  liveRegion: true,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xff194961),
                                          Color(0xff602350),
                                        ],
                                      ),
                                      border: Border.all(color: cyan),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        memoryPartner!.isEmpty
                                            ? '共感メモリが生まれました'
                                            : '$memoryPartner と共感メモリが生まれました',
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .animate()
                                .fadeIn(duration: 180.ms)
                                .slideY(begin: -.18, end: 0),
                      ),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Text(
                      !benchmark && people.isEmpty
                          ? '周辺の参加者を待っています。'
                          : benchmark && pulse > 0
                          ? 'デモ体験中 · 履歴には保存されません'
                          : '同じ音楽で、つながっている。',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xffa198af),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int i = 1; i <= 5; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(5),
                        color: i <= level
                            ? reactionColors[i]
                            : const Color(0xff453449),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                level == 0 ? 'タップして、盛り上がりをシェア' : 'LEVEL $level',
                style: const TextStyle(fontSize: 9, color: Color(0xffa198af)),
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: const Color(0xff8649a0)),
                gradient: const LinearGradient(
                  colors: [Color(0xff10273b), Color(0xff30132f)],
                ),
              ),
              child: TextButton.icon(
                onPressed: react,
                style: TextButton.styleFrom(minimumSize: const Size(0, 64)),
                icon: const WaveIcon('tap', size: 26, color: Color(0xffb3cdf8)),
                label: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tap to React  ✧',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    Text(
                      '今の気持ちを、タップで届けよう',
                      style: TextStyle(fontSize: 9, color: Color(0xffaca0ba)),
                    ),
                  ],
                ),
              ),
            ),
            if (session.message.isNotEmpty) Text(session.message),
          ],
        ),
        const WaveFooter(),
      ],
    );
  }
}
