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
- **Review your mistakes.** Missed questions come back for spaced review.
- **Keep practicing offline.** Previously generated questions stay available.
- **Choose your language.** English and Simplified Chinese interfaces, with a separate language setting for AI questions.

## Download

Get the available builds from [GitHub Releases](https://github.com/Missdrop/OmniQuiz/releases).
**Nightly builds are early previews** and may contain bugs.

| Platform | Release file |
| --- | --- |
| Windows | `OmniQuiz-windows-x64.msi` — run the installer; `.zip` is also available for use without installation |
| Android | `OmniQuiz-android-debug.apk` — install on your device |
| macOS | `OmniQuiz-macos.dmg` — open and drag OmniQuiz into Applications |
| Linux | `OmniQuiz-linux-x64.tar.gz` |

For iOS, the release archive is unsigned; building and signing requires macOS and Xcode.
Windows installers are not code-signed, and macOS builds are not notarized.
See the [development guide](docs/development.md) for platform requirements.

## Get started

1. **Connect your AI.** In **Settings**, enter your provider's API base URL, model, and API key. Select **Test connection**.
2. **Create a library.** In **Library**, choose **Create library**. Use an existing desktop folder or let OmniQuiz create one. Import files, or try the included sample notes.
3. **Start practicing.** In **Practice**, choose your material and select **Generate questions**. Visit **Review** later to revisit mistakes.

You need an API provider compatible with OpenAI Chat Completions. New questions require
an internet connection and may incur charges from your provider. Saved questions work offline.

Folders scan on launch, library switch, and return to the app. Use **Scan folder**
after editing files while OmniQuiz stays open. Each scan imports new and changed
files; removed sources leave practice, while answer history is retained. Hidden
files and symbolic links are skipped. Mobile devices use app-managed folders and
file or ZIP import. ZIP imports preserve subfolders and skip hidden/unsupported
files. Use an unencrypted ZIP (up to 100 MB compressed and expanded, 1,000 entries,
20 MB per material). API settings and interface language are shared across libraries.

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

[GPL-3.0-only](LICENSE).
