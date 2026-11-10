# 開発ガイド

## ソースから起動する

Android SDK、JDK 17、miseを用意し、USBデバッグを有効にした端末を接続します。Flutterのバージョンはリポジトリで固定しています。

```sh
git clone https://github.com/mashumarrow/feswave.git
cd feswave/apps/feswave_android
mise trust
mise install
mise exec -- flutter pub get --enforce-lockfile
mise exec -- flutter devices
mise exec -- flutter run -d DEVICE_ID
```

`DEVICE_ID` は直前のコマンドに表示された端末IDに置き換えます。[Androidアプリの構成・APKビルド手順](../apps/feswave_android/README.md)

## ローカルAPIで曲検索とプロフィール同期を試す

Rust（Cargo）とDocker Composeを用意し、リポジトリのルートから次を実行します。APIは起動時にPostgreSQLのマイグレーションを適用します。曲検索にはiTunesへのインターネット接続が必要です。

```sh
cd services/api
cp .env.example .env
docker compose up -d --wait db
cargo run --locked
```

PostgreSQLをPCにインストールしている場合は、上の `cp` と `docker compose` の代わりに、Node.js 22以上で `node scripts/db-local.mjs` を実行します。スクリプトが専用DBと接続設定を作成したら、同じディレクトリで `cargo run --locked` を実行してください。

別のターミナルでAPIとDBの接続を確認します。正常なら `204 No Content` が返ります。

```sh
curl -i http://127.0.0.1:3000/api/health
```

ソースから起動した場合の既定のAPI接続先は `http://127.0.0.1:3000/api/` です。USB接続では別のターミナルから端末ごとに `adb -s DEVICE_ID reverse tcp:3000 tcp:3000` を実行します。別のサーバーに接続する場合は、ビルド時に `--dart-define=API_BASE_URL=https://your-host/api/` を指定します。

Googleログインを使う場合は、アプリID `jp.feswave.feswave_android` とAPK署名のSHA-1に対応するAndroid OAuthクライアントを登録し、同じGoogle CloudプロジェクトのWebクライアントIDをAPIの `GOOGLE_CLIENT_ID` に設定します。HTTPSで公開する場合は `COOKIE_SECURE=true` を設定してください。

配布用APKは東京リージョンのCloud Run上のAPIを使用します。[本番構成とデプロイ手順](../infra/README.md)

## 開発に参加する

不具合や機能の提案は [Issues](https://github.com/mashumarrow/feswave/issues) で受け付けています。Bluetooth関連の報告には、端末機種・Androidバージョン・2台の距離・どちらの端末に何が表示されたかを添えてください。

| 変更箇所 | 検証方法 |
| --- | --- |
| [Flutterアプリ](../apps/feswave_android) | 同ディレクトリで `mise exec -- flutter analyze` と `mise exec -- flutter test` |
| [Rust API](../services/api) | 開発用DBを起動し、同ディレクトリで `npm ci` と `npm test`（Node.js 22以上） |

DB変更は [migrations](../services/api/migrations) に次の未使用番号のSQLファイルとして追加します。
