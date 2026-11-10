import 'dart:async';
import 'package:dio/dio.dart';
import 'package:feswave_android/live/session.dart';
import 'package:feswave_android/live/orbit.dart';
import 'package:feswave_android/live/protocol.dart';
import 'package:feswave_android/live/live_page.dart';
import 'package:feswave_android/live/membrane.dart';
import 'package:feswave_android/main.dart';
import 'package:feswave_android/profile/api.dart';
import 'package:feswave_android/profile/models.dart';
import 'package:feswave_android/profile/pages.dart';
import 'package:feswave_android/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _BlockedSession extends LiveSession {
  @override
  int build() {
    gate = Gate.blocked;
    message = '付近のデバイスの許可が必要です';
    ref.onDispose(effects.close);
    return 0;
  }

  @override
  Future<void> check({bool request = true}) async {}
}

class _Guest extends AccountController {
  @override
  Future<Account> build() async => (profile: const Profile(), linked: false);
}

class _SearchApi extends ProfileApi {
  final result = Completer<List<Track>>();
  @override
  Future<List<Track>> search(String term, CancelToken token) => result.future;
}

void main() {
  testWidgets(
    'a received REACT pulses once at the peer for each active window',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          liveProvider.overrideWith(_BlockedSession.new),
          accountProvider.overrideWith(_Guest.new),
        ],
      );
      addTearDown(container.dispose);
      final session = container.read(liveProvider.notifier)..active = true;
      final peer = Nearby(7)
        ..profile = const Profile(name: 'Haru')
        ..revision = 0;
      session.people[7] = peer;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: LivePage())),
        ),
      );
      final ripple = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PeerRipple,
      );
      void receive(int slot, int level) =>
          session.received(Signal(7, slot, level, false), -66);
      receive(1, 3);
      await tester.pump();
      expect(ripple, findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1200));
      expect(ripple, findsNothing);
      receive(1, 3);
      receive(0, 2);
      await tester.pump();
      expect(ripple, findsNothing);
      receive(2, 0);
      await tester.pump();
      expect(ripple, findsNothing);
      receive(3, 3);
      await tester.pump();
      expect(ripple, findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'stage corners and caption react; a participant opens their profile',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveProvider.overrideWith(_BlockedSession.new),
            accountProvider.overrideWith(_Guest.new),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LivePage(demoCount: 1)),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      for (final point in const [
        Offset(5, 5),
        Offset(795, 5),
        Offset(5, 595),
        Offset(795, 595),
        Offset(400, 300),
      ]) {
        await tester.tapAt(point);
        await tester.pump();
      }
      await tester.tapAt(tester.getCenter(find.text('Tap to react')));
      await tester.pump();
      expect(find.text('LEVEL 2'), findsOneWidget);
      final paint = tester.widget<CustomPaint>(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MembranePainter,
        ),
      );
      final membrane = paint.painter! as MembranePainter;
      final hit = membrane.hits.last;
      await tester.pump(const Duration(milliseconds: 80));
      expect(
        hit.displacement(hit.angle, membrane.pulse.value, 0),
        lessThan(-.2),
      );
      expect(hit.displacement(hit.angle + 3.14, membrane.pulse.value, 0), 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        hit.displacement(hit.angle + 3.14, membrane.pulse.value, 0),
        lessThan(0),
      );
      await tester.pump(const Duration(milliseconds: 450));
      expect(hit.displacement(hit.angle, membrane.pulse.value, 0), 0);
      await tester.tap(find.text('haru · demo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byTooltip('閉じる'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('権限なしで履歴の絞り込みとプロフィール編集ができる', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          liveProvider.overrideWith(_BlockedSession.new),
          accountProvider.overrideWith(_Guest.new),
          historyProvider.overrideWith((_) => Stream.value([])),
        ],
        child: const Feswave(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('ライブを始める'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('メモリ'));
    await tester.pumpAndSettle();
    expect(find.text('共感メモリはまだありません'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('お気に入り'));
    await tester.pumpAndSettle();
    expect(find.text('お気に入りはまだありません'), findsOneWidget);
    await tester.ensureVisible(find.text('すべてのメモリを見る'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('すべてのメモリを見る'));
    await tester.pumpAndSettle();
    expect(find.text('共感メモリはまだありません'), findsOneWidget);
    await tester.tap(find.text('プロフィール').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('プロフィールを作成'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('プロフィールを作成'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('変更を保存'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('変更を保存'));
    await tester.pumpAndSettle();
    expect(find.text('ニックネームを入力してください'), findsOneWidget);
  });

  testWidgets('検索語を消すと進捗と遅れて届いた結果を表示しない', (tester) async {
    final api = _SearchApi();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: const MaterialApp(home: Scaffold(body: MusicSearch())),
      ),
    );
    final field = find.byType(TextField);
    await tester.enterText(field, '曲');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.enterText(field, '');
    api.result.complete([
      const Track(trackId: 1, artistName: '歌手', trackName: '前の曲'),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('前の曲'), findsNothing);
  });

  testWidgets('文字を拡大してキーボードを表示中でも長い曲名を選べる', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 800);
    addTearDown(tester.view.reset);
    final api = _SearchApi();
    Track? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiProvider.overrideWithValue(api)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  selected = await showModalBottomSheet<Track>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const MusicSearch(),
                  );
                },
                child: const Text('曲を追加'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('曲を追加'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(find.byType(TextField), 'ライブ');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    final track = Track(
      trackId: 7,
      artistName: 'アーティスト',
      trackName: 'ライブ音源' * 8,
    );
    api.result.complete([track]);
    await tester.pumpAndSettle();
    await tester.tap(find.text(track.trackName));
    await tester.pumpAndSettle();
    expect(selected, track);
  });
}
