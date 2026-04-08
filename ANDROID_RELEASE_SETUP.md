# Android Release Setup

Android 版を iPhone 版に影響を出さずに進めるためのメモです。

## 今回入っているもの

- アプリ名のリソース化
- Android adaptive icon 対応
- `Codemagic` の `android-release` ワークフロー
- `AAB` 出力対応

## アイコン

元画像:

- [app-icon-source-1024.png](C:\Users\fermata\書き順アプリ\assets\branding\app-icon-source-1024.png)

主な反映先:

- [AndroidManifest.xml](C:\Users\fermata\書き順アプリ\android\app\src\main\AndroidManifest.xml)
- [mipmap-anydpi-v26](C:\Users\fermata\書き順アプリ\android\app\src\main\res\mipmap-anydpi-v26)

## リリース署名

`android/app/build.gradle.kts` は `key.properties` があるときだけ release 署名を使います。

必要ファイル:

- `android/key.properties`
- keystore ファイル本体

`key.properties` 例:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

## Codemagic

使うワークフロー:

- `ios-app-store`
- `android-release`

Android はまず `AAB` を作るところまで入っています。  
Google Play への自動公開はまだ入れていません。

## 次に必要なこと

1. Android 用 keystore を作る
2. `key.properties` を用意する
3. Codemagic で `android-release` を実行する
4. `build/app/outputs/bundle/release/*.aab` を Play Console にアップロードする
