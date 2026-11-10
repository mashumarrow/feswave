# FESWAVE Android

## 構成

- **live** が無線のライフサイクルを所有する。専用128-bit UUIDのService Dataにバージョン、公開フラグ、ランダムな一時ID、直前の5秒区間と反応レベルを8バイトで送る。広告の更新を直列化し、受信した区間を端末の自動時刻と照合する。GATTの公開プロフィールは相手ごとに順次読み、ページ番号・版・一時IDを検査する。
- **profile** がゲスト編集・オンライン操作を担当する。ログイン時は既存APIのchallengeとCredential Managerを使い、認証Cookieを端末の保護ストレージに保存する。曲の検索結果と代表曲を管理する。
- **memories** はDriftでプロフィール設定と共感履歴を保存する。ライブの保存成功時にだけFlameの光の描画を開始する。共有オフの相手から曲情報を表示しない。
- **main / ui** はRiverpod、go_router、Material 3で3タブを構成する。公転の角度は物理的な方位を表さない。半径とサイズは15秒のRSSI中央値、色と波紋はリアクションに連動する。

## 開発

```sh
mise exec -- dart run build_runner build
mise exec -- flutter analyze
mise exec -- flutter test
mise exec -- flutter build apk --debug
```

距離の仮設定は−72 dBm以上、直近15秒に3件以上、反応区間に観測があること。両者が公開設定でともにタップし、5段階のレベル差が1以内なら受信側が記録する。端末の向き、持ち方、機種により判定は変化する。
