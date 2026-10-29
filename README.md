<p align="center">
  <img src="assets/branding/logo.png" alt="OmniQuiz" width="120">
</p>
<h1 align="center">OmniQuiz · 万物一点通</h1>
<p align="center"><strong>Your materials. Your AI. Keep the questions coming.</strong></p>
<p align="center">
  <strong>English</strong> · <a href="README.zh-CN.md">简体中文</a><br>
  <a href="https://github.com/Missdrop/OmniQuiz/releases/latest">Download</a> ·
  <a href="#get-started">Get started</a> ·
  <a href="CONTRIBUTING.md">Contribute</a> ·
  <a href="https://github.com/Missdrop/OmniQuiz/issues">Report a bug</a>
</p>

Finished reading your slides, but unsure what stuck? Give OmniQuiz your notes, textbook or course slides. AI turns **your study materials** into questions and keeps refilling them as you practice, until you end the session.

**Import → Practice → Auto-refill → Review mistakes**

## More than “generate a few questions”

- **Keep practicing.** Questions refill when the buffer runs low. Stop whenever you want; saved questions work offline.
- **Set the direction.** Add sample questions or papers and requirements such as “more application, less recall.” Changes preserve existing questions, and your ratings inform future batches.
- **Check the source.** Each answer comes with an explanation and a source quote. Open the original PDF page, then revisit missed questions in review.
- **Choose your AI.** Sign in with ChatGPT or use an OpenAI-compatible API, including CLIProxyAPI. Save multiple connections and explicitly choose which one to use.

## Get started

1. **Create a library.** Import TXT, Markdown or PDFs with selectable text. Link a folder on desktop, or import files and ZIPs on mobile.
2. **Connect AI.** In **Settings → Configure AI**, add a ChatGPT subscription or OpenAI-compatible API connection.
3. **Start practice.** Choose your material and select **Start practice**. To match an exam style, add a paper under **Question settings** first. Set the batch size and refill threshold there too; both default to 10.

Questions currently have four choices and one correct answer; click a choice to submit. Scanned PDFs need OCR first. Generation requires internet access and consumes your selected service's plan allowance or API usage.

## Download

| Platform | Pick this |
| --- | --- |
| Windows | [MSI installer](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-windows-x64.msi) · [Portable ZIP](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-windows-x64.zip) |
| Android | [APK for most phones](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-android-arm64-v8a.apk) |
| macOS | [DMG installer](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-macos.dmg) |
| Linux | [tar.gz archive](https://github.com/Missdrop/OmniQuiz/releases/latest/download/OmniQuiz-linux-x64.tar.gz) |

[All downloads and release notes](https://github.com/Missdrop/OmniQuiz/releases/latest) include other Android architectures and an unsigned iOS IPA. Windows packages are not code-signed; macOS packages are not notarized. Nightly builds are previews.

**iOS:** import the IPA into [AltStore Classic](https://faq.altstore.io/altstore-classic) to sign and install it with your own Apple ID. Free-account installs require refreshing every 7 days. The download is not an App Store/TestFlight release or a universally installable signed IPA.

**You control upgrades.** Standalone builds can check for updates, remind you later or skip a version. Downloads start only after you choose to update, with a download-page fallback. Microsoft Store builds update through the Store; iOS offers update notices and a download link.

## Take your library with you

Each library has its own questions, mistakes and progress. Sample papers, requirements and the study database live in its `.omniquiz` folder; close the app before moving the library. You can also export and restore backups in Settings without replacing existing libraries. Accounts and keys are excluded from backups.

Open the dashboard cards to manage materials, practice, browse answer history or review mistakes. New files are selected automatically; unchecking a file only changes future generation and keeps saved questions. Deleting a library lets you choose whether to keep its original files.

Interface language, question language and appearance follow your system by default, with manual choices available. Light and dark themes are included.

## Where does your data go?

Materials and progress stay on your device. During generation, relevant excerpts, examples, requirements and recent ratings go directly to **the AI service you choose**. Credentials use OS secure storage. OmniQuiz has no backend or analytics. Read the [privacy policy](assets/legal/privacy_en.txt).

AI can make mistakes. Check answers against your source material.

## Make it better

Bug reports, usability improvements and code contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, testing and packaging.

Copyright © 2026 Missdrop · [GPL-3.0-only](LICENSE)

Font: [Noto Sans SC](https://github.com/google/fonts/tree/main/ofl/notosanssc), [SIL OFL 1.1](assets/fonts/OFL.txt).
