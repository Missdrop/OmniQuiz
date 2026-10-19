# Development

Develop on `dev` and commit independently verified changes there. Promote to
`main` only when a release build is needed: each push to `main` triggers the
full build matrix and updates Nightly.

## App icons

The approved logo is `assets/branding/logo.png`. It is shared by the app UI,
README, and Linux window icon. To regenerate Android, iOS, macOS, and Windows
launcher icons after replacing it, run `./scripts/dart run flutter_launcher_icons`
(on Windows: `scripts/dart.ps1 run flutter_launcher_icons`). Configuration lives
in `flutter_launcher_icons.yaml`. Commit the generated platform icons alongside
the source asset. Design candidates, prompts, and internal architecture notes
stay local and are ignored by Git.

Review the generated diff: version 0.14.4 can incorrectly replace the iOS
`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` boolean with
`AppIcon`. Keep that setting at `YES`; changing the existing icon artwork does
not require changing the Xcode project settings.

## Toolchain setup

The project is developed with Flutter 3.47.7 / Dart 3.13.5. `pubspec.lock` pins
application dependencies. `scripts/bootstrap`, `scripts/flutter`, and
`scripts/dart` use a project-local SDK and caches under `.tooling/`.
The bootstrap script does not install Xcode, Android Studio, Visual Studio,
or operating-system libraries.

```sh
./scripts/bootstrap
./scripts/flutter devices
./scripts/flutter run -d macos
./scripts/dart format lib test
./scripts/flutter analyze
./scripts/flutter test
```

Widget tests use fake AI and credentials with a real in-memory SQLite database.
They exercise import, settings, buffering, answer submission, and review.
Preview PNGs are written to `.tooling/previews/` and are not committed. API
adapter tests use an HTTP test double, not a paid service. A successful suite
does not establish a particular provider's compatibility or answer quality.

For a live smoke test, run the app and use **Test connection** with your own
endpoint/model/key. Then import a small document and generate questions.
Check both a correct and an incorrect answer, restart the app, and confirm
that the cached questions and review queue persist. No real API key is bundled.

### Windows PowerShell

Enable Windows Developer Mode for plugin symlinks. Install Visual Studio's
Desktop development with C++ workload, including ATL, CMake, and a Windows SDK.
Then run from the repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 doctor -v
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 analyze
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 test
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/flutter.ps1 run -d windows
```

The PowerShell wrappers use the same pinned Flutter version and project-local
caches as the Bash scripts. They change environment variables only in the
invoked process; no persistent PATH or execution-policy change is required.
For Android, extract a Windows JDK 17 into `.tooling/jdk` and install SDK tools
under `.tooling/android-sdk`. The wrappers detect `jdk/bin/java.exe` automatically.
SDK 36, build-tools 36.0.0, and NDK 28.2.13676358 match the pinned Flutter SDK.
Use `scripts/dart.ps1` for Dart commands.

## Native build requirements

| Target | Requirements | Build command |
| --- | --- | --- |
| Android | JDK 17, Android SDK, accepted SDK licenses | `flutter build apk --debug` |
| iOS | macOS, full Xcode; signing for physical devices | `flutter build ios --release --no-codesign` |
| macOS | macOS and full Xcode | `flutter build macos --release` |
| Windows | Windows, Visual Studio C++ desktop tools including ATL | `flutter build windows --release` |
| Linux | Clang, CMake, Ninja, GTK 3, libsecret and jsoncpp development libraries | `flutter build linux --release` |

Use `./scripts/flutter` in place of `flutter` for the isolated local setup.
The wrapper uses `.tooling/android-sdk` and `.tooling/gradle`; install Android
SDK components there if using this workflow. It also isolates Android user data
and emulator data under `.tooling/`. A JDK extracted into
`.tooling/jdk/Contents/Home` is detected automatically on macOS. The wrapper
does not install Java or change the system PATH.

GitHub Actions defines tests and builds for all five targets. Android artifacts
are debug builds. Apple artifacts are not notarized/App Store releases; an
unsigned iOS build is a compilation check, not an installable iPhone release.
Check each workflow run before assuming a target passed. No release signing
keys are stored in this repository.

## Releases

- Push any tag except the reserved `nightly` tag to publish a regular release.
  Its title is exactly the tag name. Update `pubspec.yaml` before tagging a new
  app version; the tag does not change the embedded application version.
- Every push to `main` updates the single **Nightly** prerelease. Other branches
  do not publish. You can also run **Rolling prerelease** manually on `main`.
- Both workflows require tests and all five native builds to pass. Each release
  includes Android APK, Windows MSI and portable ZIP, macOS DMG and TAR.GZ,
  Linux TAR.GZ, and unsigned iOS TAR.GZ, plus SHA-256 checksums.
  Unix archives preserve permissions and symbolic links.
- Nightly reuses the same release ID and asset names, and moves the `nightly`
  tag to the built commit. It does not delete and recreate the release. Existing
  assets are replaced individually, so replacement is not atomic; rerun a failed
  publishing job to repair a partial upload. Build failures leave assets untouched.
- Publishing is serialized and never cancelled by a newer push. Outdated main
  builds are skipped; rapid pushes may be coalesced to the newest pending run.
  Published regular releases are left unchanged when a workflow is rerun.
- Workflows use the built-in `GITHUB_TOKEN`; only publishing jobs can write to
  the repository. Keep `nightly` mutable if you enable immutable releases or tag
  protection rules. The rolling workflow cannot update an immutable release.

Android APKs currently use temporary debug signing keys, so upgrading across
builds may require uninstalling the previous app (which removes local data).
Apple artifacts are unsigned/not notarized as described above. Release automation
does not add distribution certificates or turn the iOS archive into an installable IPA.

### Desktop installers

After building, run `python scripts/package_release.py windows` or `macos` on
the corresponding OS. Output goes to the ignored `dist/` directory.

Windows packaging requires Python, .NET SDK 8, and WiX 5.0.2:

```powershell
dotnet tool install wix --version 5.0.2 --tool-path .tooling/wix
.tooling/wix/wix.exe extension add WixToolset.UI.wixext/5.0.2
python scripts/package_release.py windows
```

The MSI installs for all users under Program Files (administrator permission
required), adds a Start menu shortcut, and supports Windows uninstall/repair.
Both MSI and ZIP bundle the x64 C++ runtime DLLs from Visual Studio's
redistributable directory. No prerequisite download is needed during installation.
The ZIP is an alternative for users without administrator access.
Uninstall removes installed application files, not the user's library or settings.
The MSI is currently unsigned.

The stable `UpgradeCode` in `packaging/windows/OmniQuiz.wxs` identifies the app
across versions. MSI uses the three numeric fields from `pubspec.yaml` and
allows same-version replacement for Nightly builds; build metadata after `+`
is not an MSI version. Consequently, an older Nightly with the same version
can replace a newer one. Increment the app version for numbered releases.

macOS packaging uses the system `ditto` and `hdiutil` tools, preserves the app
bundle, includes an Applications shortcut, and verifies the generated DMG.
It does not add Developer ID signing or notarization. Linux and iOS keep their
existing archives; no installer is generated for those targets.

macOS uses the legacy system Keychain through flutter_secure_storage, avoiding
cross-app Keychain Sharing. Test secure storage on your signed/distributed build.
iOS signing and Keychain access must likewise be checked on a device. Linux
requires an available Secret Service at runtime. There is no plaintext fallback.

## Initial scope

- Multiple local libraries, each with all-materials or per-document practice scope.
- Single-choice questions with four distinct options.
- UTF-8 TXT/Markdown and text PDFs, up to 20 MB per file and one million extracted
  characters. Scanned PDFs need external OCR; office formats are not supported.
- Each library binds to an existing desktop folder or an app-managed folder.
  Recursive scans run on startup, switch, resume, and manually; hidden entries and
  symlinks are skipped. Mobile platforms use managed folders and file import.
  Scans read one file at a time (no 100-file directory cap). The 20 MB per-file and
  extracted-text limits still apply. A failed file does not block other imports.
- Imported files are copied into the current material folder. Different content
  with the same filename gets a hash suffix; existing files are never overwritten.
  Changed sources invalidate old questions. A successful scan removes missing
  source indexes and stops using their questions, preserving attempts. An
  unavailable folder or incomplete traversal never clears the cached library.
  Removing a source in the UI only removes its index; a later scan reimports a
  file still present on disk.
- The model assigns a topic to each question. Review is question-based; a separate
  knowledge graph and adaptive topic mastery model are not implemented.
- Provider JSON mode is optional. Not every "OpenAI-compatible" endpoint accepts
  the same parameters. Use an HTTPS base URL, typically ending in `/v1`.
  Plain HTTP is accepted only for loopback addresses, not remote hosts.
- The buffer uses one request at a time, at most ten questions per request, a low
  watermark of five, and a target of twenty. Small sources may run out of useful
  non-duplicate questions; generation then stops with an explanation.
- Network/server/rate-limit failures get at most two retries. A timeout can still
  incur provider charges. Interrupted jobs are cancelled on restart and a user
  starts a new fill; paid requests are not replayed automatically.
- Correct answers on the first attempt do not enter Review. Wrong answers are due
  again in ten minutes, then after one, three, and seven days as correct reviews
  accumulate. "Review early" explicitly allows practice before the due time.
- Data stays on one device. Cloud sync, backups/exports, OCR, folder watching,
  and ChatGPT subscription authorization are not included in this release.

## Library storage and lifecycle

`omniquiz.sqlite` remains the default library database. Existing documents,
questions, attempts and reviews stay in place. Its `settings` table also stores
the library catalog, active library, global AI profile and interface language.
Other libraries use `libraries/<uuid>/quiz.sqlite` under application support;
managed source folders use `libraries/<uuid>/materials`. External source folders
contain only the user's materials. Library names never become file paths.
Overlapping source directories are rejected to keep copied files in one library.

Each session receives its own material, question, progress and job repositories.
Only AI preferences and language use the global database; API secrets remain in
system secure storage. Switching stops the old generator, replaces the router
and all study view models, then disposes the old session after detaching widgets.
Delayed model responses cannot publish into the next library. A global database
handle is shared intentionally and is never closed by a study session.

macOS uses the `omniquiz/folders` platform channel to retain security-scoped
bookmarks in app preferences and restore access after restart. Both macOS builds
require user-selected read/write and app-scope bookmark entitlements. Use
**Grant folder access** to reselect the same directory if authorization expires.
Native bookmark behavior must be checked in a sandboxed macOS build. Android and
iOS do not request unrestricted directory access; users import into managed folders.
This does not implement continuous filesystem watching or cross-device sync.

## Code map

Interface translations live in `lib/l10n/app_en.arb` and `app_zh.arb`.
Run `flutter gen-l10n` after editing them. `LanguageViewModel` persists the
interface preference independently of AI profiles, so switching UI languages
does not cancel generation or require an API key. System language is the default.
`localization.dart` translates existing application diagnostics and stored source
locations at the presentation boundary; it never translates user documents or
cached AI questions. New questions use the provider profile's question language.


- `lib/domain`: immutable models, question invariants, review and buffer policies.
- `lib/application`: interfaces, import/settings use cases, validation, generation coordination.
- `lib/infrastructure`: Drift repositories, HTTP adapter, document parsers, system storage.
- `lib/presentation`: view models and adaptive pages.
- `lib/app`: concrete dependency composition, lifecycle, routing, theme.

Drift adapters currently use parameterized SQL and explicit schema migrations,
with JSON snapshots for question content and source references. Do not import
infrastructure classes from the domain/application layers. Add behavioral tests
for new invariants and external boundaries; avoid a base-class hierarchy.
