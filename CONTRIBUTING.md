# Contributing to OmniQuiz

Thanks for helping improve OmniQuiz (万物一点通). For bugs, include the app version, OS, steps to reproduce and expected behavior. Remove private study materials, email addresses and credentials from logs and screenshots. GitHub issues are public.

For a larger feature, open an issue first so we can agree on scope. Send focused pull requests to **`dev`**, describe the user-visible change and include relevant test results. Keep generated outputs, personal libraries, private keys, design candidates and AI prompts out of the repository.

## Set up

Use **Flutter 3.47.7 / Dart 3.13.5**. Dependencies are pinned in `pubspec.lock`. The wrappers below keep the Flutter SDK and caches inside ignored `.tooling/`; native build tools must be installed separately.

### Windows

Enable Developer Mode for plugin symlinks. Install Visual Studio's **Desktop development with C++** workload, including ATL, CMake and a Windows SDK.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 doctor -v
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 run -d windows
```

### macOS / Linux

```sh
./scripts/bootstrap
./scripts/flutter doctor -v
./scripts/flutter devices
./scripts/flutter run -d macos  # or linux / your Android device ID
```

### Native tools

| Target | Requirements |
| --- | --- |
| Windows | Windows and Visual Studio C++ desktop tools, including ATL |
| Android | Full JDK 21, Android SDK platform 36, build-tools 36.0.0, NDK 28.2.13676358, CMake 3.22.1 and accepted SDK licenses |
| macOS | macOS and full Xcode |
| iOS | macOS, full Xcode and an installed simulator runtime; a device build needs signing |
| Linux | Clang, CMake, Ninja, pkg-config, GTK 3, libsecret and jsoncpp development libraries |

Android plugins may also request SDK platform 35. The wrappers detect `.tooling/android-sdk` and `.tooling/jdk` (on macOS, `.tooling/jdk/Contents/Home`). They do not install Java or native platform tools.

## Make a change

- Keep domain logic and use cases separate from Flutter UI, transport and persistence.
- Add comments explaining intent, constraints and non-obvious decisions; keep names and functions readable.
- Update both `lib/l10n/app_en.arb` and `lib/l10n/app_zh.arb` for UI text, then run `flutter gen-l10n` through the wrapper.
- Preserve cached questions when changing AI connections or generation requirements. Never silently switch billing sources or retry an uncertain paid request.
- Keep credentials in OS secure storage. Do not put tokens, prompts or document contents in diagnostic logs or backups.
- Add focused regression tests for behavior changes. Test actual native interactions when a change affects browser return, platform storage, PDF viewing or window behavior.

### Code map

| Path | Responsibility |
| --- | --- |
| `lib/domain/` | Models, connection types, generation guidance and policies |
| `lib/application/` | Use cases, generation coordinator and infrastructure ports |
| `lib/infrastructure/` | AI transports, document parsing, persistence, platform adapters and updates |
| `lib/presentation/` | Pages, widgets and view models |
| `lib/app/` | Dependency wiring, library lifecycle, distribution mode and theme |
| `test/`, `integration_test/` | Unit/widget tests and native interaction tests |
| `scripts/`, `packaging/`, `.github/workflows/` | Tooling, installers and release automation |

Libraries store their database, examples and requirements under `.omniquiz/`. Global connection settings stay device-specific, with secrets referenced from secure storage. Use temporary libraries and synthetic credentials in tests rather than modifying personal app data.

## Verify

On macOS/Linux:

```sh
./scripts/dart format --output=none --set-exit-if-changed lib test
./scripts/flutter analyze
./scripts/flutter test --timeout 90s
node --test scripts/publish-release.test.cjs
python -m unittest discover -s scripts -p 'test_*.py'
```

On Windows, use `scripts/dart.ps1` and `scripts/flutter.ps1` for the corresponding Dart/Flutter commands. Node.js 22 and Python 3 are needed for script tests.

### Native interaction tests

Use a disposable emulator or simulator: Flutter installs the test entry point under the application's normal ID. Never use a personal library or saved production credentials.

```sh
./scripts/flutter test integration_test/connection_management_test.dart -d DEVICE_ID --timeout 180s
./scripts/flutter test integration_test/generation_guidance_test.dart -d DEVICE_ID --timeout 180s
./scripts/flutter test integration_test/ui_interaction_test.dart -d DEVICE_ID --timeout 180s
./scripts/flutter test integration_test/mobile_auth_test.dart -d DEVICE_ID --timeout 180s
```

Use the PowerShell wrapper on Windows. Run Android browser tests with Chrome's first-run setup completed. The authentication test uses synthetic OAuth/JWKS/Responses fixtures with real native browser callbacks and secure storage; it does not log into a real account or consume subscription allowance. A simulator pass does not establish physical-device behavior. Test signed devices separately when changing lifecycle or authorization code. Shut down test simulators when finished.

## Build and package

Use the appropriate wrapper in place of `flutter`:

```sh
flutter build windows --release
flutter build macos --release
flutter build linux --release
flutter build ios --release --no-codesign
flutter build apk --debug
```

Run each build on a supported host. Then run `python scripts/package_release.py TARGET` with `windows`, `macos`, `linux`, `ios` or `android`. Packages go to ignored `dist/`.

Windows packaging requires Python, .NET SDK 8 and WiX 5.0.2:

```powershell
dotnet tool install wix --version 5.0.2 --tool-path .tooling/wix
.tooling/wix/wix.exe extension add WixToolset.UI.wixext/5.0.2
python scripts/package_release.py windows
python scripts/verify_windows_package.py
```

The MSI and portable ZIP bundle Visual C++ runtime DLLs. Preserve the MSI `UpgradeCode` so upgrades remain compatible. Windows packages are currently unsigned. macOS packaging verifies the app bundle and DMG, but does not add notarization. The iOS archive is unsigned, not a directly installable IPA.

### Android signing

Release APKs must reuse the existing private signing identity; do not generate a new key for a normal update. The repository stores no private signing files. Maintainers configure `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD` and `ANDROID_KEY_ALIAS` as GitHub Actions secrets. Pull-request builds use debug APKs without those secrets.

Local signed builds need a privately configured keystore and an increasing build number:

```sh
flutter build apk --release --split-per-abi --build-number NUMBER
python scripts/package_release.py android
```

CI derives the base Android build number from seconds since 2024-01-01; Flutter adds ABI-specific codes. Choose a local number above the installed build when testing upgrades.

### Microsoft Store

Store identity is in `packaging/windows/store.json`. Build on Windows:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/package_store.ps1
python scripts/verify_store_package.py
```

Store builds use `OMNIQUIZ_STORE=true` and Store-managed updates. Keep this separate from standalone MSI/ZIP updates; packaging locally does not submit anything to the Store.

### Icons

The approved source is `assets/branding/logo.png`. To update launchers, run `dart run flutter_launcher_icons` through the wrapper and review generated changes. In the iOS project, keep `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES`; the icon tool must not replace it with `AppIcon`. Preserve font and asset licenses.

## Release workflow

Releases are maintainer actions. A push to `main` runs the full matrix and updates **Nightly**; `dev` does not publish automatically. A tag such as `v1.1.0` triggers a same-name stable Release after tests and all five platform builds pass. Update `pubspec.yaml` before tagging: tags do not change the embedded app version.

The release contains three signed Android APKs, Windows MSI/ZIP, macOS DMG/tar.gz, Linux tar.gz and an unsigned iOS tar.gz. No separate `SHA256SUMS` file is uploaded; GitHub provides asset digests. Published stable assets are not replaced by rerunning the workflow. Verify downloads, embedded versions and signing continuity before announcing a release.

## License

Contributions are distributed under [GPL-3.0-only](LICENSE). Include license and provenance information for third-party code, fonts and other assets.
