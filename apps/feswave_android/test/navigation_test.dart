import 'dart:async';
import 'package:dio/dio.dart';
import 'package:feswave_android/live/session.dart';
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
    await tester.tap(find.text('すべてのメモリを見る'));
    await tester.pumpAndSettle();
    expect(find.text('共感メモリはまだありません'), findsOneWidget);
    await tester.tap(find.text('プロフィール').last);
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
}
