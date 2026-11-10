# Third-party licenses

FESWAVEの第三者ソフトウェア、外部サービス、素材の出典です。ライセンス本文と著作権表示は次のファイルに収録しています。

| 対象 | 出典と収録範囲 |
| --- | --- |
| [Flutter・Dart・エンジンとパッケージ](third_party_licenses/flutter.txt) | [v0.1.0の配布APK](https://github.com/mashumarrow/feswave/releases/tag/v0.1.0)に同梱された `assets/flutter_assets/NOTICES.Z` の展開原文。アプリのバージョン固定は [pubspec.lock](apps/feswave_android/pubspec.lock) を参照 |
| [Androidネイティブ依存](third_party_licenses/android.txt) | Gradleの `debugRuntimeClasspath` で解決したMaven座標・版、各POMのライセンスと配布物中の通知。Google IdentityとGoogle Play servicesには各POM記載のAndroid SDK利用規約が適用される |
| [Rust APIの依存](third_party_licenses/rust.txt) | [Cargo.lock](services/api/Cargo.lock) をLinux x86_64向けに解決したクレートの名称・版・ライセンス指定・入手先、配布ソースのライセンスと通知。ビルド依存を含む |
| [APIテスト用のNode.js依存](third_party_licenses/node.txt) | [package-lock.json](services/api/package-lock.json) のパッケージと配布元の通知 |

Android版には[Material Icons](https://github.com/google/material-design-icons)（Google、Apache-2.0）と[SQLite](https://sqlite.org/copyright.html)（パブリックドメイン）も含まれます。APIのデータベースには[PostgreSQL](https://www.postgresql.org/about/licence/)を使用します。コンテナ内のDebianパッケージの著作権表示は各パッケージの `/usr/share/doc/<package>/copyright` にあります。

## 外部サービスと素材

| 対象 | アプリでの使用と出典 |
| --- | --- |
| Google「G」ロゴ | Google LLCのログインボタン用ロゴをプロフィール画面に表示。[Sign in with Google Branding Guidelines](https://developers.google.com/identity/branding-guidelines) |
| Google Identity | Credential Managerを通じたGoogleログインと、サーバーでのIDトークン検証。[Google APIs Terms of Service](https://developers.google.com/terms) |
| iTunes Search API | Apple Inc.のAPIで楽曲を検索し、曲名・アーティスト名・作品ページのURLを取得。[iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/index.html) |
| ジャケット画像 | APIから取得した各作品の画像をプロフィールなどに表示。画像の権利者は作品ごとに異なります。Appleの条件には、対象作品の販売ページへリンクする承認済みバッジの近接表示などが含まれます。[Appleの利用条件](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/index.html#//apple_ref/doc/uid/TP40017632-CH3-SW1) |
