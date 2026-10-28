// Reads public release metadata and verifies bounded downloads before exposing an installation file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

/// Release download metadata, including expected byte count and optional SHA-256 digest.
class UpdateAsset {
  const UpdateAsset(this.name, this.url, this.size, this.digest);
  final String name;
  final Uri url;
  final int size;
  final String? digest;
}

/// A stable release version, notes and assets eligible for platform selection.
class AppRelease {
  const AppRelease(this.version, this.tag, this.notes, this.assets);
  final Version version;
  final String tag, notes;
  final List<UpdateAsset> assets;
  Uri get website =>
      Uri.https('github.com', '/Missdrop/OmniQuiz/releases/tag/$tag');
}

/// Public release metadata only. No account tokens or app content are sent.
class ReleaseUpdater {
  ReleaseUpdater({http.Client Function()? clientFactory})
    : clientFactory = clientFactory ?? http.Client.new;
  final http.Client Function() clientFactory;
  static final website = Uri.https('github.com', '/Missdrop/OmniQuiz/releases');
  static final endpoint = Uri.https(
    'api.github.com',
    '/repos/Missdrop/OmniQuiz/releases/latest',
  );
  static const maxDownload = 512 * 1024 * 1024;
  http.Client? _client;
  int _epoch = 0;

  void cancel() {
    _epoch++;
    _client?.close();
    _client = null;
  }

  Future<AppRelease?> latest() async {
    final client = _client = clientFactory();
    try {
      final response = await client
          .send(
            http.Request('GET', endpoint)
              ..followRedirects = false
              ..headers.addAll({
                'Accept': 'application/vnd.github+json',
                'User-Agent': 'OmniQuiz-update-check',
              }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 404) return null; // No stable release yet.
      if (response.statusCode != 200) throw const FormatException();
      final json = jsonDecode(
        await _text(response, 1024 * 1024),
      ) as Map<String, dynamic>;
      if (json['draft'] != false || json['prerelease'] != false) {
        throw const FormatException();
      }
      final tag = json['tag_name'] as String;
      final version = Version.parse(
        tag.startsWith('v') ? tag.substring(1) : tag,
      );
      if (version.isPreRelease ||
          !RegExp(r'^v?\d+\.\d+\.\d+(?:\+[\w.-]+)?$').hasMatch(tag)) {
        throw const FormatException();
      }
      final assets = <UpdateAsset>[];
      for (final raw in json['assets'] as List) {
        final name = raw['name'] as String;
        final url = Uri.parse(raw['browser_download_url'] as String);
        if (url.scheme != 'https' ||
            url.host != 'github.com' ||
            url.userInfo.isNotEmpty ||
            url.query.isNotEmpty ||
            url.fragment.isNotEmpty ||
            url.path != '/Missdrop/OmniQuiz/releases/download/$tag/$name' ||
            name.contains('/') ||
            name.contains('\\')) {
          continue;
        }
        final size = raw['size'] as int;
        if (size <= 0 || size > maxDownload) continue;
        assets.add(UpdateAsset(name, url, size, raw['digest'] as String?));
      }
      final notes = json['body'] as String? ?? '';
      return AppRelease(version, tag, notes, assets);
    } finally {
      if (identical(_client, client)) _client = null;
      client.close();
    }
  }

  static UpdateAsset? assetFor(
    AppRelease release,
    String platform, {
    List<String> abis = const [],
  }) {
    final name = switch (platform) {
      'windows-x64' => 'OmniQuiz-windows-x64.msi',
      'macos' => 'OmniQuiz-macos.dmg',
      'linux-x64' => 'OmniQuiz-linux-x64.tar.gz',
      'android' =>
        abis
            .where(
              (abi) => ['arm64-v8a', 'armeabi-v7a', 'x86_64'].contains(abi),
            )
            .map((abi) => 'OmniQuiz-android-$abi.apk')
            .firstOrNull,
      _ => null,
    };
    return release.assets.where((asset) => asset.name == name).firstOrNull;
  }

  Future<http.StreamedResponse> _get(http.Client client, Uri initial) async {
    var url = initial;
    for (var redirect = 0; redirect < 6; redirect++) {
      if (url.scheme != 'https' ||
          url.userInfo.isNotEmpty ||
          ![
            'github.com',
            'release-assets.githubusercontent.com',
            'objects.githubusercontent.com',
          ].contains(url.host)) {
        throw const FormatException();
      }
      final response = await client
          .send(http.Request('GET', url)..followRedirects = false)
          .timeout(const Duration(seconds: 30));
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers['location'];
        if (location == null) throw const FormatException();
        // Cancel the unused response without buffering its body.
        await response.stream.listen((_) {}).cancel();
        url = url.resolve(location);
        continue;
      }
      if (response.statusCode != 200) throw const FormatException();
      return response;
    }
    throw const FormatException();
  }

  static Future<String> _text(http.StreamedResponse response, int limit) async {
    final bytes = <int>[];
    await for (final chunk in response.stream.timeout(
      const Duration(seconds: 30),
    )) {
      if (bytes.length + chunk.length > limit) throw const FormatException();
      bytes.addAll(chunk);
    }
    return utf8.decode(bytes);
  }

  Future<String> _digest(
    http.Client client,
    AppRelease release,
    UpdateAsset asset,
  ) async {
    final digest = asset.digest;
    if (digest != null &&
        RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) {
      return digest.substring(7).toLowerCase();
    }
    final sums = release.assets
        .where((a) => a.name == 'SHA256SUMS')
        .firstOrNull;
    if (sums == null) throw const FormatException();
    final text = await _text(await _get(client, sums.url), 64 * 1024);
    for (final line in const LineSplitter().convert(text)) {
      final match = RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$').firstMatch(line);
      if (match?.group(2) == asset.name) return match!.group(1)!.toLowerCase();
    }
    throw const FormatException();
  }

  /// Called only by the user action. Streams to disk, then checks size and SHA-256.
  Future<File> download(
    AppRelease release,
    UpdateAsset asset,
    Directory cache,
    void Function(int, int) progress,
  ) async {
    final epoch = _epoch;
    final client = _client = clientFactory();
    Directory? directory;
    var complete = false;
    try {
      final expected = await _digest(client, release, asset);
      if (epoch != _epoch) throw const FormatException();
      await cache.create(recursive: true);
      directory = await cache.createTemp('v${release.version}-');
      final partial = File(p.join(directory.path, '${asset.name}.part'));
      final response = await _get(client, asset.url);
      if (response.contentLength != null &&
          response.contentLength != asset.size) {
        throw const FormatException();
      }
      final sink = partial.openWrite();
      var received = 0;
      final timer = Stopwatch()..start();
      try {
        await for (final chunk in response.stream.timeout(
          const Duration(seconds: 60),
        )) {
          if (epoch != _epoch || timer.elapsed > const Duration(minutes: 15)) {
            throw const FormatException();
          }
          received += chunk.length;
          if (received > asset.size || received > maxDownload) {
            throw const FormatException();
          }
          sink.add(chunk);
          await sink.flush();
          progress(received, asset.size);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      final actual = (await sha256.bind(partial.openRead()).first).toString();
      if (received != asset.size || epoch != _epoch || actual != expected) {
        throw const FormatException();
      }
      final file = await partial.rename(p.join(directory.path, asset.name));
      if (epoch != _epoch) throw const FormatException();
      complete = true;
      return file;
    } finally {
      if (identical(_client, client)) _client = null;
      client.close();
      if (!complete && directory != null) {
        await directory.delete(recursive: true);
      }
    }
  }
}
