import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/secure_credentials.dart';
import 'package:touchfish_client/services/security_notice_service.dart';
import 'package:touchfish_client/widgets/security_notice_banners.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SettingsService.instance.debugReset();
    await SettingsService.instance.init();
    SecurityNoticeService.instance.resetForTest();
    await SecurityNoticeService.instance.init();
  });

  tearDown(() {
    SecureCredentials.instance.resetProbeState();
    SecureCredentials.isWebPlatform = () => kIsWeb;
    SecureCredentials.webIsSecureContext = () => true;
  });

  Future<void> restartSecurityNotices() async {
    SecurityNoticeService.instance.resetForTest();
    await SecurityNoticeService.instance.init();
  }

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );

  group('SecurityNoticeService persistence', () {
    test('dismissal survives a restart', () async {
      expect(SecurityNoticeService.instance.httpsFallbackDismissed, isFalse);

      await SecurityNoticeService.instance.dismissHttpsFallback();
      expect(SecurityNoticeService.instance.httpsFallbackDismissed, isTrue);
      expect(
        SettingsService.instance.getValue<bool>(
          SecurityNoticeService.kHttpsFallbackDismissedKey,
          false,
        ),
        isTrue,
      );

      await restartSecurityNotices();
      expect(SecurityNoticeService.instance.httpsFallbackDismissed, isTrue);
    });

    test('insecure context dismissal survives a restart', () async {
      await SecurityNoticeService.instance.dismissInsecureContext();
      await restartSecurityNotices();
      expect(SecurityNoticeService.instance.insecureContextDismissed, isTrue);
    });

    test('https fallback state is per-run, not persisted', () async {
      SecurityNoticeService.instance.reportHttpsFallback();
      expect(SecurityNoticeService.instance.httpsFallbackActive, isTrue);
      await restartSecurityNotices();
      expect(SecurityNoticeService.instance.httpsFallbackActive, isFalse);
    });

    test('repeated dismiss does not notify twice', () async {
      var notified = 0;
      void listener() => notified++;
      SecurityNoticeService.instance.addListener(listener);
      addTearDown(
        () => SecurityNoticeService.instance.removeListener(listener),
      );

      await SecurityNoticeService.instance.dismissInsecureContext();
      await SecurityNoticeService.instance.dismissInsecureContext();
      expect(notified, 1);
    });
  });

  group('HttpsFallbackBanner', () {
    const title = '连接已自动降级为明文 HTTP';

    testWidgets('hidden until a downgrade is reported', (tester) async {
      await tester.pumpWidget(wrap(const HttpsFallbackBanner()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);

      SecurityNoticeService.instance.reportHttpsFallback();
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    });

    testWidgets('dismiss hides it and it stays hidden after restart', (
      tester,
    ) async {
      SecurityNoticeService.instance.reportHttpsFallback();
      await tester.pumpWidget(wrap(const HttpsFallbackBanner()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
      expect(SecurityNoticeService.instance.httpsFallbackDismissed, isTrue);

      await restartSecurityNotices();
      SecurityNoticeService.instance.reportHttpsFallback();
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    });
  });

  group('InsecureStorageBanner', () {
    const title = '登录凭据将以未加密方式保存';

    Future<void> enterInsecureWebContext() async {
      SecureCredentials.instance.resetProbeState();
      SecureCredentials.isWebPlatform = () => true;
      SecureCredentials.webIsSecureContext = () => false;
      await SecureCredentials.instance.probe(force: true);
    }

    testWidgets('shows on insecure context and hides after dismissal', (
      tester,
    ) async {
      await enterInsecureWebContext();
      await tester.pumpWidget(wrap(const InsecureStorageBanner()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    });

    testWidgets('stays hidden after restart once dismissed', (tester) async {
      await SecurityNoticeService.instance.dismissInsecureContext();
      await enterInsecureWebContext();
      await restartSecurityNotices();

      await tester.pumpWidget(wrap(const InsecureStorageBanner()));
      await tester.pumpAndSettle();
      expect(find.text(title), findsNothing);
    });
  });
}
