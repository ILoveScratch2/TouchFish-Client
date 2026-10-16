import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/widgets/data_saving_image.dart';
import 'package:touchfish_client/widgets/optimized_image.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  Widget wrap(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  Future<void> setDataSaving(bool on) =>
      SettingsService.instance.setValue('dataSavingMode', on);

  testWidgets('data saving on: shows download placeholder until tapped', (
    tester,
  ) async {
    await setDataSaving(true);
    await tester.pumpWidget(
      wrap(const DataSavingImage(url: 'https://example.com/a.png')),
    );
    await tester.pump();

    expect(find.byIcon(Icons.download_for_offline_outlined), findsOneWidget);
    expect(find.byType(OptimizedImage), findsNothing);

    await tester.tap(find.byIcon(Icons.download_for_offline_outlined));
    await tester.pump();
    expect(find.byType(OptimizedImage), findsOneWidget);
  });

  testWidgets('data saving off: renders OptimizedImage directly', (
    tester,
  ) async {
    await setDataSaving(false);
    await tester.pumpWidget(
      wrap(const DataSavingImage(url: 'https://example.com/a.png')),
    );
    await tester.pump();

    expect(find.byIcon(Icons.download_for_offline_outlined), findsNothing);
    expect(find.byType(OptimizedImage), findsOneWidget);
  });

  testWidgets('explicit size flows through to the image box', (tester) async {
    await setDataSaving(false);
    await tester.pumpWidget(
      wrap(
        const DataSavingImage(
          url: 'https://example.com/a.png',
          width: 32,
          height: 32,
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(DataSavingImage)), const Size(32, 32));
  });

  testWidgets('OptimizedImage honors explicit width/height', (tester) async {
    await tester.pumpWidget(
      wrap(
        OptimizedImage(
          provider: const NetworkImage('https://example.com/a.png'),
          width: 40,
          height: 24,
        ),
      ),
    );
    await tester.pump();

    expect(tester.getSize(find.byType(OptimizedImage)), const Size(40, 24));
  });
}
