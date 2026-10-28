// Stages replacements and invokes system installation while preserving explicit OS consent.

import 'dart:ffi';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Native system installers keep OS consent in control. Portable desktop bundles
/// stage a complete replacement before a detached helper swaps directories.
class UpdateInstaller {
  static const channel = MethodChannel('io.github.missdrop.omniquiz/updates');

  Future<String> platform() async {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows && Abi.current() == Abi.windowsX64) {
      return 'windows-x64';
    }
    if (Platform.isLinux && Abi.current() == Abi.linuxX64) return 'linux-x64';
    return 'unsupported';
  }

  Future<List<String>> androidAbis() async =>
      await channel.invokeListMethod<String>('abis') ?? [];

  Future<bool> install(
    File file, {
    Future<void> Function()? prepareToExit,
  }) async {
    if (Platform.isAndroid) {
      final result = await channel.invokeMethod<String>('install', {
        'path': file.path,
      });
      return result != 'permission';
    }
    if (Platform.isWindows) {
      if (!file.path.endsWith('.msi')) throw const FormatException();
      final helper = File(p.join(file.parent.path, 'finish-update.ps1'));
      await helper.writeAsString(windowsHelper);
      final programFiles =
          Platform.environment['ProgramW6432'] ??
          Platform.environment['ProgramFiles'];
      if (programFiles == null) throw const FormatException();
      final powershell = p.join(
        Platform.environment['SystemRoot'] ?? r'C:\Windows',
        'System32',
        'WindowsPowerShell',
        'v1.0',
        'powershell.exe',
      );
      await prepareToExit?.call();
      await Process.start(powershell, [
        '-NoProfile',
        '-NonInteractive',
        '-WindowStyle',
        'Hidden',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        helper.path,
        file.path,
        p.join(programFiles, 'OmniQuiz', 'omniquiz.exe'),
        Platform.resolvedExecutable,
      ], mode: ProcessStartMode.detached);
      exit(0);
    }
    if (Platform.isMacOS || Platform.isLinux) {
      final staged = await stageDesktop(
        file,
        Platform.resolvedExecutable,
        macos: Platform.isMacOS,
      );
      // Do all staging and permission checks before closing any databases.
      final helper = File(p.join(file.parent.path, 'finish-update.sh'));
      await helper.writeAsString(desktopHelper);
      await prepareToExit?.call();
      await Process.start('/bin/bash', [
        helper.path,
        '$pid',
        staged.target,
        staged.replacement,
        staged.backup,
        Platform.isMacOS ? 'macos' : 'linux',
      ], mode: ProcessStartMode.detached);
      exit(0);
    }
    throw UnsupportedError('Use the official download page.');
  }

  /// Kept separate so staging can be tested without quitting the test process.
  static Future<({String target, String replacement, String backup})>
  stageDesktop(File archive, String executable, {required bool macos}) async {
    final binary = File(executable);
    final target = macos
        ? binary.parent.parent.parent.path
        : binary.parent.path;
    if (macos
        ? !target.endsWith('/OmniQuiz.app')
        : !await File(p.join(target, 'lib', 'libflutter_linux_gtk.so'))
                  .exists() ||
              !await Directory(p.join(target, 'data', 'flutter_assets'))
                  .exists()) {
      throw const FormatException();
    }
    // A sibling ensures both renames stay on the same filesystem. Creating it
    // also verifies write access; system-managed installations use the website.
    final staging = await Directory(p.dirname(target))
        .createTemp('.omniquiz-update-');
    final replacement = p.join(
      staging.path,
      macos ? 'OmniQuiz.app' : 'OmniQuiz',
    );
    try {
      if (macos) {
        final mount = await Directory(p.join(archive.parent.path, 'mount'))
            .create();
        var mounted = false;
        try {
          await _run('/usr/bin/hdiutil', [
            'attach',
            archive.path,
            '-nobrowse',
            '-readonly',
            '-mountpoint',
            mount.path,
          ]);
          mounted = true;
          final source = p.join(mount.path, 'OmniQuiz.app');
          await _run('/usr/bin/codesign', [
            '--verify',
            '--deep',
            '--strict',
            source,
          ]);
          await _run('/usr/bin/ditto', [source, replacement]);
        } finally {
          if (mounted) await _run('/usr/bin/hdiutil', ['detach', mount.path]);
        }
      } else {
        await _run('/usr/bin/tar', ['-xzf', archive.path, '-C', staging.path]);
      }
      final nextBinary = macos
          ? p.join(replacement, 'Contents', 'MacOS', p.basename(executable))
          : p.join(replacement, 'omniquiz');
      if (!await File(nextBinary).exists()) throw const FormatException();
      return (
        target: target,
        replacement: replacement,
        backup: p.join(staging.path, 'previous'),
      );
    } catch (_) {
      await staging.delete(recursive: true);
      rethrow;
    }
  }

  static Future<void> _run(String executable, List<String> args) async {
    final result = await Process.run(
      executable,
      args,
    ).timeout(const Duration(minutes: 3));
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Update preparation failed (${result.exitCode})',
        executable,
      );
    }
  }

  // Paths arrive as positional arguments, never interpolated shell source.
  // Keep the previous bundle for recovery; it is not removed during the swap.
  static const desktopHelper = r'''#!/bin/bash
set -eu
old_pid="$1"
target="$2"
replacement="$3"
backup="$4"
platform="$5"
launch() {
  if [ "$platform" = macos ]; then
    /usr/bin/open "$target"
  else
    "$target/omniquiz" >/dev/null 2>&1 &
  fi
}
for attempt in {1..60}; do
  if ! kill -0 "$old_pid" 2>/dev/null; then break; fi
  sleep 1
done
if kill -0 "$old_pid" 2>/dev/null; then exit 1; fi
if ! mv -- "$target" "$backup"; then
  launch
  exit 1
fi
if ! mv -- "$replacement" "$target"; then
  mv -- "$backup" "$target"
  launch
  exit 1
fi
launch
''';

  // The helper keeps the original user's token while Windows Installer handles
  // its own elevation. Cancel/failure restarts the previous executable.
  static const windowsHelper = r'''param(
  [string]$InstallerPath,
  [string]$InstalledExe,
  [string]$PreviousExe,
  [string]$InstallerCommand = 'msiexec.exe'
)
$ErrorActionPreference = 'Stop'
$selectedExe = $PreviousExe
try {
  $installerArguments = '/i "' + $InstallerPath + '"'
  $installProcess = Start-Process -FilePath $InstallerCommand -ArgumentList $installerArguments -Wait -PassThru
  if ($installProcess.ExitCode -in @(0, 3010)) { $selectedExe = $InstalledExe }
} catch { $selectedExe = $PreviousExe }
if (Test-Path -LiteralPath $selectedExe -PathType Leaf) {
  Start-Process -FilePath $selectedExe -WorkingDirectory (Split-Path -Parent $selectedExe)
}
''';
}
