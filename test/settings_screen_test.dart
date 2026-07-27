import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('custom preview limit survives confirm and cancel teardown', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'automaticPreviewMaxMiB': 10});
    await SettingsService.instance.init();
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final previewSetting = find.text('Automatic file previews');
    await tester.scrollUntilVisible(
      previewSetting,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    final previewTile = find.ancestor(
      of: previewSetting,
      matching: find.byType(ListTile),
    );
    final dropdownFinder = find.descendant(
      of: previewTile,
      matching: find.byType(CustomDropdown<String>),
    );
    tester
        .widget<CustomDropdown<String>>(dropdownFinder)
        .onChanged
        ?.call('Custom');
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), '25');
    await tester.tap(find.text('Confirm'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      SettingsService.instance.getValue<int>('automaticPreviewMaxMiB', 0),
      25,
    );

    tester
        .widget<CustomDropdown<String>>(dropdownFinder)
        .onChanged
        ?.call('Custom');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      SettingsService.instance.getValue<int>('automaticPreviewMaxMiB', 0),
      25,
    );
    expect(tester.takeException(), isNull);
  });
}
