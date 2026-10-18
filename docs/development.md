# Development

Develop on `dev` and commit independently verified changes there. Promote to
`main` only when a release build is needed: each push to `main` triggers the
full build matrix and updates Nightly.

## Toolchain

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
  includes Android, Linux, Windows, macOS and unsigned iOS archives, plus SHA-256
  checksums. Unix archives preserve permissions and symbolic links.
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

macOS uses the legacy system Keychain through flutter_secure_storage, avoiding
cross-app Keychain Sharing. Test secure storage on your signed/distributed build.
iOS signing and Keychain access must likewise be checked on a device. Linux
requires an available Secret Service at runtime. There is no plaintext fallback.

## Initial scope

- One local library, with all-materials or per-document practice scope.
- Single-choice questions with four distinct options.
- UTF-8 TXT/Markdown and text PDFs, up to 20 MB per file and one million extracted
  characters. Scanned PDFs need external OCR; office formats are not supported.
- Folder import is a manual recursive scan; hidden files and symlinks are skipped.
  Removing a file from the original directory does not delete its imported copy
  of extracted text. Remove it explicitly from Library.
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
