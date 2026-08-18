import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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

  static const MethodChannel _channel = MethodChannel(
    'touchfish/background_notification',
  );

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

  /// 计算下载文件最终的完整保存路径（用于下载前的界面展示）。
  ///
  /// Android 上返回公共 Downloads 目录下的路径（应用文件之外）。实际写入
  /// 由 [downloadUpdate] 通过 MediaStore 通道完成。
  static Future<String> downloadPathFor(String downloadUrl) async {
    final fileName = downloadUrl.split('/').last;
    if (!kIsWeb && Platform.isAndroid) {
      return '/storage/emulated/0/Download/$fileName';
    }
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return '${directory.path}${Platform.pathSeparator}$fileName';
  }

  /// 下载更新文件，返回最终保存路径；失败返回 null。
  ///
  /// Android：
  /// 1. 先下载到应用缓存目录（一定可写，避免分区存储限制）。
  /// 2. 通过 MethodChannel 调用系统 MediaStore 写入公共 Downloads 目录
  ///    （API 29+ 免存储权限；API <= 28 直接写公共路径）。
  /// 3. 成功返回公共路径；通道不可用时回退到缓存路径，保证功能不中断。
  Future<String?> downloadUpdate(String downloadUrl) async {
    final fileName = downloadUrl.split('/').last;
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(
      '${tempDir.path}${Platform.pathSeparator}$fileName',
    );

    try {
      final response = await http
          .get(Uri.parse(downloadUrl))
          .timeout(const Duration(minutes: 60));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        talker.warning('Update download failed: HTTP ${response.statusCode}');
        return null;
      }
      await tempFile.writeAsBytes(response.bodyBytes, flush: true);
    } catch (error, stackTrace) {
      talker.error('Update download failed', error, stackTrace);
      return null;
    }

    // 非 Android：缓存目录即最终目标。
    if (kIsWeb || !Platform.isAndroid) {
      return tempFile.path;
    }

    // Android：通过 MediaStore 写入公共 Downloads。
    try {
      final saved = await _channel.invokeMethod<String>(
        'saveFileToDownloads',
        {'srcPath': tempFile.path, 'displayName': fileName},
      );
      if (saved != null && saved.isNotEmpty) {
        try {
          await tempFile.delete();
        } catch (_) {}
        talker.info('Update saved to public Downloads: $saved');
        return saved;
      }
    } catch (error, stackTrace) {
      talker.error(
        'Failed to save update via MediaStore, falling back to cache',
        error,
        stackTrace,
      );
    }

    // 通道失败时兜底返回缓存路径（功能不中断）。
    return tempFile.path;
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