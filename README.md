# FESWAVE

ライブ会場で近くの人を見つけ、一緒に盛り上がった瞬間をスマホに残すAndroidアプリ。

| ディレクトリ | 担当 |
| --- | --- |
| [apps/feswave_android](apps/feswave_android) | Flutterアプリ。BLE広告で参加者の発見・反応交換、GATTで公開プロフィールを取得。共感メモリは端末のSQLiteに保存 |
| [services/api](services/api) | 既存Web版と同じ認証・曲検索・プロフィールのHTTP API。Rust、Axum、PostgreSQL |

## スマホで試す

Android 12以上の広告・スキャン対応端末を2台用意する。各端末でBluetoothと位置情報をオンにする。初回は「ライブを始める」を押し、付近のデバイスと正確な位置情報を許可する。許可済みなら、ライブを開くと広告とスキャンが自動で始まる。メモリとプロフィールはBluetoothがオフでも利用できる。名前は後からプロフィールで登録できる。メモリを作る場合は「好きな曲とアイコンを公開」を両端末でオンにする。中央のボタンを近くで同じ5秒間にタップすると、条件を満たした受信側に共感メモリが残る。

```sh
cd apps/feswave_android
mise install
mise exec -- flutter pub get
mise exec -- flutter build apk --debug
adb -s <serial> install -r build/app/outputs/flutter-apk/app-debug.apk
```

## 曲検索・プロフィール同期

PostgreSQLをインストール済みの開発PCでは以下を実行する。Dockerの場合はAPIディレクトリで.env.exampleを.envへコピーし、接続情報を設定して docker compose up -d --wait db を実行する。

```sh
cd services/api
node scripts/db-local.mjs
cargo run --locked
```

USBデバッグでは各端末で `adb -s <serial> reverse tcp:3000 tcp:3000` を実行する。デバッグAPKの既定接続先は http://127.0.0.1:3000/api/ 。公開環境では `flutter build apk --dart-define=API_BASE_URL=https://your-host/api/` とし、配布用署名を別途設定する。

Googleログインを使う場合は、アプリID jp.feswave.feswave_android とAPK署名のSHA-1に対応するAndroid OAuthクライアントを登録する。同じGoogle CloudプロジェクトのWebクライアントIDをAPI側の GOOGLE_CLIENT_ID に設定する。HTTPS環境では COOKIE_SECURE=true とする。認証の設定がない環境でもゲスト参加と曲検索を利用できる。

DBマイグレーションは `services/api/migrations` に置く。適用済みの番号と内容は維持し、新規ファイルには未使用の次の番号を使う。
