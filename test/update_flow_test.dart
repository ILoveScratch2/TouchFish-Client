import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/routes/app_routes.dart';
import 'package:touchfish_client/screens/about_screen.dart';
import 'package:touchfish_client/screens/update_setup_screen.dart';
import 'package:touchfish_client/services/app_update_flow.dart';
import 'package:touchfish_client/services/app_update_service.dart';
import 'package:touchfish_client/services/update_preferences.dart';

/// 模拟 `updates/tfc/latest` 的纯文本响应。
MockClient mockedLatestBody(String body, {int status = 200}) {
  return MockClient((request) async {
    // 用 bytes 构造，避免 http.Response 按 latin1 编码中文时抛错。
    return http.Response.bytes(
      utf8.encode(body),
      status,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );
  });
}

/// 让 `PackageInfo.fromPlatform()` 在测试里返回固定版本。
void mockPackageVersion(String version) {
  PackageInfo.setMockInitialValues(
    appName: 'TouchFish Client',
    packageName: 'touchfish_client',
    version: version,
    buildNumber: '3',
    buildSignature: '',
  );
}

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SettingsService.instance.debugReset();
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    AppUpdateService.instance.httpClientOverride = null;
    AppUpdateService.instance.currentVersionOverride = null;
    mockPackageVersion('0.0.3');
  });

  tearDown(() {
    AppUpdateService.instance.httpClientOverride = null;
    AppUpdateService.instance.currentVersionOverride = null;
  });

  group('UpdateSetupScreen', () {
    testWidgets('defaults to auto check enabled and persists the toggle', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const UpdateSetupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('保持最新'), findsOneWidget);
      expect(find.text('自动检查更新'), findsOneWidget);

      final switchTile = tester.widget<SwitchListTile>(
        find.byType(SwitchListTile),
      );
      expect(switchTile.value, isTrue);
      expect(UpdatePreferences.autoCheckEnabled, isTrue);

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(UpdatePreferences.autoCheckEnabled, isFalse);
    });

    testWidgets('offers a skip action that keeps the default', (tester) async {
      // 跳过只标记引导已读，不改动开关值。
      final router = GoRouter(
        initialLocation: '/updates/setup',
        routes: [
          GoRoute(
            path: '/updates/setup',
            builder: (_, _) => const UpdateSetupScreen(),
          ),
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(body: Text('登录页')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('跳过'));
      await tester.pumpAndSettle();

      expect(find.text('登录页'), findsOneWidget);
      expect(UpdatePreferences.setupHandled, isTrue);
      expect(UpdatePreferences.autoCheckEnabled, isTrue);
    });
  });

  group('AboutScreen update section', () {
    testWidgets('shows latest version and its changes', (tester) async {
      mockPackageVersion('1.0.0');
      AppUpdateService.instance.currentVersionOverride = '1.0.0';
      AppUpdateService.instance.httpClientOverride = mockedLatestBody(
        '1.1.0\n- 新增更新设置页\n- 修复下载弹窗',
      );

      await tester.pumpWidget(_app(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('更新'), findsOneWidget);
      expect(find.text('最新版本'), findsOneWidget);
      expect(find.text('1.1.0（有新版本可用）'), findsOneWidget);
      expect(find.text('本版本变动'), findsOneWidget);
      expect(find.text('新增更新设置页'), findsOneWidget);
      expect(find.text('修复下载弹窗'), findsOneWidget);
    });

    testWidgets('reports up to date when versions match', (tester) async {
      mockPackageVersion('1.1.0');
      AppUpdateService.instance.currentVersionOverride = '1.1.0';
      AppUpdateService.instance.httpClientOverride = mockedLatestBody('1.1.0');

      await tester.pumpWidget(_app(const AboutScreen()));
      await tester.pumpAndSettle();

      expect(find.text('1.1.0（已是最新版本）'), findsOneWidget);
      // 没有变动说明时不显示该区块。
      expect(find.text('本版本变动'), findsNothing);
    });

    testWidgets('manual check surfaces the update dialog', (tester) async {
      mockPackageVersion('1.0.0');
      AppUpdateService.instance.currentVersionOverride = '1.0.0';
      AppUpdateService.instance.httpClientOverride = mockedLatestBody(
        '1.1.0\n- 新增更新设置页',
      );

      await tester.pumpWidget(_app(const AboutScreen()));
      await tester.pumpAndSettle();

      // 关于页可滚动，更新区块可能不在首屏，先滚到可见再点。
      await tester.ensureVisible(find.text('检查更新'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('检查更新'));
      await tester.pumpAndSettle();

      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('新增更新设置页'), findsWidgets);

      // 关掉弹窗，避免单例里的「流程进行中」标记泄漏到后续用例。
      await tester.tap(find.text('稍后'));
      await tester.pumpAndSettle();
    });
  });

  group('forced update flow', () {
    testWidgets('prompts even when already on the latest version', (
      tester,
    ) async {
      AppUpdateService.instance.currentVersionOverride = '1.1.0';
      AppUpdateService.instance.httpClientOverride = mockedLatestBody('1.1.0');

      late BuildContext captured;
      await tester.pumpWidget(
        _app(
          Builder(
            builder: (context) {
              captured = context;
              return const Scaffold(body: Text('首页'));
            },
          ),
        ),
      );

      // 弹窗会一直等用户选择，这里先不等待 future，否则测试会卡住。
      final pending = AppUpdateFlow.instance.forceUpdateFlow(captured);
      await tester.pumpAndSettle();

      expect(find.text('发现新版本'), findsOneWidget);
      expect(find.text('立即更新'), findsOneWidget);

      await tester.tap(find.text('稍后'));
      await tester.pumpAndSettle();
      await pending;
      expect(find.text('发现新版本'), findsNothing);
    });
  });
}
