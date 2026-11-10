# FESWAVE

ライブ会場で近くの人を見つけ、一緒に盛り上がった瞬間をスマホに残すAndroidアプリ。

| ディレクトリ | 担当 |
| --- | --- |
| [apps/feswave_android](apps/feswave_android) | Flutterアプリ。BLE広告で参加者の発見・反応交換、GATTで公開プロフィールを取得。共感メモリは端末のSQLiteに保存 |
| [services/api](services/api) | 既存Web版と同じ認証・曲検索・プロフィールのHTTP API。Rust、Axum、PostgreSQL |

## スマホで試す

Android 12以上の広告・スキャン対応端末を2台用意する。各端末でBluetoothと位置情報をオンにする。初回は「ライブを始める」を押し、付近のデバイスと正確な位置情報を許可する。許可済みなら、ライブを開くと広告とスキャンが自動で始まる。メモリとプロフィールはBluetoothがオフでも利用できる。名前は後からプロフィールで登録できる。メモリを作る場合は「好きな曲とアイコンを公開」を両端末でオンにする。近くで同じ5秒間にライブ画面の背景をタップすると、条件を満たした受信側に共感メモリが残る。

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

## 本番APIのデプロイ

本番はGCPプロジェクト `feswave` の東京リージョンを使う。Cloud RunがRust APIを実行し、Cloud SQL for PostgreSQL 17にUnixソケット経由で接続する。配布用APKの接続先は `https://feswave-api-933816421570.asia-northeast1.run.app/api/`。ローカルのUSBデバッグは上記の手順を使う。

- Pull RequestではTerraformの書式・構成、PostgreSQLを使うAPIテスト、コンテナビルドを検証する。
- `services/api/`、`infra/`、APIワークフローの変更がmainに入ると、GitHub Actionsの「FESWAVE API」がテスト、Artifact Registryへのpush、Terraformのplan・apply、公開 `/healthz` のDB疎通確認を順に行う。手動再実行もmainを指定する。
- 通常の本番構成は `infra/production` で変更する。DBのパスワードを含むstateは非公開のバージョニング付きGCSバケットに置き、APIはSecret Managerのバージョンを参照する。既存DBへのマイグレーションは旧リビジョンと共存できる変更にする。
- 認証基盤、stateバケット、イメージリポジトリは管理者が `infra/bootstrap` で管理する。初回は課金済みプロジェクトで下記を実行する。再適用には初回のbootstrap stateを使う。GitHubはmainのデプロイワークフローだけがWorkload Identity Federationで認証できる。
- Googleログインを有効化するときはGitHubのproduction環境変数 `GOOGLE_CLIENT_ID` にWebクライアントIDを設定し、ワークフローを再実行する。

```sh
cd infra
mise install
gcloud auth application-default login
mise exec -- terraform -chdir=bootstrap init
mise exec -- terraform -chdir=bootstrap apply -var=project_id=feswave
```
