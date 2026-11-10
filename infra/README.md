# 本番APIのデプロイ

本番はGCPプロジェクト `feswave` の東京リージョンを使う。Cloud RunがRust APIを実行し、Cloud SQL for PostgreSQL 17にUnixソケット経由で接続する。配布用APKの接続先は `https://feswave-api-933816421570.asia-northeast1.run.app/api/`。ローカルのUSBデバッグは[開発手順](../README.md#曲検索とプロフィール同期)を使う。

- Pull RequestではTerraformの書式・構成、PostgreSQLを使うAPIテスト、コンテナビルドを検証する。
- `services/api/`、`infra/`、APIワークフローの変更がmainに入ると、GitHub Actionsの「FESWAVE API」がテスト、Artifact Registryへのpush、Terraformのplan・apply、公開 `/healthz` のDB疎通確認を順に行う。手動再実行もmainを指定する。
- 通常の本番構成は `infra/production` で変更する。DBのパスワードを含むstateは非公開のバージョニング付きGCSバケットに置き、APIはSecret Managerのバージョンを参照する。既存DBへのマイグレーションは旧リビジョンと共存できる変更にする。
- 認証基盤、stateバケット、イメージリポジトリは管理者が `infra/bootstrap` で管理する。bootstrapのstateも同じバケットの専用prefixに保存する。管理者の再適用手順は次のとおり。GitHubはmainのデプロイワークフローだけがWorkload Identity Federationで認証できる。
- Googleログインを有効化するときはGitHubのproduction環境変数 `GOOGLE_CLIENT_ID` にWebクライアントIDを設定し、ワークフローを再実行する。

```sh
cd infra
mise install
gcloud auth application-default login
mise exec -- terraform -chdir=bootstrap init -backend-config=bucket=feswave-feswave-tfstate
mise exec -- terraform -chdir=bootstrap apply -var=project_id=feswave
```

空のプロジェクトから再構築するときは、先に `gcloud storage buckets create gs://PROJECT_ID-feswave-tfstate --project=PROJECT_ID --location=asia-northeast1 --uniform-bucket-level-access` でstate用バケットを作り、bootstrapのinit後に `terraform -chdir=bootstrap import -var=project_id=PROJECT_ID google_storage_bucket.state PROJECT_ID-feswave-tfstate` で取り込む。プロジェクトを移す場合はワークフローのプロジェクトID・番号とAPKの接続先も合わせて更新する。
