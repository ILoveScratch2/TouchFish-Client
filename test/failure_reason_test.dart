import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/utils/failure_reason.dart';

void main() {
  testWidgets('known codes map to localized text', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      localizeFailureReason(l10n, SendFailureReason.network),
      l10n.messageSendNetworkFailed,
    );
    expect(
      localizeFailureReason(l10n, SendFailureReason.rejected),
      l10n.messageSendRejected,
    );
    expect(
      localizeFailureReason(l10n, SendFailureReason.upload),
      l10n.messageSendUploadFailed,
    );
  });

  testWidgets('unknown reason falls back to the server text', (tester) async {
    late AppLocalizations l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(localizeFailureReason(l10n, 'room muted by admin'), 'room muted by admin');
  });

  test('failure reason codes are stable strings', () {
    // 这些码会随消息持久化
    // 不能更改
    expect(SendFailureReason.timeout, 'send.timeout');
    expect(SendFailureReason.network, 'send.network');
    expect(SendFailureReason.rejected, 'send.rejected');
    expect(SendFailureReason.upload, 'send.upload');
  });
}
