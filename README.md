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
2. 「ライブに参加する」からニックネーム、好きな曲・アーティスト、カラーを登録します。
3. 同じイベントに参加した実ユーザーの反応をSSEで同期します。
4. サーバー時刻の固定5秒窓で、1〜2回はLevel 1、3〜5回はLevel 2、6回以上はLevel 3です。
5. 同じイベント・時間帯で強度差が1以内、かつ双方が共有を許可した場合、集計後にメモリを保存します。
6. メモリはお気に入り登録とJSON出力が可能です。プロフィールも編集できます。

PCの通常ウィンドウとシークレットウィンドウで、独立した2ユーザーを試せます。同じブラウザのタブは同一ユーザーです。

Bluetooth、Spotify、位置・方向推定、アカウント認証は未実装です。イベント、出演者、会場、曲表示はサンプルで、音源再生・曲認識は行いません。バブル配置は会場内の位置を示しません。

## コマンド

| コマンド | 内容 |
| --- | --- |
| `npm start` / `npm run dev` | TypeScriptをビルドしてRustサーバーを起動 |
| `npm run build` | TypeScript → public/app.js |
| `npm run typecheck` | strictモードで型チェック |
| `npm run build:server` | Rustをビルド |
| `npm run db:up` / `npm run db:down` | DockerのDBを起動 / 停止（データは保持） |
| `npm run db:local` / `npm run db:local:stop` | 専用ローカルDBを作成・起動 / 停止 |
| `npm run db:import -- .data/store.json` | 旧JSONをDBへ取り込み |
| `npm test` | 型チェック、Rust単体テスト、実PostgreSQLでのHTTP/SSE統合テスト |

自動リロードは未実装です。フロントエンド変更後は `npm run build` とブラウザ再読み込み、Rust変更後はサーバー再起動が必要です。

## データと共有

プロフィール、セッション、イベント、参加履歴、メモリはPostgreSQLに保存します。接続先は `.env` の `DATABASE_URL` で設定します。`.env` はGit管理対象外です。セッションの識別子はハッシュ化してDBに保存し、有効期限を確認します。タップ集計と接続状態はRustのメモリ上にあり、再起動でリセットされます。Cookieを失うと既存プロフィールには戻れません。

テーブルは `users`、`sessions`、`events`、`event_participants`、`memories` です。定義とサンプルイベントは `migrations/` で管理し、起動時に自動適用します。Dockerのデータは名前付きボリューム、専用ローカルDBのデータは `.data/postgres/` に残ります。

旧バージョンのデータがある場合は、アプリを停止して次を実行してください。

```sh
npm run db:import -- .data/store.json
npm start
```

元のJSONは変更しません。IDとCookieを維持して取り込み、既存DBの行は上書きしません。同じファイルを再実行しても履歴を重複作成しません。公開が許可されている参加者間の共感メモリのみ取り込みます。保存済みの公開プロフィールは、表示時に最新の登録情報を参照します。

共有は初期状態でオフです。参加中のニックネーム・カラー・反応は公開されます。好きな曲・アーティストと共感履歴は共有を許可した場合のみ表示します。共有をオフにすると、相手の保存済みメモリからも自分の記録を削除します。既にダウンロードされたファイルは削除できません。

単一RustプロセスのMVPです。公開運用向けのアカウント認証、HTTPS、複数サーバー間のリアルタイム同期、負荷対策等は今後の開発範囲です。

## 構成

- `frontend/app.ts` — UI、イベント処理、型付きAPI呼び出し
- `frontend/types.ts` — API、ユーザー、リアクション等の型
- `src/main.rs` — Rust API、SSE、Cookie、永続化、静的ファイル配信
- `src/storage.rs` — SQLxによるPostgreSQL操作、トランザクション、旧JSON取り込み
- `src/reactions.rs` — 強度算出、共感判定、単体テスト
- `migrations/` — テーブル定義とサンプルイベント
- `compose.yaml` / `.env.example` — 開発用DBと環境設定
- `public/` — HTML、CSS、コンパイル済みJavaScript
- `public/app-shell.css` — 最大430pxのスマホ向け画面
- `scripts/cargo.mjs` — Rust起動・ビルドを補助する開発用スクリプト
- `test/server.test.mjs` — 実際のRustサーバーを使うHTTP/SSE統合テスト

`npm test` の前にDBを起動してください。統合テストは同じDB内にランダムな専用スキーマを作成し、終了後にそのスキーマだけを削除します。通常のテーブルは変更しません。テスト用ユーザーにはスキーマ作成権限が必要です。別のDBを使う場合は `TEST_DATABASE_URL` を指定できます。

セッション分離・期限切れ、SSE、共感保存、再起動後のデータ保持、お気に入り所有権、共有取り消し、非公開プロフィール、旧JSON取り込みと再実行、イベント検証、外部Origin拒否を確認します。
