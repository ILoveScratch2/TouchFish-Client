import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/talker.dart';
import 'android_abi_probe.dart';

/// 更新包的投递方式
enum UpdateDelivery {
  /// 下载后直接运行安装器
  installer,

  /// 下载后打开磁盘映像
  diskImage,

  /// 下载 APK 并交给系统安装器
  apk,

  /// 不在应用内下载，交给浏览器 / 包管理器
  external,
}

/// 运行环境归类
enum UpdateHost { windows, macOS, linux, android, other }

/// Android 打包所用 ABI
enum AndroidAbi {
  arm64V8('arm64-v8a'),
  armeabiV7a('armeabi-v7a'),
  x86_64('x86_64');

  const AndroidAbi(this.abiName);

  final String abiName;

  String get apkFileName => 'touchfish-android-$abiName.apk';
}

@immutable
class UpdateTarget {
  const UpdateTarget({
    required this.delivery,
    required this.pageUrl,
    this.downloadUrl,
  });

  final UpdateDelivery delivery;

  final String? downloadUrl;

  final Uri pageUrl;

  bool get needsDownload => delivery != UpdateDelivery.external;
}

class VersionCheckResult {
  final bool hasUpdate;
  final String? remoteVersion;
  final String? currentVersion;
  final String? error;

  /// 最新版本的变动说明
  final String changelog;

  /// 本次强制触发
  final bool forced;

  const VersionCheckResult({
    required this.hasUpdate,
    this.remoteVersion,
    this.currentVersion,
    this.error,
    this.changelog = '',
    this.forced = false,
  });
}

@immutable
class LatestReleaseFeed {
  const LatestReleaseFeed({required this.version, this.changelog = ''});

  final String version;
  final String changelog;
}

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

  /// 最新版本清单：Markdown
  /// 首行是版本号，其后是该版本的更新日志
  static const String latestVersionUrl =
      'https://touchfish.xin/updates/tfc/latest';

  static const String changelogUrl =
      'https://touchfish.xin/updates/tfc/log';
  static const String downloadBaseUrl =
      'https://v4.gh-proxy.com/https://github.com/ILoveScratch2/TouchFish-Client/releases/download';

  static const MethodChannel _channel = MethodChannel(
    'touchfish/background_notification',
  );


  static final RegExp _versionToken = RegExp(
    r'v?([0-9]+(?:\.[0-9]+){0,3}(?:-[A-Za-z0-9._-]+)?)',
    caseSensitive: false,
  );

  /// 测试注入点
  @visibleForTesting
  http.Client? httpClientOverride;

  /// 测试注入点
  @visibleForTesting
  String? currentVersionOverride;

  /// 默认客户端延迟创建
  http.Client? _defaultClient;

  http.Client get _client =>
      httpClientOverride ?? (_defaultClient ??= http.Client());

  bool _checked = false;
  VersionCheckResult? _lastResult;

  bool get hasChecked => _checked;

  /// 最近一次检查结果
  VersionCheckResult? get lastResult => _lastResult;

  /// 读取本机版本号
  Future<String?> currentVersion() async {
    final override = currentVersionOverride;
    if (override != null) return override;
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (error) {
      talker.warning('Failed to read local app version: $error');
      return null;
    }
  }

  /// 拉取并解析
  Future<LatestReleaseFeed?> fetchLatestFeed() async {
    if (kIsWeb) return null;
    try {
      final response = await _client
          .get(
            Uri.parse(latestVersionUrl),
            headers: const {
              // 版本号是强时效数据
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        talker.warning(
          'Latest version fetch failed: HTTP ${response.statusCode}',
        );
        return null;
      }
      final feed = parseLatestFeed(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      if (feed == null) {
        talker.warning('Latest version fetch failed: unparsable payload');
      }
      return feed;
    } catch (error, stackTrace) {
      talker.warning('Latest version fetch failed: $error', error, stackTrace);
      return null;
    }
  }

  /// 检查是否有新版本
  Future<VersionCheckResult> checkForUpdate({bool force = false}) async {
    if (kIsWeb) {
      return const VersionCheckResult(hasUpdate: false);
    }

    final current = await currentVersion();
    final feed = await fetchLatestFeed();

    if (feed == null) {
      final failed = VersionCheckResult(
        hasUpdate: force,
        currentVersion: current,
        remoteVersion: force ? current : null,
        error: 'Latest version unavailable',
        forced: force,
      );
      _checked = true;
      _lastResult = failed;
      return failed;
    }

    final remote = feed.version;
    final isDevBuild = remote.toLowerCase().contains('dev-build');
    final isNewer = current != null && compareVersions(remote, current) > 0;
    // dev-build
    final hasUpdate = force || (!isDevBuild && current != null && isNewer);

    final result = VersionCheckResult(
      hasUpdate: hasUpdate,
      remoteVersion: remote,
      currentVersion: current,
      changelog: feed.changelog,
      forced: force,
    );
    _checked = true;
    _lastResult = result;
    return result;
  }

  /// 强制走一遍更新
  Future<VersionCheckResult> forceUpdateCheck() => checkForUpdate(force: true);

  /// 解析 latest
  @visibleForTesting
  static LatestReleaseFeed? parseLatestFeed(String body) {
    final normalized = body
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\uFEFF', '');
    final trimmedBody = normalized.trim();
    if (trimmedBody.isEmpty || trimmedBody.startsWith('<')) return null;

    final match = _versionToken.firstMatch(trimmedBody);
    if (match == null) return null;

    return LatestReleaseFeed(
      version: match.group(1)!.trim(),
      changelog: _changelogAfterVersion(trimmedBody.substring(match.end)),
    );
  }

  /// 截取版本号之后的正文
  static String _changelogAfterVersion(String rest) {
    final newlineIndex = rest.indexOf('\n');
    final firstLine = newlineIndex < 0 ? rest : rest.substring(0, newlineIndex);
    final tail = newlineIndex < 0 ? '' : rest.substring(newlineIndex);
    final head = firstLine
        .trim()
        .replaceFirst(RegExp(r'^[-–—:：|]+'), '')
        .trim();
    if (head.isEmpty) return tail.trim();
    return '$head$tail'.trim();
  }

  /// 仅取版本号
  @visibleForTesting
  static String? parseLatestVersion(String body) => parseLatestFeed(body)?.version;

  /// 拉取完整更新日志
  Future<String?> fetchChangelog() async {
    try {
      final response = await _client
          .get(Uri.parse(changelogUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        talker.warning('Changelog fetch failed: HTTP ${response.statusCode}');
        return null;
      }
      return utf8.decode(response.bodyBytes, allowMalformed: true);
    } catch (error, stackTrace) {
      talker.error('Changelog fetch failed', error, stackTrace);
      return null;
    }
  }

  /// 发布页
  static String releasePageUrlFor(String version) =>
      'https://github.com/ILoveScratch2/TouchFish-Client/releases/tag/'
      '${Uri.encodeComponent(version)}';

  static UpdateHost get currentHost {
    if (kIsWeb) return UpdateHost.other;
    if (Platform.isWindows) return UpdateHost.windows;
    if (Platform.isMacOS) return UpdateHost.macOS;
    if (Platform.isLinux) return UpdateHost.linux;
    if (Platform.isAndroid) return UpdateHost.android;
    return UpdateHost.other;
  }

  /// 测试注入点
  @visibleForTesting
  AndroidAbi? androidAbiOverride;

  /// 解析本机 Android ABI
  ///
  /// 优先读系统的 `SUPPORTED_ABIS`
  Future<AndroidAbi> resolveAndroidAbi() async {
    final override = androidAbiOverride;
    if (override != null) return override;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final resolved = pickAndroidAbi(info.supportedAbis);
      if (resolved != null) return resolved;
    } catch (error) {
      talker.warning('Failed to read Android ABIs: $error');
    }
    return androidAbiFromProcess();
  }

  /// 按系统给的优先顺序挑第一个有产物的 ABI（arm64-v8a 优先于 armeabi-v7a
  @visibleForTesting
  static AndroidAbi? pickAndroidAbi(List<String> supportedAbis) {
    for (final raw in supportedAbis) {
      switch (raw.toLowerCase().trim()) {
        case 'arm64-v8a':
          return AndroidAbi.arm64V8;
        case 'armeabi-v7a':
        case 'armeabi':
          return AndroidAbi.armeabiV7a;
        case 'x86_64':
          return AndroidAbi.x86_64;
      }
    }
    return null;
  }

  /// 当前进程的 ABI
  @visibleForTesting
  static AndroidAbi androidAbiFromProcess() {
    return pickAndroidAbi(<String>[currentProcessAndroidAbi()]) ??
        AndroidAbi.arm64V8;
  }

  /// 解析某版本在当前平台的更新产物
  static Future<UpdateTarget> resolveUpdateTarget(String version) async {
    final host = currentHost;
    final abi = host == UpdateHost.android
        ? await AppUpdateService.instance.resolveAndroidAbi()
        : null;
    return resolveUpdateTargetFor(version, host, androidAbi: abi);
  }

  /// 可注入平台的解析实现
  @visibleForTesting
  static UpdateTarget resolveUpdateTargetFor(
    String version,
    UpdateHost host, {
    AndroidAbi? androidAbi,
  }) {
    final pageUrl = Uri.parse(releasePageUrlFor(version));
    final encodedVersion = Uri.encodeComponent(version);
    String direct(String fileName) =>
        '$downloadBaseUrl/$encodedVersion/$fileName';

    switch (host) {
      case UpdateHost.android:
        final abi = androidAbi ?? AndroidAbi.arm64V8;
        return UpdateTarget(
          delivery: UpdateDelivery.apk,
          downloadUrl: direct(abi.apkFileName),
          pageUrl: pageUrl,
        );
      case UpdateHost.windows:
        return UpdateTarget(
          delivery: UpdateDelivery.installer,
          downloadUrl: direct('windows-x86_64-setup.exe'),
          pageUrl: pageUrl,
        );
      case UpdateHost.macOS:
        // CI 会把 DMG 重命名为固定名
        return UpdateTarget(
          delivery: UpdateDelivery.diskImage,
          downloadUrl: direct('touchfish-macos.dmg'),
          pageUrl: pageUrl,
        );
      case UpdateHost.linux:
      case UpdateHost.other:
        // Linux 的 zip 只是构建产物
        return UpdateTarget(delivery: UpdateDelivery.external, pageUrl: pageUrl);
    }
  }

  /// 计算下载文件最终的完整保存路径
  static Future<String> downloadPathFor(String downloadUrl) async {
    final fileName = downloadUrl.split('/').last;
    if (!kIsWeb && Platform.isAndroid) {
      return '/storage/emulated/0/Download/$fileName';
    }
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    return '${directory.path}${Platform.pathSeparator}$fileName';
  }

  /// 下载更新文件，返回最终保存路径
  ///
  /// Android：
  /// 1. 先下载到应用缓存目录（一定可写，避免分区存储限制）
  /// 2. 通过 MethodChannel 调用系统 MediaStore 写入公共 Downloads 目录
  ///    （API 29+ 免存储权限；API <= 28 直接写公共路径）
  /// 3. 成功返回公共路径；通道不可用时回退到缓存路径
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

    // 非 Android：缓存目录即最终目标
    if (kIsWeb || !Platform.isAndroid) {
      return tempFile.path;
    }

    // Android：通过 MediaStore 写入公共 Downloads
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
    return tempFile.path;
  }

  Future<void> revealFile(String filePath) async {
    try {
      if (!kIsWeb && Platform.isAndroid) {
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
      final process = await Process.start(filePath, const <String>[]);
      talker.info('Launched installer PID: ${process.pid}');
    } catch (error, stackTrace) {
      talker.error('Failed to launch installer', error, stackTrace);
    }
  }
}