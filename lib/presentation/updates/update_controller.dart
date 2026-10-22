import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../infrastructure/updates/release_updater.dart';
import '../../infrastructure/updates/update_installer.dart';
import '../../infrastructure/updates/update_preferences.dart';

enum UpdateStatus {
  idle,
  checking,
  current,
  noRelease,
  available,
  downloading,
  ready,
  installing,
  failed,
  cancelled,
}

class UpdateController extends ChangeNotifier {
  UpdateController(
    this.preferences, {
    ReleaseUpdater? service,
    UpdateInstaller? installer,
    Future<String> Function()? versionReader,
    Future<Directory> Function()? cacheDirectory,
  }) : service = service ?? ReleaseUpdater(),
       installer = installer ?? UpdateInstaller(),
       versionReader =
           versionReader ??
           (() async => (await PackageInfo.fromPlatform()).version),
       cacheDirectory =
           cacheDirectory ??
           (() async => Directory(
             p.join((await getTemporaryDirectory()).path, 'updates'),
           ));
  final UpdatePreferences preferences;
  final ReleaseUpdater service;
  final UpdateInstaller installer;
  final Future<String> Function() versionReader;
  final Future<Directory> Function() cacheDirectory;
  Future<void> Function()? prepareToExit;
  bool autoCheck = true, loaded = false, saving = false, saveFailed = false;
  bool _disposed = false;
  bool _cancelling = false;
  bool installPermissionNeeded = false;
  Future<void>? _initializing;
  String? version, skippedVersion;
  AppRelease? release;
  UpdateAsset? asset;
  File? downloaded;
  UpdateStatus status = UpdateStatus.idle;
  double progress = 0;
  int notification = 0;
  bool get busy =>
      _cancelling ||
      [
        UpdateStatus.checking,
        UpdateStatus.downloading,
        UpdateStatus.installing,
      ].contains(status);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() => _initializing ??= _initialize();
  Future<void> _initialize() async {
    try {
      final settings = await preferences.load();
      autoCheck = settings['autoCheck'] as bool? ?? true;
      skippedVersion = settings['skippedVersion'] as String?;
      version = await versionReader();
      Version.parse(version!);
    } catch (_) {
      status = UpdateStatus.failed;
    }
    loaded = true;
    _notify();
    if (!_disposed && autoCheck && version != null) await check(manual: false);
  }

  Future<void> setAutoCheck(bool enabled) async {
    if (saving) return;
    saving = true;
    saveFailed = false;
    _notify();
    try {
      await preferences.save({
        'autoCheck': enabled,
        'skippedVersion': skippedVersion,
      });
      autoCheck = enabled;
    } catch (_) {
      saveFailed = true;
    }
    saving = false;
    _notify();
  }

  Future<void> skip() async {
    if (release == null || saving) return;
    saving = true;
    saveFailed = false;
    _notify();
    try {
      final skipped = release!.version.toString();
      await preferences.save({
        'autoCheck': autoCheck,
        'skippedVersion': skipped,
      });
      skippedVersion = skipped;
    } catch (_) {
      saveFailed = true;
    }
    saving = false;
    _notify();
  }

  Future<void> check({bool manual = true}) async {
    if (busy || _disposed) return;
    status = UpdateStatus.checking;
    _notify();
    try {
      version ??= await versionReader();
      final latest = await service.latest();
      if (_disposed) return;
      release = null;
      asset = null;
      downloaded = null;
      if (latest == null) {
        status = UpdateStatus.noRelease;
      } else if (latest.version <= Version.parse(version!)) {
        status = UpdateStatus.current;
      } else {
        release = latest;
        final platform = await installer.platform();
        asset = ReleaseUpdater.assetFor(
          latest,
          platform,
          abis: platform == 'android'
              ? await installer.androidAbis()
              : const [],
        );
        status = UpdateStatus.available;
        if (manual ||
            (autoCheck && skippedVersion != latest.version.toString())) {
          notification++;
        }
      }
    } catch (_) {
      status = UpdateStatus.failed;
    }
    _notify();
  }

  Future<void> download() async {
    final selected = release;
    final target = asset;
    if (busy || selected == null || target == null || _disposed) return;
    status = UpdateStatus.downloading;
    progress = 0;
    _notify();
    final throttle = Stopwatch()..start();
    try {
      final file = await service.download(
        selected,
        target,
        await cacheDirectory(),
        (received, total) {
          progress = received / total;
          if (throttle.elapsedMilliseconds > 100 || received == total) {
            throttle.reset();
            _notify();
          }
        },
      );
      if (!_disposed && status != UpdateStatus.cancelled) {
        downloaded = file;
        status = UpdateStatus.ready;
      }
    } catch (_) {
      if (!_disposed && status != UpdateStatus.cancelled) {
        status = UpdateStatus.failed;
      }
    }
    _cancelling = false;
    _notify();
  }

  void cancelDownload() {
    if (status != UpdateStatus.downloading) return;
    status = UpdateStatus.cancelled;
    _cancelling = true;
    service.cancel();
    _notify();
  }

  Future<void> install() async {
    if (busy || downloaded == null) return;
    status = UpdateStatus.installing;
    _notify();
    try {
      installPermissionNeeded = !await installer.install(
        downloaded!,
        prepareToExit: prepareToExit,
      );
      status = UpdateStatus.ready;
    } catch (_) {
      status = UpdateStatus.failed;
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    service.cancel();
    super.dispose();
  }
}
