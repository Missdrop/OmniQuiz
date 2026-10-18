# OmniQuiz

**Turn your study materials into endless practice.**

A local-first quiz app for phones and desktops. Bring your notes and your own AI API.

## Features

- **Learn from your materials.** Import TXT, Markdown, or text-based PDFs. Desktop users can import a folder recursively.
- **Stay in flow.** Questions are generated in small batches and cached ahead of time.
- **Check the source.** Every accepted question includes an excerpt and its document location.
- **Learn from mistakes.** Wrong answers enter a spaced review queue. Three correct reviews graduate a question.
- **Choose your AI.** Configure an OpenAI-compatible Chat Completions endpoint, model, and API key.
- **Practice offline.** Saved questions, explanations, and progress remain available without a connection.

> Early release. Automated tests cover the core workflow. Native builds and platform-specific integrations are validated separately; see [development](docs/development.md).

## Get started

1. Open **Settings**, enter your API base URL and model, then save your API key.
2. Use **Test connection** to verify the provider. This makes a small API request.
3. Import your study materials in **Library**, or try the sample notes.
4. Open **Practice**, choose a source, and select **Generate questions**.
5. Revisit missed questions in **Review**.

Generation uses your provider's API balance. It pauses when you leave Practice or the app is suspended. Cached questions are always available. Reimport a folder to scan for changed files; continuous folder watching is not implemented.

## Run locally

Requires Git and the native build tools for your target platform.

```sh
./scripts/bootstrap
./scripts/flutter run -d macos
```

The scripts keep Flutter and package caches inside `.tooling/`. They do not change your system PATH. Replace `macos` with an available device from `./scripts/flutter devices`. On Windows, use `scripts/bootstrap.ps1` and `scripts/flutter.ps1 run -d windows`; see the [PowerShell setup](docs/development.md#windows-powershell) for prerequisites and commands.

See [development](docs/development.md) for platform requirements, tests, and limitations.

## Privacy

No OmniQuiz account, backend, or analytics. Documents are parsed locally; extracted text, questions, and progress are stored in SQLite. Original files are not copied into the app's storage. When you generate questions, selected excerpts are sent directly to your configured AI provider. Keys are stored using the operating system's secure storage.

AI-generated answers can be wrong. Source matching validates the citation, not the reasoning. Check the original excerpt and hide questions that are incorrect or ambiguous.

## Architecture

Flutter + Dart + SQLite (Drift), with MVVM presentation, constructor injection, and separate domain, application, and infrastructure layers. See the [architecture](docs/architecture.md).

## Contributing

Issues and focused pull requests are welcome. Run formatting, static analysis, and relevant tests before submitting changes. Never commit API keys or personal study materials.

## License

[GPL-3.0-only](LICENSE). Copyright (C) 2026 OmniQuiz contributors.
