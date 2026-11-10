# FESWAVE

フェス・ライブ向け交流アプリ。フロントエンドは **TypeScript**、バックエンドは **Rust / Axum / Tokio**、データベースは **PostgreSQL / SQLx** です。

スマートフォン利用を前提に、最大430px幅の縦長画面へ統一しました。PCでも同じ画面を中央に表示します。下部タブ、タッチ向けボタン、safe area、16pxの入力文字に対応しています。

## 起動

Git、Node.js 20以上、Rust stable（Cargoを含む）、Docker ComposeまたはPostgreSQL 17以上が必要です。WindowsではMSVCビルドツールも必要です。

リポジトリをクローンして、プロジェクトのディレクトリへ移動します。

```sh
git clone https://github.com/mashumarrow/feswave.git
cd feswave
```

依存パッケージをインストールします。

```sh
npm install
```

続いて、以下のどちらかでPostgreSQLを用意します。どちらもDB用ポートは `55432` です。両方を同時に起動しないでください。

### Docker Composeを使う場合

Docker Desktop等を起動し、環境設定をコピーします。PowerShellでは以下を実行します。

```powershell
Copy-Item .env.example .env
npm run db:up
npm start
```

macOS / Linuxではコピー部分を `cp .env.example .env` に置き換えてください。`.env` が既にある場合は上書きせず、内容を確認してください。

### インストール済みPostgreSQLを使う場合

```sh
npm run db:local
npm start
```

`db:local` はインストール済みのPostgreSQL実行ファイルを使い、プロジェクト専用のクラスタとDBを `.data/postgres/` に作成します。既存のシステムDBは変更しません。`.env` がなければ、ランダムなパスワードで生成します。実行ファイルを自動検出できない場合は `PG_BIN` にPostgreSQLのbinディレクトリを設定してください。

この作業環境では専用PostgreSQLを作成済みです。Windowsで権限制限のあるシェルを使う場合、通常のPowerShellから `npm run db:local` を実行してください。

### マイグレーションエラーについて

PostgreSQLのマイグレーションファイルのバージョン番号が重複している場合、アプリ起動時に以下のエラーが発生することがあります。

```text
Error: VersionMismatch(3)
```

本プロジェクトでは、マイグレーションのバージョン番号が重複しないよう、以下の順序で管理しています。

| バージョン | ファイル名 |
|---|---|
| 0001 | `0001_initial.sql` |
| 0002 | `0002_sample_events.sql` |
| 0003 | `0003_five_reaction_levels.sql` |
| 0004 | `0004_profile_music.sql` |
| 0005 | `0005_favorite_tracks.sql` |

マイグレーションを追加する際は、既存の番号と重複しないようにしてください。

また、既に適用済みのマイグレーションファイルは、原則として内容や番号を変更しないでください。データベースの適用履歴と不一致が生じる可能性があります。

### アプリを開く

**http://localhost:3000** を開きます。TypeScriptをコンパイルした後、RustサーバーがDBに接続し、マイグレーションを適用して起動します。初回はCargoの依存取得とビルドに時間がかかります。DBに接続できない場合はJSON保存へ切り替えず、エラーで停止します。

起動スクリプトはプロジェクト内の `.tools/` にRustがあれば優先し、なければ通常の `cargo` を利用します。`.tools/` はGit管理対象外なので、クローンした環境ではRustを別途インストールしてください。

## スマホから接続

同じWi-Fi上で、PowerShellから以下のように起動してください。

```powershell
$env:HOST = '0.0.0.0'
npm start
```

スマホから `http://<PCのLAN内IPアドレス>:3000` にアクセスします。PCのファイアウォールで接続許可が必要な場合があります。通常起動はlocalhostのみで待ち受けます。ポートは環境変数 `PORT` で変更できます。

## 機能と使い方

1. 最初はデモ参加者とタップの動きを体験できます。デモは履歴に保存しません。
2. 「ライブに参加する」からニックネーム、好きな曲・アーティストを登録します。
   イベントは初期表示のFESWAVE FESTIVALに参加します。イベント変更機能は無効です。既に参加済みの場合は、そのイベントを引き継ぎます。
3. 同じイベントに参加した実ユーザーの反応をSSEで同期します。
4. サーバー時刻の固定5秒窓で、1〜5回はLevel 1、6〜10回はLevel 2、11〜15回はLevel 3、16〜20回はLevel 4、21回以上はLevel 5です。本人の音符とレベル表示の色も強度に応じて変わります。
5. 同じイベント・時間帯で強度差が1以内、かつ双方が共有を許可した場合、集計後にメモリを保存します。
6. メモリはお気に入り登録が可能です。プロフィールも編集できます。

PCの通常ウィンドウとシークレットウィンドウで、独立した2ユーザーを試せます。同じブラウザのタブは同一ユーザーです。

## iTunesの曲・ジャケットをプロフィールに登録

プロフィールの作成・編集で「＋ 曲を追加する」を押し、曲名・アーティスト名・アルバム名を検索します。検索結果の「追加」で最大20曲まで選び、「完了」で登録した曲の一覧に戻ります。一覧で「アイコンにする」を押すと、その曲が一番のお気に入りになり、「アイコンに設定中」と表示します。選んだ曲のジャケットがプロフィール・ライブ画面の自分のアイコンになります。公開がオンの場合、他の参加者の画面でもバブルやメモリのアイコンとして表示します。

最初の1曲は自動で一番のお気に入りになります。同じ曲は重複追加できません。各曲の「×」で削除できます。アイコンに使っている曲を削除した場合は残った先頭の曲を一番にし、全部削除すると文字アイコンへ戻ります。画面下に常に表示する「変更を保存する」で、追加・削除・アイコンの変更を確定します。「キャンセル」で閉じると変更は保存しません。

アーティスト・曲名はアイコンに選んだ曲から自動で登録します。検索を利用しない場合は「検索せずに曲名を入力する」を開いて手入力できます。「文字アイコンの色」も開いて変更できます。登録した曲はプロフィールの「FAVORITE TRACKS」に一覧で表示し、作品紹介カードにiTunes Storeへのリンクを付けています。

Rustサーバーが日本のiTunes Search APIへ接続します。追加のAPIキー設定は不要です。音源の再生・ダウンロードは行いません。画像が取得できない場合は音符の代替表示になります。ネットワーク障害や該当曲がない場合も手入力で登録できます。

登録した曲は `user_tracks` に、曲ID・曲名・アーティスト・アルバム名・画像URL・ストアURL・並び順を保存します。`users.favorite_track_id` が一番のお気に入りを参照し、`users.music_track` にその曲の表示用スナップショットを保持します。曲一覧と一番の曲は1つのトランザクションで保存し、一番の曲が自分の登録一覧に属することをDBの外部キーでも保証します。以前の1曲登録はマイグレーションで引き継ぎます。

画像ファイル自体はサーバーへ保存しません。サーバーは曲IDから公式情報を確認するため、ブラウザから任意の画像URLを登録することはできません。共有をオフにすると、自分にはジャケットアイコンを表示しますが、相手には文字アイコンを表示し、曲の詳細・ジャケット・登録曲一覧は共有しません。画像が読み込めないときも文字アイコンへ戻ります。

検索結果・曲情報はサーバー内で15分キャッシュし、外部APIへの新しいリクエストは最短3.1秒間隔に制限します。保存済みの同じ曲でニックネーム等だけを変更する場合は、外部APIへ接続せず保存できます。

作品紹介カードには公式バッジ付きリンクを表示します。[AppleのAPI仕様・提供条件](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/index.html) と [iTunes Storeの表示ガイドライン](https://marketing.services.apple/itunes-identity-guidelines) を参照しています。公式バッジは同ガイドラインの日本語素材をそのまま使用しています。

Bluetooth、Spotify、位置・方向推定は未実装です。イベント、出演者、会場、曲表示はサンプルで、音源再生・曲認識は行いません。バブル配置は会場内の位置を示しません。

## Googleログイン（Google Identity Services）

Google公式のログインボタンで取得した **Google IDトークンをRustで直接検証**します。Firebaseの設定・SDK・APIキーは使用しません。プロフィールやお気に入り曲は既存のPostgreSQLに保存します。

### OAuthクライアントIDの作成

1. [Google Cloud ConsoleのGoogle Auth Platform](https://console.cloud.google.com/auth/clients)を開き、プロジェクトを作成または選択します。Googleログイン用のOAuth設定に、有料サービスの利用や無料トライアルの申し込みは不要です。
2. Google Auth Platformの「ブランディング」でアプリ名・サポート用メール・連絡先を設定します。「対象」で利用対象を設定し、テストユーザーの指定を求められた場合は使用するGoogleアカウントを追加します。
3. 「クライアント」→「クライアントを作成」で、種類を **ウェブアプリケーション** にします。
4. 「承認済みのJavaScript生成元」に次の2つを登録します。パスや末尾の `/` は付けません。

   ```text
   http://localhost
   http://localhost:3000
   ```

5. 作成された **クライアントID** をローカルの `.env` に設定します。

```dotenv
GOOGLE_CLIENT_ID=123456789-example.apps.googleusercontent.com
COOKIE_SECURE=false
```

6. サーバーを停止して `npm start` で再起動し、**http://localhost:3000** のプロフィール画面からログインします。

今回のポップアップ＋JavaScriptコールバック方式では、クライアントシークレット・APIキー・リダイレクトURIの設定は不要です。クライアントIDはブラウザにも渡す公開設定です。`.env` はGitに追加しないでください。`GOOGLE_CLIENT_ID` が空ならGoogleログインは無効となり、従来のゲスト利用ができます。以前の `FIREBASE_*` 環境変数は不要なので削除できます。

ローカルでは `127.0.0.1` ではなく、登録した **localhost** で開いてください。スマホではSafariやChrome等の通常のブラウザを使用します。スマホ実機からPCのLANアドレスでログインする場合はGoogleの生成元制約があるため、HTTPSの開発用URLを用意してその生成元も登録してください。公開時もHTTPSの生成元を登録し、`COOKIE_SECURE=true` を設定します。ポップアップが開かない場合はブラウザの許可設定を確認してください。

### データの引き継ぎと認証

初回ログインでは、現在のプロフィール・お気に入り曲・アイコン・参加履歴・メモリを引き継ぎます。登録済みのGoogleアカウントの場合は、そのアカウントのデータに切り替えます。別ブラウザで作成したゲストデータとの自動統合は行いません。ログアウトはこのブラウザのセッションだけを無効にし、新しいゲストに切り替えます。Googleアカウントのデータは削除されず、再ログインで復元できます。

RustはGoogleの公開鍵をキャッシュし、RS256署名・発行元（Google）・対象クライアントID・有効期限・発行時刻・`sub` を検証します。メールアドレスではなく **Googleの `sub`** をアプリのユーザーと紐づけます。ログイン要求には専用ヘッダーを必須にし、異なるOriginからの操作を拒否します。さらにセッションに紐づく30分有効のnonceをGoogle IDトークンと照合し、ログイン成功時にセッション更新と同じトランザクションで消費します。画面を長時間開いてログインに失敗した場合は再読み込みしてください。

IDトークンは永続保存せず、ログイン後は7日間有効なHttpOnly Cookieを使用します。初回の紐づけ時には以前のゲストセッションを無効化します。Googleのメールアドレス・写真はDBに保存せず、好きな曲のアイコンも変更しません。Google側の利用停止や連携解除と、発行済みのアプリセッションの即時失効は未連携です。

DB更新は起動時に自動適用します。以前のFirebase用識別情報が存在する場合も削除せず、別の名前空間に保持します。Firebase UIDとGoogleの `sub` を同一視したり、メールアドレスだけで自動統合したりはしません。

実際のGoogleアカウントでの確認は、クライアントID設定後に「既存プロフィールでログイン → ログアウト → 再ログイン」、さらに別ブラウザから同じアカウントでログインし、曲・アイコン・履歴が復元されることを確認します。ブラウザに `origin is not allowed` が出る場合は、生成元とクライアントIDの設定を確認してください。

公式資料：[設定手順](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid)、[IDトークン検証](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)、[JavaScript API](https://developers.google.com/identity/gsi/web/reference/js-reference)。ログインボタンはGoogle公式ライブラリで描画し、設定前の表示には[公式ロゴ素材](https://developers.google.com/identity/branding-guidelines)を使用しています。

## コマンド

| コマンド                                     | 内容                                                           |
| -------------------------------------------- | -------------------------------------------------------------- |
| `npm start` / `npm run dev`                  | TypeScriptをビルドしてRustサーバーを起動                       |
| `npm run build`                              | TypeScript → public/app.js                                     |
| `npm run typecheck`                          | strictモードで型チェック                                       |
| `npm run build:server`                       | Rustをビルド                                                   |
| `npm run db:up` / `npm run db:down`          | DockerのDBを起動 / 停止（データは保持）                        |
| `npm run db:local` / `npm run db:local:stop` | 専用ローカルDBを作成・起動 / 停止                              |
| `npm run db:import -- .data/store.json`      | 旧JSONをDBへ取り込み                                           |
| `npm test`                                   | 型チェック、Rust単体テスト、実PostgreSQLでのHTTP/SSE統合テスト |

自動リロードは未実装です。フロントエンド変更後は `npm run build` とブラウザ再読み込み、Rust変更後はサーバー再起動が必要です。

## データと共有

プロフィール、セッション、イベント、参加履歴、メモリはPostgreSQLに保存します。接続先は `.env` の `DATABASE_URL` で設定します。`.env` はGit管理対象外です。セッションの識別子はハッシュ化してDBに保存し、有効期限を確認します。タップ集計と接続状態はRustのメモリ上にあり、再起動でリセットされます。ゲストはCookieを失うと既存プロフィールには戻れません。Googleログイン済みなら同じアカウントで復元できます。

テーブルは `users`、`sessions`、`events`、`event_participants`、`memories`、`user_tracks`、`auth_identities` です。`auth_identities` は認証プロバイダー・Googleの `sub` と既存ユーザーを一意に紐づけ、公開プロフィールには含めません。`user_profiles` ビューで登録した曲を含むプロフィールを取得します。定義とサンプルイベントは `migrations/` で管理し、起動時に自動適用します。Dockerのデータは名前付きボリューム、専用ローカルDBのデータは `.data/postgres/` に残ります。

旧バージョンのデータがある場合は、アプリを停止して次を実行してください。

```sh
npm run db:import -- .data/store.json
npm start
```

元のJSONは変更しません。IDとCookieを維持して取り込み、既存DBの行は上書きしません。同じファイルを再実行しても履歴を重複作成しません。公開が許可されている参加者間の共感メモリのみ取り込みます。保存済みの公開プロフィールは、表示時に最新の登録情報を参照します。

共有は初期状態でオフです。参加中のニックネーム・カラー・反応は公開されます。好きな曲・アーティストと共感履歴は共有を許可した場合のみ表示します。共有をオフにすると、相手の保存済みメモリからも自分の記録を削除します。

単一RustプロセスのMVPです。HTTPSでの公開環境、複数サーバー間のリアルタイム同期、負荷対策等は今後の開発範囲です。

## 構成

- `frontend/app.ts` — UI、イベント処理、型付きAPI呼び出し
- `frontend/types.ts` — API、ユーザー、リアクション等の型
- `frontend/music.ts` — 曲検索・選択UI、ジャケットカード、画像取得失敗時の表示
- `frontend/auth.ts` — Google Identity Services、公式ログインボタン、認証エラー表示
- `src/main.rs` — Rust API、SSE、Cookie、永続化、静的ファイル配信
- `src/storage.rs` — SQLxによるPostgreSQL操作、トランザクション、旧JSON取り込み
- `src/reactions.rs` — 強度算出、共感判定、単体テスト
- `src/music.rs` — iTunes Search/Lookup接続、キャッシュ、応答の検証
- `src/auth.rs` — Google IDトークンの署名・クレーム検証と公開鍵キャッシュ
- `src/auth_tests.rs` — テスト用署名鍵と実PostgreSQLによるログイン統合テスト
- `migrations/` — テーブル定義とサンプルイベント
- `compose.yaml` / `.env.example` — 開発用DBと環境設定
- `public/` — HTML、CSS、コンパイル済みJavaScript
- `public/app-shell.css` — 最大430pxのスマホ向け画面
- `scripts/cargo.mjs` — Rust起動・ビルドを補助する開発用スクリプト
- `test/server.test.mjs` — 実際のRustサーバーを使うHTTP/SSE統合テスト

`npm test` の前にDBを起動してください。統合テストは同じDB内にランダムな専用スキーマを作成し、終了後にそのスキーマだけを削除します。通常のテーブルは変更しません。テスト用ユーザーにはスキーマ作成権限が必要です。別のDBを使う場合は `TEST_DATABASE_URL` を指定できます。

セッション分離・期限切れ、SSE、共感保存、再起動後のデータ保持、お気に入り所有権、共有取り消し、非公開プロフィール、旧JSON取り込みと再実行、イベント検証、外部Origin拒否を確認します。

認証テストではテスト専用のRSA署名鍵を使用して、署名改ざん・別クライアント・期限切れ・不正な発行元・nonce不一致・使い回しの拒否と、ログインによるデータ引き継ぎ・別ブラウザからの復元・Cookie更新・ログアウトを確認します。`test/fixtures/auth-test-*` は公開可能なテスト用データで、アプリ本体のトークン検証には使用しません。実際のGoogleログイン画面はOAuthクライアントID設定後に手動確認が必要です。
