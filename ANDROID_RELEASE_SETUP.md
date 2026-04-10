# Android Local Release Setup

Use this guide when you want to build an Android `AAB` locally instead of using Codemagic.

## Requirements

- Flutter SDK
- Android SDK
- JDK
- A working `flutter doctor`

Both `flutter` and `keytool` must be available from PowerShell.

## 1. Create the upload keystore

Run this from the project root:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\create_android_keystore.ps1
```

This creates `upload-keystore.jks` in the project root.

If you want to pass the passwords from the command line:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\create_android_keystore.ps1 -StorePassword YOUR_STORE_PASSWORD -KeyPassword YOUR_KEY_PASSWORD
```

## 2. Create android\key.properties

Copy `android\key.properties.example` to `android\key.properties` and fill in the real values.

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=../upload-keystore.jks
```

## 3. Build the AAB

Use the version from `pubspec.yaml`:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_aab.ps1
```

Run analyze and tests before building:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_aab.ps1 -RunChecks
```

Override the version for one build:

```powershell
powershell -ExecutionPolicy Bypass -File .\tool\build_android_aab.ps1 -BuildName 1.0.8 -BuildNumber 9
```

## Output

The generated bundle is written here:

`build\app\outputs\bundle\release\app-release.aab`

## Related files

- `android\app\build.gradle.kts`
- `android\key.properties`
- `android\key.properties.example`
- `tool\create_android_keystore.ps1`
- `tool\build_android_aab.ps1`

## Notes

- `android\key.properties` and `*.jks` are already ignored by git.
- These Android changes do not change the iPhone build settings.
