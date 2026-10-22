<p align="center">
  <img src="assets/branding/logo.png" alt="OmniQuiz logo" width="140">
</p>
<h1 align="center">OmniQuiz</h1>
<p align="center"><strong>Turn your notes into practice questions.</strong></p>
<p align="center">
  <a href="https://github.com/Missdrop/OmniQuiz/releases">Download</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="docs/development.md">Build from source</a> ·
  <a href="https://github.com/Missdrop/OmniQuiz/issues">Report a bug</a>
</p>

Bring your study materials, connect your own AI provider, and start practicing.
OmniQuiz keeps your library and progress on your device. No account needed.

## What you can do

- **Keep subjects separate.** Create libraries with independent questions, mistakes, and progress.
- **Import a ZIP.** Bring a folder of notes to your phone, keeping subfolders intact.
- **Study a whole folder.** Connect an existing desktop folder or create an app-managed one. Scan TXT, Markdown, and PDFs with selectable text, including subfolders.
- **Understand each answer.** Read explanations alongside excerpts from your materials.
- **Review your mistakes.** Missed questions come back for spaced review; early practice does not fast-track mastery.
- **Back up your progress.** Export all libraries and restore them as separate copies.
- **Keep practicing offline.** Previously generated questions stay available.
- **Choose your language.** English and Simplified Chinese interfaces, with a separate language setting for AI questions.

## Download

Get the available builds from [GitHub Releases](https://github.com/Missdrop/OmniQuiz/releases).
**Nightly builds are early previews** and may contain bugs.

| Platform | Release file |
| --- | --- |
| Windows | `OmniQuiz-windows-x64.msi` — run the installer; `.zip` is also available for use without installation |
| Android | `OmniQuiz-android-arm64-v8a.apk` — signed release for most phones; `armeabi-v7a` and `x86_64` builds are also available |
| macOS | `OmniQuiz-macos.dmg` — open and drag OmniQuiz into Applications |
| Linux | `OmniQuiz-linux-x64.tar.gz` |

For iOS, the release archive is unsigned; building and signing requires macOS and Xcode.
Windows installers are not code-signed, and macOS builds are not notarized.
See the [development guide](docs/development.md) for platform requirements.

## Get started

1. **Connect your AI.** In **Settings**, use experimental **Continue with ChatGPT**, or enter your provider's API base URL, model, and key, select **Test connection**, then **Save settings**.
2. **Create a library.** In **Library**, choose **Create library**. Use an existing desktop folder or let OmniQuiz create one. Import files, or try the included sample notes.
3. **Start practicing.** In **Practice**, choose your material and select **Generate questions**. Visit **Review** later to revisit mistakes.

API-key mode needs a provider compatible with OpenAI Chat Completions. Direct ChatGPT
mode needs an eligible account and plan authorization. New questions require an internet
connection and consume the selected connection's allowance or API usage. Saved questions work offline.

### Use your ChatGPT plan directly (experimental)

In **Settings → ChatGPT subscription**, choose **Continue with ChatGPT**.
Complete browser authorization on this device, return to OmniQuiz, select an
available model, then choose **Test and use this model**. This direct connection
requires no API key, gateway, or always-on computer. It uses your authorized plan
allowance; availability depends on your account.

Android and iOS use native browser components with a local callback. This feature
is experimental: automated tests do not establish successful real-device login.
If the app is terminated during authorization, restart the sign-in. Account
credentials remain in OS secure storage and are excluded from library backups.

### Optional: use a subscription through CLIProxyAPI

You can connect OmniQuiz to your own [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
gateway and use the provider accounts you have signed into there, including its
ChatGPT/Codex route. In **Settings**, enter the gateway's `/v1` base URL and
**client API key**, choose **Load available models**, then test and save.
Available models and usage limits depend on your gateway and connected accounts.

On the same computer, the usual address is `http://127.0.0.1:8317/v1`.
On a phone, use a reachable **HTTPS** gateway address; `localhost` means the phone
itself. Keep the gateway running. This optional route requires a gateway; use the direct sign-in above for standalone operation. See [setup and mobile requirements](docs/development.md#subscription-gateways).

### App updates

OmniQuiz checks for new **stable releases** at startup. In **Settings → App
updates**, you can turn this off or check manually. A new version shows its
release notes with **Remind me later**, **Skip this version**, and **Update now**.
Skipping suppresses startup reminders for that version; manual checks still show it.
Updates are always optional.

Only **Update now** starts the download. OmniQuiz verifies its size and SHA-256
before opening the Android/Windows system installer or replacing and restarting
a writable macOS/Linux app bundle. System installation permission may be required.
Closing the notice during download postpones installation; downloading can also be
cancelled. Libraries and credentials stay in the app data directory.

If checking, downloading, or installing fails, use **Official download page**.
System-managed or read-only desktop installations may need manual installation.
iOS currently offers update notices and the official page because its release
archive is unsigned; it cannot install that archive as an app update.

### Files and backups

Folders scan on launch, library switch, and return to the app. Use **Scan folder**
after editing files while OmniQuiz stays open. Scans import new and changed files.
Missing source files are marked, but their imported text, questions, and progress
remain available. Removing a document in OmniQuiz excludes it from future scans
without deleting the original file; use **Excluded files** to include it again.
Hidden files and symbolic links are skipped. Mobile devices use app-managed folders and
file or ZIP import. ZIP imports preserve subfolders and skip hidden/unsupported
files. Use an unencrypted ZIP (up to 100 MB compressed and expanded, 1,000 entries,
20 MB per material). API settings and interface language are shared across libraries.

In **Settings → Back up your libraries**, save an OmniQuiz backup before moving
to another device or reinstalling. Restoring adds libraries without replacing
existing data. Missing originals cannot be included, but their imported text and
progress are preserved; the export reports how many originals are missing.
AI settings and API keys are excluded. Keep backups private.

## Your data

Your library, questions, and progress are stored locally. When you generate questions,
selected text excerpts go directly to the AI provider you configured. Your API key is
kept in your operating system's secure storage. OmniQuiz has no backend or analytics.

AI can make mistakes. Use the source excerpts to check answers and hide incorrect questions.
Scanned PDFs need OCR before import.

## Development

Built with Flutter. For setup, tests, and platform details, see [Development](docs/development.md).

```sh
./scripts/bootstrap
./scripts/flutter run -d macos
```

On Windows, use PowerShell:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/bootstrap.ps1
powershell -ExecutionPolicy Bypass -File scripts/flutter.ps1 run -d windows
```

Native build tools are required. The scripts keep Flutter and caches in `.tooling/`.
Contributions are welcome: open an issue or a focused pull request against `dev`.

## License

Copyright © 2026 Missdrop.

[GPL-3.0-only](LICENSE).
