# FESWAVE

![FESWAVE](apps/feswave_android/assets/feswave.svg)

FESWAVEは、ライブ会場で近くの人が好きな曲を知るためのAndroidアプリです。同じ5秒間に近くの人と同じくらい画面をタップすると、お互いに公開している曲を「共感メモリ」として端末に記録できます。

[デモAPKをダウンロード](https://github.com/mashumarrow/feswave/releases/download/v0.1.0/feswave-demo-arm64.apk) · [リリース一覧](https://github.com/mashumarrow/feswave/releases) · [MITライセンス](LICENSE)

## アプリでできること

| 画面 | 使い方 |
| --- | --- |
| プロフィール | 好きな曲を登録し、星を押して代表曲を選びます。公開設定で、近くの参加者に曲とジャケットを見せるかどうかを選べます。 |
| ライブ | Bluetoothで見つけた参加者が画面に現れます。相手がタップすると、その人のアイコンから波紋が広がります。 |
| メモリ | ライブで記録した相手と曲を見返せます。ハートを押した記録は「お気に入り」で絞り込めます。 |

## 2台で試す

デモAPKはarm64用のデバッグビルドです。Android 12以上で、Bluetooth LE（BLE）の広告とスキャンに対応するスマホを2台用意します。ライブと共感メモリは、ゲストのままサーバーなしで試せます。

1. 両方の端末にAPKをインストールし、Bluetooth・位置情報・自動日時設定をオンにします。
2. それぞれの端末でプロフィールを編集し、ニックネームを入力します。初めて曲を登録するときは、アーティスト名と曲名を手入力できます。デモAPKでインターネットに接続していれば、曲を検索して追加することもできます。
3. 両方の端末で「好きな曲とアイコンを公開」をオンにし、「変更を保存」を押します。
4. 「ライブを始める」を押し、付近のデバイスと正確な位置情報の権限を許可します。2台を近くに置き、ライブ画面に相手が現れるまで待ちます。
5. 2台でライブ画面を同じタイミングでタップします。近接とリアクションの条件を満たすと、受信した端末の「メモリ」で記録を見返せます。

ライブ画面右上のマイクをオンにすると、周囲の音の周波数に合わせて中央のリングが動きます。音声は端末内で解析し、保存・送信しません。

## 共感メモリができる仕組み

端末はBLE広告で一時IDと5秒ごとの反応レベルを交換します。ライブ画面では電波が強い相手ほど中心に近く表示されます。円周上の位置は演出です。

受信側の端末は、次の条件がすべてそろうと相手の公開プロフィールをGATTで読み取り、端末内のSQLiteに保存します。

| 判定 | 条件 |
| --- | --- |
| 公開設定 | 両方の端末で「好きな曲とアイコンを公開」がオンになっている。 |
| タップ | 同じ5秒区間に両者がタップし、5段階の反応レベルの差が1以内である。 |
| 近さ | 直近15秒間に相手の電波を3回以上受信し、その受信強度の中央値が−72 dBm以上である。反応した5秒区間にも受信している。 |

Pixel 4とRedmi Note 10 JEを使った各距離1回の試験では、1 mで両方にメモリが残り、2 mでは両方とも保存されませんでした。電波強度は機種や持ち方で変わります。混雑した会場での誤判定率は未評価です。[実測値と試験条件](apps/feswave_android/verification/README.md)

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

`DEVICE_ID` は直前のコマンドに表示された端末IDに置き換えます。[Androidアプリの構成・APKビルド手順](apps/feswave_android/README.md)

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

Googleログインを使う場合は、アプリID `jp.feswave.feswave_android` とAPK署名のSHA-1に対応するAndroid OAuthクライアントを登録し、同じGoogle CloudプロジェクトのWebクライアントIDをAPIの `GOOGLE_CLIENT_ID` に設定します。HTTPSで公開する場合は `COOKIE_SECURE=true` を設定し、APKには配布用の署名を設定してください。

配布用APKは東京リージョンのCloud Run上のAPIを使用します。[本番構成とデプロイ手順](infra/README.md)

## 開発に参加する

不具合や機能の提案は [Issues](https://github.com/mashumarrow/feswave/issues) で受け付けています。Bluetooth関連の報告には、端末機種・Androidバージョン・2台の距離・どちらの端末に何が表示されたかを添えてください。

| 変更箇所 | 検証方法 |
| --- | --- |
| [Flutterアプリ](apps/feswave_android) | 同ディレクトリで `mise exec -- flutter analyze` と `mise exec -- flutter test` |
| [Rust API](services/api) | 開発用DBを起動し、同ディレクトリで `npm ci` と `npm test`（Node.js 22以上） |

DB変更は [migrations](services/api/migrations) に次の未使用番号のSQLファイルとして追加します。

## ライセンス

FESWAVEのソースコードは [MIT License](LICENSE) で公開しています。依存ライブラリにはそれぞれのライセンスが適用されます。Googleのロゴ、曲のジャケット画像などの第三者素材は各権利者に帰属します。第三者の著作権表示と利用条件は [Third-party licenses](THIRD_PARTY_LICENSES.md) を参照してください。
