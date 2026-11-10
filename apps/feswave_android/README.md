# FESWAVE Android

## 構成

- **live** が無線のライフサイクルを所有する。専用128-bit UUIDのService Dataにバージョン、公開フラグ、ランダムな一時ID、直前の5秒区間と反応レベルを8バイトで送る。広告の更新を直列化し、受信した区間を端末の自動時刻と照合する。GATTの公開プロフィールは相手ごとに順次読み、ページ番号・版・一時IDを検査する。
- **profile** がゲスト編集・オンライン操作を担当する。ログイン時は既存APIのchallengeとCredential Managerを使い、認証Cookieを端末の保護ストレージに保存する。曲の検索結果と代表曲を管理する。
- **memories** はDriftでプロフィール設定と共感履歴を保存する。ライブの保存成功時にだけFlameの光の描画を開始する。共有オフの相手から曲情報を表示しない。
- **main / ui** はRiverpod、go_router、Material 3で3タブを構成する。公転の角度は物理的な方位を表さない。距離の目盛は約1・2・3 m。参加者を15秒のRSSI中央値から推定した半径に配置し、1 m以内と3 m以遠はそれぞれ内周・外周にまとめる。3件の観測が揃うまでは直近のRSSIを使う。相手の5秒区間のリアクションを受信すると、そのアバターから波紋が広がる。

## 開発

アプリのディレクトリで実行する。UIを調整するときは接続した端末を選び、起動後に `r` でホットリロードする。

```sh
mise exec -- flutter devices
mise exec -- flutter run -d DEVICE_ID
```

Freezed・Driftのモデル定義を変更したときは `mise exec -- dart run build_runner build` を実行し、生成差分もコミットする。静的解析は `mise exec -- flutter analyze`、BLE判定やメモリ保存のテストは `mise exec -- flutter test test/live_test.dart` で個別に実行できる。

## 配布

`main` へのアプリ・配布設定の変更で「Release Android」が動く。直前の `vX.Y.Z` 以降のAndroid関連コミットをgit-cliffで集計し、破壊的変更はmajor、`feat` はminor、それ以外はpatchを上げる。手動実行でも公開済みのコミットはスキップする。機能ブランチはActionsのArtifactsでデバッグAPKを配布する。

正式版はタグのバージョンをAndroidの `versionName`、コミットの累計数を `versionCode` に使う。テスト後、署名付きarm64 APKとSHA-256をGitHub Releaseに添付し、変更履歴とともにLatestに指定する。検証は両ファイルを同じディレクトリに置いて `sha256sum -c feswave-android-arm64.apk.sha256` を実行する。

署名にはActionsのSecrets `ANDROID_RELEASE_KEYSTORE`（PKCS12のBase64、aliasは `feswave`）と `ANDROID_RELEASE_PASSWORD` を使う。今後の上書き更新には同じ鍵が必要。以前のデバッグ署名APKから移行する場合、署名の違いにより上書きできず、アンインストールすると端末内のメモリも削除される。

ローカルでビルドする場合は次を実行する。

```sh
mise exec -- flutter build apk --debug --target-platform android-arm64
```

距離の仮設定は−72 dBm以上、直近15秒に3件以上、反応区間に観測があること。両者が公開設定でともにタップし、5段階のレベル差が1以内なら受信側が記録する。端末の向き、持ち方、機種により判定は変化する。
