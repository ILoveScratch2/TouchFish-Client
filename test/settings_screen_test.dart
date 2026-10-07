import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/settings_model.dart';
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

  testWidgets('no raw setting keys are displayed in any category', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
    // 高视口让内容列表一次性构建全部设置项（ListVierw.builder 懒构建）。
    await tester.binding.setSurfaceSize(const Size(1000, 4000));
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
    // 字体下拉的 FutureBuilder 在测试环境不会完成，转圈动画会令
    // pumpAndSettle 永不收敛，因此用固定时长的 pump。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final keys = <String>[];
    void collectKeys(SettingItem item) {
      keys.add(item.titleKey);
      if (item.descriptionKey != null) keys.add(item.descriptionKey!);
      for (final option in item.options ?? const <SettingOption>[]) {
        keys.add(option.labelKey);
      }
      for (final subItem in item.subItems ?? const <SettingItem>[]) {
        collectKeys(subItem);
      }
    }

    for (final category in SettingsData.categories) {
      for (final item in category.items) {
        collectKeys(item);
      }
    }

    // 宽布局下左侧分类列表是第一个 ListView；逐一切换并检查整页。
    final sidebarTiles = find.descendant(
      of: find.byType(ListView).first,
      matching: find.byType(ListTile),
    );
    for (var i = 0; i < SettingsData.categories.length; i++) {
      await tester.tap(sidebarTiles.at(i));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final key in keys) {
        expect(
          find.text(key, skipOffstage: false),
          findsNothing,
          reason: 'Raw translation key "$key" is displayed on the screen',
        );
      }
    }
  });
}
