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

On Linux, Android builds require a **full JDK 21**, including `javac`, plus
Android platform 36, build-tools 36.0.0, NDK 28.2.13676358, and CMake 3.22.1.
Plugins also request platform 35; Gradle installs it when SDK licenses are accepted.
Install the SDK packages with Google's command-line tools under
`.tooling/android-sdk`. A local Linux JDK can live at `.tooling/jdk`; the wrapper
selects it automatically. A Java runtime alone cannot compile Android plugins.

Linux desktop builds require Clang, CMake, Ninja, pkg-config, GTK 3 development
headers, libsecret development headers, and jsoncpp development headers. For a
rootless Debian environment, signed distribution packages may be extracted into
`.tooling/linux-sysroot`. Rebase their pkg-config prefixes to that directory and
ensure development-library symlinks resolve to the corresponding runtime
libraries. `scripts/linux_environment.sh` activates this optional local prefix.
It is specific to Debian x86-64; other hosts should install their native packages.
Xvfb enables a headless startup smoke test. Toolchains and logs remain ignored.

Build release artifacts with `./scripts/flutter build linux --release` and
`./scripts/flutter build apk --release --split-per-abi --build-number NUMBER`
(use a growing Android build number as described below). Package outputs with
`python scripts/package_release.py linux` and
`python scripts/package_release.py android`.
Windows requires a Windows host; macOS and iOS require macOS/Xcode.
Use the manually dispatched CI workflow on `dev` for those hosts without
promoting changes to `main`. Running it requires GitHub Actions access and
network access to `api.github.com`.

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

Android published APKs use a fixed release identity. PR checks compile debug
APKs without exposing release keys. Existing previews used temporary debug keys;
switching to the release identity may require uninstalling once. Export an app
backup first, reinstall, and restore it. Subsequent releases use the same key.
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
  Scans process one file at a time (no 100-file directory cap). Automatic scans
  reuse per-library size/mtime hints only for successfully imported revisions;
  **Verify all files** rereads every non-excluded file to catch changes that kept
  their metadata. Progress shows the current file and checked count; stopping
  keeps completed imports. The 20 MB per-file and
  extracted-text limits still apply. A failed file does not block other imports.
- Imported files are copied into the current material folder. Different content
  with the same filename gets a hash suffix; existing files are never overwritten.
  Changed sources invalidate old questions. Missing sources are reported without
  deleting extracted text, questions, wrong answers or progress. An unavailable
  folder or incomplete/cancelled traversal never clears the cached library.
  Removing a source in the UI keeps its original file and persistently excludes
  its path from future scans. **Excluded files** restores selected paths to the
  import flow. Exclusions belong to each library, survive restart and are rebased
  when a backup is restored; scan hints are discarded in restored copies.
- The model assigns a topic to each question. Review is question-based; a separate
  knowledge graph and adaptive topic mastery model are not implemented.
- Provider JSON mode is optional. Not every "OpenAI-compatible" endpoint accepts
  the same parameters. Use an HTTPS base URL, typically ending in `/v1`.
  Plain HTTP is accepted only for loopback addresses, not remote hosts.
- The buffer uses one request at a time, at most ten questions per request, a low
  watermark of five, and a target of twenty. Small sources may run out of useful
  non-duplicate questions; generation then stops with an explanation.
- Only explicit server/rate-limit responses get at most two retries. Retry-After
  seconds/dates are respected; waits longer than two minutes require a user restart.
  Timeout/ambiguous transport errors require manual retry because they may have
  incurred provider charges. Cancellation interrupts a scheduled wait immediately. Interrupted jobs are cancelled on restart and a user
  starts a new fill; paid requests are not replayed automatically.
- Correct answers on the first attempt do not enter Review. Wrong answers are due
  again in ten minutes, then after one and three days. Three due-time correct
  reviews graduate a question. Early correct practice records the attempt without
  changing the review streak or due date; an incorrect answer resets the streak.
- Data stays on one device. Cloud sync, OCR, folder watching,
  and direct ChatGPT subscription authorization are not included in this release.

## ZIP material import

**Import ZIP** is available for each directory-backed library, including managed
mobile libraries. It imports into the current library; it is not a database or
progress backup format. TXT, Markdown and text PDFs retain their relative paths.
Hidden files, macOS metadata, unsupported formats and nested archives are skipped.
Unencrypted stored/deflate ZIPs are supported, up to 100 MB compressed, 100 MB
expanded in total, 1,000 entries and 20 MB per supported material. ZIP64 and
multi-volume archives are outside these bounds. Central-directory metadata is
also bounded before decoding.

`ZipDocumentAccess` stages and verifies all selected entries in temporary storage
on a worker isolate before yielding materials one at a time. It rejects traversal,
absolute paths, symlinks, ambiguous duplicate paths, invalid sizes and bad CRCs.
Temporary files are removed on success, failure or stream cancellation. The
library writer refuses existing links in parent directories and gives conflicting
filenames a content hash suffix. Reimporting unchanged materials is idempotent.
Existing sources are not reconciled/deleted during ZIP import. A valid archive
can still contain an unreadable document; document parsing reports these per file,
while other valid documents are imported normally.

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

## Android release identity

Generate a new identity only for a new app signing lineage:

```sh
python scripts/android_signing.py create
```

This writes ignored private files under `.tooling/android-signing/`, installs local
`android/key.properties`, and creates a private ZIP containing the key and its
passwords. Keep that ZIP in secure storage outside this checkout. Never commit it.
To reuse a key on another machine, restore `release.p12` and `key.properties` to
those same locations. The default store type is PKCS12.

For repository releases, configure `ANDROID_KEYSTORE_BASE64`,
`ANDROID_STORE_PASSWORD`, `ANDROID_KEY_PASSWORD`, and `ANDROID_KEY_ALIAS` as
GitHub Actions secrets. From an authenticated maintainer machine holding the
private `github-secrets.json`, run:

```sh
python scripts/android_signing.py install-secrets
```

The reusable workflow inherits the secrets from main/tag workflows. Missing keys
stop publication; release builds never fall back to a debug key. Signed APKs are
split by ABI. CI uses seconds since 2024-01-01 as the base Android version code,
so main and tag builds share a growing version-code sequence. Flutter adds ABI
codes when splitting. Local release builds must likewise choose an increasing
`--build-number` to cover an existing installed release. No signing secrets are
provided to pull-request builds.

## Backups and restore

The Settings panel exports all library snapshots and supported original materials
as a versioned OmniQuiz ZIP. It excludes AI configuration and secure-storage
credentials. Missing legacy original files are reported; extracted text and
learning records are still backed up. A disconnected library folder fails export
instead of silently producing an incomplete backup. Limits: 100 MB compressed,
512 MB expanded, 128 MB per database, 20 MB per material, 10,000 archive entries,
and 100 libraries. Android exports the staged archive through SAF with a 64 KB
copy buffer, and iOS exports its file URL through the document picker. Neither
mobile path loads the whole ZIP into a Flutter method payload. Desktop saving
still uses the file-picker bytes API under the 100 MB compressed limit. Archive
CRC checks use a bounded buffer, including database snapshots.

Restore stages and validates every archive entry and SQLite snapshot first, then
creates app-managed copies with new library IDs and rebases source origins. A
single catalog write publishes the result; failures remove only staged/new data.
Existing libraries, active selection and AI settings remain unchanged. Running
jobs are cancelled in snapshots; paid requests never replay after restore.

Modules in `lib/infrastructure/backup/` separate the versioned manifest, archive
I/O, source collection, database hygiene, restore staging, and orchestration. The
presentation depends on backup ports; platform dialogs are separate adapters.
During backup/restore, the host pauses generation and blocks app writes. Live
filesystem edits outside OmniQuiz can still change original files while copying;
normal revision checks reconcile them when a restored library is scanned.

## Large libraries

Generation reads a bounded three-chunk window directly from SQLite, rotating in
source order and wrapping at the end. A schema-v2 index supports per-document
selection. Only those chunks are decoded into Dart objects. Ready-question counts
use COUNT independently of the 40-question display window. `generationChunks`
and `readyCount` are repository operations rather than SQL in view models.

## Subscription gateways

OmniQuiz can use a user-operated CLIProxyAPI instance through its standard
OpenAI-compatible client API. This connects to subscription accounts authenticated
by the gateway; OmniQuiz does not yet implement direct ChatGPT OAuth. The
[comparison](chatgpt-sign-in.md#delivery-decision-2026-10-22) explains the tradeoff.

1. Install [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) or its linked
   desktop manager on a computer/server you control. Use the upstream version's
   setup instructions and sign into the desired provider there. The CLI's
   `--codex-login` option is its ChatGPT/Codex account flow.
2. Configure a strong, unique **client** access key. In the current v8 configuration
   this is `access.api-keys`; older configurations use a top-level `api-keys` list.
   Do not put provider OAuth tokens or the management key into OmniQuiz.
3. For same-computer use, bind the gateway to loopback and enter
   `http://127.0.0.1:8317/v1` in OmniQuiz. For a phone, make the client API reachable
   through HTTPS with a certificate trusted by that phone, for example through
   your own TLS reverse proxy. Use that host's `/v1` URL, not `localhost`.
   Keep management access local and expose only the client API paths needed by
   OmniQuiz (`GET /v1/models`, `POST /v1/chat/completions`).
4. In Settings enter the URL and client key, select **Load available models**,
   search/select a model, and **Test connection**. Leave JSON mode off initially;
   enable it only if the selected gateway/model supports it. Save, import the
   sample material, and generate a batch to verify actual question generation.

The model list is not a guarantee of inference access. A connection test uses
inference and can consume the upstream account's allowance. The gateway sees
selected study excerpts and must stay running while generating questions.
OmniQuiz stores only its client key in OS secure storage; library backups omit it.
Changing endpoints requires explicitly supplying that endpoint's key. Model-list
requests reject redirects, have a 20-second timeout and a 1 MiB response limit,
and do not reveal upstream error bodies.

Phone networking uses the existing native HTTP client and Internet permissions;
no CLI runtime or OAuth callback is needed on the phone for this route. Remote
plain HTTP and invalid certificates are not accepted. If using a private LAN
hostname/address on iOS, local-network permission must be granted. An HTTPS
internet-reachable endpoint avoids that local-network dependency.

Validation gates: automated transport and 390-pixel English/Chinese picker tests
cover the client behavior. Complete a real signed Android/iOS device test against
your authenticated gateway (model listing, question generation, network loss,
app resume and expired upstream login) before treating that deployment as
verified. Compiling an APK or receiving a model catalog alone is insufficient.
