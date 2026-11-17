import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/app_update_service.dart';
import 'package:touchfish_client/services/update_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('compareVersions', () {
    test('equal versions compare as 0', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2.3+4', '1.2.3'), 0);
      expect(compareVersions('1.2.3', '1.2.3+7'), 0);
    });

    test('newer versions compare positive', () {
      expect(compareVersions('1.2.4', '1.2.3'), greaterThan(0));
      expect(compareVersions('1.3.0', '1.2.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('older versions compare negative', () {
      expect(compareVersions('1.2.3', '1.2.4'), lessThan(0));
      expect(compareVersions('1.2.9', '1.3.0'), lessThan(0));
      expect(compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });

    test('handles missing components as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1', '1.0.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('handles trailing build metadata', () {
      expect(compareVersions('1.2.3+100', '1.2.3+1'), 0);
      expect(compareVersions('1.2.4+1', '1.2.3+999'), greaterThan(0));
    });
  });

  group('parseLatestFeed', () {
    test('parses a bare single-line version', () {
      final feed = AppUpdateService.parseLatestFeed('1.2.3');
      expect(feed, isNotNull);
      expect(feed!.version, '1.2.3');
      expect(feed.changes, isEmpty);
    });

    test('tolerates whitespace, BOM and line endings', () {
      expect(
        AppUpdateService.parseLatestFeed('  \uFEFF1.2.3 \r\n\r\n'),
        isA<LatestReleaseFeed>().having((f) => f.version, 'version', '1.2.3'),
      );
    });

    test('strips a v prefix', () {
      expect(AppUpdateService.parseLatestVersion('v1.2.3'), '1.2.3');
      expect(AppUpdateService.parseLatestVersion('V1.2.3'), '1.2.3');
    });

    test('accepts a pre-release suffix', () {
      expect(AppUpdateService.parseLatestVersion('1.2.3-dev-build'), '1.2.3-dev-build');
      expect(AppUpdateService.parseLatestVersion('1.2.3-rc.1'), '1.2.3-rc.1');
    });

    test('collects the following lines as changes', () {
      final feed = AppUpdateService.parseLatestFeed(
        '1.0.0\n- 新增更新区块\n* 修复关于页崩溃\n2. 其它改进\n',
      );
      expect(feed!.version, '1.0.0');
      expect(feed.changes, ['新增更新区块', '修复关于页崩溃', '其它改进']);
    });

    test('keeps an inline note after the version', () {
      final feed = AppUpdateService.parseLatestFeed('1.0.0 —— 首个正式版');
      expect(feed!.version, '1.0.0');
      expect(feed.changes, ['首个正式版']);
    });

    test('caps the number of collected changes', () {
      final body = ['1.0.0', ...List.generate(12, (i) => '- 变动 $i')].join('\n');
      expect(AppUpdateService.parseLatestFeed(body)!.changes.length, 6);
    });

    test('rejects HTML error pages', () {
      expect(
        AppUpdateService.parseLatestFeed(
          '<html>\n<head><title>404 Not Found</title></head>\n</html>',
        ),
        isNull,
      );
    });

    test('rejects empty bodies', () {
      expect(AppUpdateService.parseLatestFeed(''), isNull);
      expect(AppUpdateService.parseLatestFeed('   \n\n'), isNull);
    });
  });

  group('extractChangelogHighlights', () {
    test('keeps only top-level bullet items', () {
      const markdown = '''
# 0.0.3

这是本版本的正文段落，不应出现在摘要里。

- 新增：更新设置页
- 修复：关于页版本号
- 优化：列表滚动

## 0.0.2

- 旧版本的条目
''';
      expect(
        AppUpdateService.extractChangelogHighlights(markdown, limit: 2),
        ['新增：更新设置页', '修复：关于页版本号'],
      );
    });

    test('strips markdown emphasis', () {
      expect(
        AppUpdateService.extractChangelogHighlights('- **新增** `About` 页'),
        ['新增 About 页'],
      );
    });

    test('returns empty when there is no list', () {
      expect(AppUpdateService.extractChangelogHighlights('# 标题\n正文'), isEmpty);
    });
  });

  group('checkForUpdate', () {
    final service = AppUpdateService.instance;

    tearDown(() {
      service.httpClientOverride = null;
      service.currentVersionOverride = null;
    });

    MockClient respondWith(String body, {int status = 200}) {
      return MockClient((request) async {
        expect(request.url.toString(), AppUpdateService.latestVersionUrl);
        // 用 bytes 构造，避免 http.Response 按 latin1 编码中文时抛错。
        return http.Response.bytes(
          utf8.encode(body),
          status,
          headers: {'content-type': 'text/plain; charset=utf-8'},
        );
      });
    }

    test('reports an update when the remote version is newer', () async {
      service.currentVersionOverride = '1.0.0';
      service.httpClientOverride = respondWith('1.1.0\n- 修好了些东西');

      final result = await service.checkForUpdate();

      expect(result.hasUpdate, isTrue);
      expect(result.remoteVersion, '1.1.0');
      expect(result.currentVersion, '1.0.0');
      expect(result.changes, ['修好了些东西']);
      expect(result.error, isNull);
    });

    test('does not report an update when versions match', () async {
      service.currentVersionOverride = '1.1.0';
      service.httpClientOverride = respondWith('v1.1.0');

      final result = await service.checkForUpdate();

      expect(result.hasUpdate, isFalse);
      expect(result.remoteVersion, '1.1.0');
    });

    test('does not report an update when the local build is newer', () async {
      service.currentVersionOverride = '2.0.0';
      service.httpClientOverride = respondWith('1.9.9');

      expect((await service.checkForUpdate()).hasUpdate, isFalse);
    });

    test('ignores dev-build markers', () async {
      service.currentVersionOverride = '1.0.0';
      service.httpClientOverride = respondWith('1.1.0-dev-build');

      expect((await service.checkForUpdate()).hasUpdate, isFalse);
    });

    test('force reports an update even when already current', () async {
      service.currentVersionOverride = '1.1.0';
      service.httpClientOverride = respondWith('1.1.0');

      final result = await service.forceUpdateCheck();

      expect(result.hasUpdate, isTrue);
      expect(result.forced, isTrue);
      expect(result.remoteVersion, '1.1.0');
    });

    test('force still works when the endpoint is unreachable', () async {
      service.currentVersionOverride = '1.1.0';
      service.httpClientOverride = MockClient((_) async => http.Response('', 404));

      final result = await service.forceUpdateCheck();

      expect(result.hasUpdate, isTrue);
      expect(result.remoteVersion, '1.1.0');
      expect(result.error, isNotNull);
    });

    test('a 404 does not look like an update', () async {
      service.currentVersionOverride = '1.0.0';
      service.httpClientOverride = MockClient(
        (_) async => http.Response('<html>404</html>', 404),
      );

      final result = await service.checkForUpdate();

      expect(result.hasUpdate, isFalse);
      expect(result.error, isNotNull);
    });

    test('an HTML error page served with 200 is rejected', () async {
      service.currentVersionOverride = '1.0.0';
      service.httpClientOverride = respondWith('<html><body>oops</body></html>');

      final result = await service.checkForUpdate();

      expect(result.hasUpdate, isFalse);
      expect(result.remoteVersion, isNull);
    });

    test('exposes the last result for the about page', () async {
      service.currentVersionOverride = '1.0.0';
      service.httpClientOverride = respondWith('1.2.0');

      await service.checkForUpdate();

      expect(service.hasChecked, isTrue);
      expect(service.lastResult?.remoteVersion, '1.2.0');
    });
  });

  group('UpdatePreferences', () {
    setUp(() async {
      SettingsService.instance.debugReset();
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
    });

    test('auto check defaults to enabled', () {
      expect(UpdatePreferences.autoCheckEnabled, isTrue);
      expect(UpdatePreferences.shouldAutoCheck, isTrue);
    });

    test('disabling persists and is read back', () async {
      await UpdatePreferences.setAutoCheckEnabled(false);
      expect(UpdatePreferences.autoCheckEnabled, isFalse);
      expect(UpdatePreferences.shouldAutoCheck, isFalse);
    });

    test('setup is marked handled once', () async {
      expect(UpdatePreferences.setupHandled, isFalse);
      await UpdatePreferences.markSetupHandled();
      expect(UpdatePreferences.setupHandled, isTrue);
    });
  });

  group('Android ABI selection, wyf mjz ywd', () {
    test('arm64 device prefers arm64-v8a wangyufan', () {
      expect(
        AppUpdateService.pickAndroidAbi(['arm64-v8a', 'armeabi-v7a', 'armeabi']),
        AndroidAbi.arm64V8,
      );
    });

    test('Falls back to armeabi-v7a only when 32-bit majingzhi', () {
      expect(
        AppUpdateService.pickAndroidAbi(['armeabi-v7a', 'armeabi']),
        AndroidAbi.armeabiV7a,
      );
      expect(
        AppUpdateService.pickAndroidAbi(['armeabi']),
        AndroidAbi.armeabiV7a,
      );
    });

    test('x86 emulator picks x86_64 yxy', () {
      expect(
        AppUpdateService.pickAndroidAbi(['x86_64', 'arm64-v8a']),
        AndroidAbi.x86_64,
      );
    });

    test('Returns null when no suitable ABI is available wyf', () {
      expect(AppUpdateService.pickAndroidAbi([]), isNull);
      expect(AppUpdateService.pickAndroidAbi(['mips64']), isNull);
    });

    test('File names match the build.yml artifacts mjz', () {
      expect(
        AndroidAbi.arm64V8.apkFileName,
        'touchfish-android-arm64-v8a.apk',
      );
      expect(
        AndroidAbi.armeabiV7a.apkFileName,
        'touchfish-android-armeabi-v7a.apk',
      );
      expect(AndroidAbi.x86_64.apkFileName, 'touchfish-android-x86_64.apk');
    });
  });

  group('resolveUpdateTargetFor touchfisher', () {
    test('Android constructs the correct APK based on ABI wyf', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.android,
        androidAbi: AndroidAbi.arm64V8,
      );
      expect(target.delivery, UpdateDelivery.apk);
      expect(
        target.downloadUrl,
        endsWith('/1.2.3/touchfish-android-arm64-v8a.apk'),
      );
      expect(target.needsDownload, isTrue);
    });

    test('32-bit Android devices get armeabi-v7a zyh', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.android,
        androidAbi: AndroidAbi.armeabiV7a,
      );
      expect(target.downloadUrl, endsWith('/touchfish-android-armeabi-v7a.apk'));
    });

    test('Android defaults to 64-bit when ABI is not specified sax', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.android,
      );
      expect(target.downloadUrl, endsWith('/touchfish-android-arm64-v8a.apk'));
    });

    test('Windows uses direct installer link ljx', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.windows,
      );
      expect(target.delivery, UpdateDelivery.installer);
      expect(target.downloadUrl, endsWith('/windows-x86_64-setup.exe'));
    });

    test('macOS uses fixed-name DMG hzr', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.macOS,
      );
      expect(target.delivery, UpdateDelivery.diskImage);
      expect(target.downloadUrl, endsWith('/touchfish-macos.dmg'));
    });

    test('Linux does not download in-app, only provides release page frostlynx', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.linux,
      );
      expect(target.delivery, UpdateDelivery.external);
      expect(target.downloadUrl, isNull);
      expect(target.needsDownload, isFalse);
      expect(target.pageUrl.toString(), endsWith('/releases/tag/1.2.3'));
    });

    test('Unknown platforms also fall back to the release page cyez', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        '1.2.3',
        UpdateHost.other,
      );
      expect(target.delivery, UpdateDelivery.external);
      expect(target.downloadUrl, isNull);
    });

    test('Version numbers are URL-encoded to avoid breaking URLs with v-prefix or special characters wxh', () {
      final target = AppUpdateService.resolveUpdateTargetFor(
        'v1.2.3+4',
        UpdateHost.windows,
      );
      expect(target.downloadUrl, contains('/v1.2.3%2B4/'));
      expect(target.pageUrl.toString(), endsWith('/releases/tag/v1.2.3%2B4'));
    });
  });
}
