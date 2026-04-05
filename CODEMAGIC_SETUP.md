# もじれん: GitHub -> Codemagic -> App Store Connect

## 1. GitHub に push

このフォルダを GitHub リポジトリに push します。

## 2. Codemagic でリポジトリ接続

- Codemagic で GitHub リポジトリを接続
- `codemagic.yaml` を使う設定にする

## 3. Apple 側で用意するもの

- Apple Developer Program 登録
- App Store Connect のアプリ作成
- App Store Connect API key
- iOS Distribution certificate
- App Store 用 Provisioning Profile

## 4. Codemagic の Integration 名

`codemagic.yaml` では次の integration 名を使っています。

- `codemagic-app-store-connect`

Codemagic 側で同じ名前にするか、`codemagic.yaml` を書き換えてください。

## 5. App Store Apple ID

`codemagic.yaml` の `APP_STORE_APPLE_ID` は現在次の値です。

- `6761683947`

この値は App Store Connect の `もじれん` に対応しています。

## 6. 現在の Bundle ID

- App 名: `もじれん`
- Bundle ID: `com.jppiennm.mojiren`

変更が必要な主な場所:

- `ios/Runner.xcodeproj/project.pbxproj`
- `android/app/build.gradle.kts`
- `codemagic.yaml`

## 7. TestFlight へ送る

このワークフローは `submit_to_testflight: true` です。

最初は App Store 本提出ではなく TestFlight までにしてあります。
問題なければ `submit_to_app_store: true` に切り替えます。

## 8. 注意

- 実際の審査提出にはアプリアイコン、スクリーンショット、説明文、プライバシー情報が必要です。
- App Store 提出前に、説明文、スクリーンショット、プライバシー情報も埋める必要があります。
