<p align="center">
  <img src="assets/branding/logo.png" alt="OmniQuiz logo" width="140">
</p>
<h1 align="center">OmniQuiz</h1>
<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a></p>
<p align="center"><strong>Turn your notes into practice questions.</strong></p>
<p align="center">
  <a href="https://github.com/Missdrop/OmniQuiz/releases">Download</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="docs/development.md">Build from source</a> ·
  <a href="https://github.com/Missdrop/OmniQuiz/issues">Report a bug</a>
</p>

OmniQuiz (万物一点通) turns your study materials into an ongoing practice session.
Bring your materials, connect your own AI provider, and start practicing.
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

1. **Connect your AI.** Open **Settings → Configure AI → Add connection**, then choose **ChatGPT subscription** or **OpenAI-compatible API**. Testing is optional. Your first connection is selected automatically; additional connections are saved independently.
2. **Create a library.** In **Library**, choose **Create library**. Use an existing desktop folder or let OmniQuiz create one. Import files, or try the included sample notes.
3. **Start practicing.** In **Practice**, choose your material and select **Start practice**. Questions refill automatically as you answer; select **End practice** or leave the page to stop. Visit **Review** later to revisit mistakes.

Choose light, dark, or system appearance in **Settings**, or use the theme button in the sidebar or mobile toolbar. Your choice is saved. Practice keeps a limited buffer rather than generating endlessly ahead; if a provider request fails, you can keep answering cached questions and retry refilling.

The app starts with no libraries. Appearance and question language follow your system by default. Set the shared question language below interface language in **Settings**; it applies to both API and ChatGPT connections.

API-key mode needs a provider compatible with OpenAI Chat Completions. Direct ChatGPT
mode needs an eligible account and plan authorization. New questions require an internet
connection and consume the selected connection's allowance or API usage. Saved questions work offline.

### Sample papers and question requirements

In **Practice → Reference examples and requirements**, paste sample questions or import TXT, Markdown or text-based PDF papers, then enter your requirements (for example, scenario-based questions with explanations of incorrect choices). These settings belong to the current library and are included in its backup. Scanned PDFs need text recognition before import.

Samples guide style and difficulty; answers and citations still come from your study materials. Currently, generated questions have four choices and one correct answer. Saving preserves all existing questions, answer history and the current selection; updated requirements apply to subsequent generation. Importing a draft alone does not send it to AI; generation sends your requirements and bounded sample excerpts to the selected service.

Your library is portable. Its `.omniquiz/quiz.sqlite` contains questions, answer history, review schedules and quality votes. `.omniquiz/guidance/requirements.md` contains editable requirements, `pasted-example.md` stores pasted examples, and `examples/` keeps copies of imported sample papers. You can edit these files or add supported papers there; subsequent generation batches read them again. Study-material scans skip `.omniquiz`. Existing centralized study databases migrate automatically, retaining the old file for recovery. Close the app before moving or copying a complete library, then attach its folder again. Global interface settings and securely stored account credentials remain device-specific.

Tap a choice to submit it immediately. Use **Good**, **Not good** or **Something wrong?** for quality feedback. Recent ratings and notes accompany subsequent generation requests to improve questions; a vote does not issue a separate paid request. Feedback never replaces source evidence. Marking an error hides that question while preserving answer history. **View original source** opens the cited PDF page with zoom and scrolling; missing or changed originals fall back to a clearly labelled saved text excerpt.

Generation shows reading, model request, validation and saving stages with elapsed time. Batches contain at most five questions and model requests may wait up to three minutes. Timeouts stop without an automatic paid retry; cached questions remain available. Local status diagnostics are in `.omniquiz/generation.log`, without prompts, materials, keys or account details.

### Choose the active AI connection

Name and save multiple connections in **Configure AI**. Both the official OpenAI API and CLIProxyAPI belong to **OpenAI-compatible API**; change the base URL for your service. **Save connection** keeps an additional configuration without switching; **Use** or **Save and use** explicitly selects it. Editing or testing an inactive connection does not affect current generation. Switching keeps cached questions and applies to future batches. Deleting the active connection or signing it out stops generation without automatically falling back to another service. The practice page always shows the connection and model used for new questions.

### Use your ChatGPT plan directly

In **Settings → Configure AI → Add connection → ChatGPT subscription**, choose **Continue with ChatGPT**.
Complete browser authorization on this device and return to OmniQuiz. Your account
is saved with an available model automatically. Select **Save connection** after editing its model, or **Save and use** to activate it; **Test connection** is optional.
If model loading fails, your account stays saved; choose **Load available models**
to finish setup. This direct connection
requires no API key, gateway, or always-on computer. It uses your authorized plan
allowance; availability depends on your account.

Android and iOS use native browser components with a local callback. Automated tests do not establish successful real-device login.
If the app is terminated during authorization, restart the sign-in. Account
credentials remain in OS secure storage and are excluded from library backups.

### Optional: use a subscription through CLIProxyAPI

You can connect OmniQuiz to your own [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI)
gateway and use the provider accounts you have signed into there, including its
ChatGPT/Codex route. Add an **OpenAI-compatible API** connection, enter the gateway's `/v1` base URL and
**client API key**, choose **Load available models**, then test and save.
Available models and usage limits depend on your gateway and connected accounts.

On the same computer, the usual address is `http://127.0.0.1:8317/v1`.
On a phone, use a reachable **HTTPS** gateway address; `localhost` means the phone
itself. Keep the gateway running. This optional route requires a gateway; use the direct sign-in above for standalone operation. See [setup and mobile requirements](docs/development.md#subscription-gateways).

### App updates

Microsoft Store builds receive updates through the Store. The following download
and installation controls apply to standalone releases.

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

Folders scan on launch, library switch, and return to the app when no practice session is active. Use **Scan folder**
after editing files while OmniQuiz stays open. Scans import new and changed files.
Missing source files are marked, but their imported text, questions, and progress
remain available. Removing a document in OmniQuiz excludes it from future scans
without deleting the original file; use **Excluded files** to include it again.
Hidden files and symbolic links are skipped. Mobile devices use app-managed folders and
file or ZIP import. ZIP imports preserve subfolders and skip hidden/unsupported
files. Use an unencrypted ZIP (up to 100 MB compressed and expanded, 1,000 entries,
20 MB per material). AI connections, appearance, interface language, and question language are shared across libraries.

In **Settings → Back up your libraries**, save an OmniQuiz backup before moving
to another device or reinstalling. Restoring adds libraries without replacing
existing data. Missing originals cannot be included, but their imported text and
progress are preserved; the export reports how many originals are missing.
AI settings and API keys are excluded. Keep backups private.

## Your data

Read the [privacy policy](assets/legal/privacy_en.txt), also available offline in Settings.
Incorrect or inappropriate AI content can be reported to the developer through
the in-app report link. GitHub reports are public; question content and credentials
are never attached automatically.

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

The bundled [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc) font uses the [SIL Open Font License 1.1](assets/fonts/OFL.txt).
