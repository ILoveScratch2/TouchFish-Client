import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/talker.dart';

class VersionCheckResult {
  final bool hasUpdate;
  final String? remoteVersion;
  final String? currentVersion;
  final String? error;

  const VersionCheckResult({
    required this.hasUpdate,
    this.remoteVersion,
    this.currentVersion,
    this.error,
  });
}

@visibleForTesting
int compareVersions(String a, String b) {
  final aParts = a
      .split('+')
      .first
      .trim()
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final bParts = b
      .split('+')
      .first
      .trim()
      .split('.')
      .map((p) => int.tryParse(p.trim()) ?? 0)
      .toList();
  final length = aParts.length > bParts.length ? aParts.length : bParts.length;
  for (var i = 0; i < length; i++) {
    final aPart = i < aParts.length ? aParts[i] : 0;
    final bPart = i < bParts.length ? bParts[i] : 0;
    if (aPart != bPart) return aPart.compareTo(bPart);
  }
  return 0;
}

class AppUpdateService {
  AppUpdateService._();
  static final AppUpdateService instance = AppUpdateService._();

  static const String versionCheckUrl =
      'http://touchfish.xin/tfv5/tfc_newest.html';
  static const String changelogUrl =
      'http://touchfish.xin/tfv5/tfc_changelog.html';
  static const String downloadBaseUrl =
      'https://v4.gh-proxy.com/https://github.com/ILoveScratch2/TouchFish-Client/releases/download';

  bool _checked = false;

  bool get hasChecked => _checked;

  Future<VersionCheckResult> checkForUpdate() async {
    if (kIsWeb) {
      return const VersionCheckResult(hasUpdate: false);
    }
    if (_checked) {
      return const VersionCheckResult(hasUpdate: false);
    }

    String? currentVersion;
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersion = info.version;
    } catch (error) {
      talker.warning('Failed to read local app version: $error');
    }

    String? remoteVersion;
    try {
      final response = await http
          .get(Uri.parse(versionCheckUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        talker.warning('Version check failed: HTTP ${response.statusCode}');
        return VersionCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: 'HTTP ${response.statusCode}',
        );
      }
      remoteVersion = _parseVersionFromHtml(response.body);
      if (remoteVersion == null) {
        talker.warning('Version check failed: could not parse version');
        return VersionCheckResult(
          hasUpdate: false,
          currentVersion: currentVersion,
          error: 'Could not parse version',
        );
      }
    } catch (error) {
      talker.warning('Version check failed: $error');
      return VersionCheckResult(
        hasUpdate: false,
        currentVersion: currentVersion,
        error: error.toString(),
      );
    }

    _checked = true;

    if (remoteVersion.toLowerCase().contains('dev-build')) {
      return VersionCheckResult(
        hasUpdate: false,
        remoteVersion: remoteVersion,
        currentVersion: currentVersion,
      );
    }

    if (currentVersion == null) {
      return VersionCheckResult(
        hasUpdate: false,
        remoteVersion: remoteVersion,
        currentVersion: currentVersion,
      );
    }

    return VersionCheckResult(
      hasUpdate: remoteVersion != currentVersion,
      remoteVersion: remoteVersion,
      currentVersion: currentVersion,
    );
  }

  @visibleForTesting
  static String? parseVersionFromHtml(String html) {
    return _parseVersionFromHtml(html);
  }

  /// Fetches the changelog markdown from the server. Returns null when the
  /// network request fails.
  Future<String?> fetchChangelog() async {
    try {
      final response = await http
          .get(Uri.parse(changelogUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        talker.warning('Changelog fetch failed: HTTP ${response.statusCode}');
        return null;
      }
      return utf8.decode(response.bodyBytes);
    } catch (error, stackTrace) {
      talker.error('Changelog fetch failed', error, stackTrace);
      return null;
    }
  }

  static String? _parseVersionFromHtml(String html) {
    final tagMatch = RegExp(
      r'<version[^>]*>([^<]+)</version>',
      caseSensitive: false,
    ).firstMatch(html);
    if (tagMatch != null) {
      final candidate = tagMatch.group(1)?.trim();
      if (candidate != null && candidate.isNotEmpty) return candidate;
    }
    final plainMatch = RegExp(
      r'([0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9._-]+)?)',
    ).firstMatch(html);
    if (plainMatch != null) return plainMatch.group(1);
    // Only treat plain, short text as a version. Skip HTML markup.
    if (html.contains('<')) {
      return null;
    }
    final trimmed = html.trim();
    if (trimmed.isNotEmpty && trimmed.length < 128) return trimmed;
    return null;
  }

  static String downloadUrlFor(String version) {
    String fileName;
    if (!kIsWeb && Platform.isAndroid) {
      fileName = 'touchfish-android-armeabi-v7a.apk';
    } else if (!kIsWeb && Platform.isWindows) {
      fileName = 'windows-x86_64-setup.exe';
    } else if (!kIsWeb && Platform.isMacOS) {
      fileName = 'touchfish-macos.zip';
    } else if (!kIsWeb && Platform.isLinux) {
      fileName = 'touchfish-linux-x64.zip';
    } else {
      throw UnsupportedError('No download available for this platform');
    }
    return '$downloadBaseUrl/${Uri.encodeComponent(version)}/$fileName';
  }

  Future<String?> downloadUpdate(String downloadUrl) async {
    try {
      final fileName = downloadUrl.split('/').last;
      var directory = await getApplicationSupportDirectory();
      // On Android, save to a user-accessible public location so the APK is
      // reachable from the file manager even after this app is uninstalled.
      if (!kIsWeb && Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          directory = Directory(
            '${external.path}${Platform.pathSeparator}TouchFish',
          );
        }
      }
      await directory.create(recursive: true);
      final target = File(
        '${directory.path}${Platform.pathSeparator}$fileName',
      );
      final response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(minutes: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        talker.warning('Update download failed: HTTP ${response.statusCode}');
        return null;
      }
      await target.writeAsBytes(response.bodyBytes, flush: true);
      return target.path;
    } catch (error, stackTrace) {
      talker.error('Update download failed', error, stackTrace);
      return null;
    }
  }

  Future<void> revealFile(String filePath) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
        // On Android there is no generic "reveal in file manager" intent;
        // opening the APK hands it to the system (package installer / picker).
        final result = await OpenFile.open(filePath);
        if (result.type != ResultType.done) {
          talker.warning('Failed to open update file: ${result.message}');
        }
        return;
      }
      final result = await launchUrl(Uri.file(filePath));
      if (!result) {
        talker.warning('Failed to reveal update file at $filePath');
      }
    } catch (error, stackTrace) {
      talker.error('Failed to reveal update file', error, stackTrace);
    }
  }

  Future<void> launchFile(String filePath) async {
    try {
      // Use Process.start (not Process.run) so we don't block waiting for the
      // installer to finish. Process.run blocks until the child process exits,
      // and since installers are interactive GUI apps, the app process would
      // never reach the exit(0) call afterward.
      final process = await Process.start(filePath, const <String>[]);
      talker.info('Launched installer PID: ${process.pid}');
      // The installer runs independently; this app process is killed right
      // after by the caller (exit(0)).
    } catch (error, stackTrace) {
      talker.error('Failed to launch installer', error, stackTrace);
    }
  }
}