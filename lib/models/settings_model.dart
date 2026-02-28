import 'package:flutter/material.dart';

enum SettingType {
  switchSetting,
  dropdown,
  radio,
  navigation,
  slider,
  customWidget,
}

enum SettingCategory {
  appearance,
  notifications,
  about,
}

class SettingItem {
  final String key;
  final String titleKey;
  final String? descriptionKey;
  final SettingType type;
  final dynamic defaultValue;
  final List<SettingOption>? options;
  final List<SettingItem>? subItems;
  final IconData? icon;

  const SettingItem({
    required this.key,
    required this.titleKey,
    this.descriptionKey,
    required this.type,
    required this.defaultValue,
    this.options,
    this.subItems,
    this.icon,
  });
}

class SettingOption {
  final String value;
  final String labelKey;

  const SettingOption({
    required this.value,
    required this.labelKey,
  });
}

class SettingCategoryData {
  final SettingCategory category;
  final String titleKey;
  final IconData icon;
  final List<SettingItem> items;

  const SettingCategoryData({
    required this.category,
    required this.titleKey,
    required this.icon,
    required this.items,
  });
}

class SettingsData {
  static const List<SettingCategoryData> categories = [
    SettingCategoryData(
      category: SettingCategory.appearance,
      titleKey: 'settingsCategoryAppearance',
      icon: Icons.brush,
      items: [
        SettingItem(
          key: 'language',
          titleKey: 'settingsLanguageTitle',
          descriptionKey: 'settingsLanguageDesc',
          type: SettingType.dropdown,
          defaultValue: 'system',
          icon: Icons.language,
          options: [
            SettingOption(value: 'system', labelKey: 'settingsLanguageSystem'),
            SettingOption(value: 'zh', labelKey: 'settingsLanguageZh'),
            SettingOption(value: 'en', labelKey: 'settingsLanguageEn'),
          ],
        ),
        SettingItem(
          key: 'theme',
          titleKey: 'settingsThemeTitle',
          descriptionKey: 'settingsThemeDesc',
          type: SettingType.dropdown,
          defaultValue: 'system',
          icon: Icons.dark_mode,
          options: [
            SettingOption(value: 'system', labelKey: 'settingsThemeSystem'),
            SettingOption(value: 'light', labelKey: 'settingsThemeLight'),
            SettingOption(value: 'dark', labelKey: 'settingsThemeDark'),
          ],
        ),
        SettingItem(
          key: 'themeColor',
          titleKey: 'settingsThemeColorTitle',
          descriptionKey: 'settingsThemeColorDesc',
          type: SettingType.dropdown,
          defaultValue: 'blue',
          icon: Icons.color_lens,
          options: [
            SettingOption(value: 'blue', labelKey: 'settingsColorDefault'),
            SettingOption(value: 'red', labelKey: 'settingsColorRed'),
            SettingOption(value: 'green', labelKey: 'settingsColorGreen'),
            SettingOption(value: 'purple', labelKey: 'settingsColorPurple'),
            SettingOption(value: 'orange', labelKey: 'settingsColorOrange'),
            SettingOption(value: 'custom', labelKey: 'settingsColorCustom'),
          ],
        ),
        SettingItem(
          key: 'fontFamily',
          titleKey: 'settingsFontFamilyTitle',
          descriptionKey: 'settingsFontFamilyDesc',
          type: SettingType.dropdown,
          defaultValue: 'HarmonyOS Sans SC',
          icon: Icons.font_download,
          options: [],
        ),
        SettingItem(
          key: 'sendMode',
          titleKey: 'settingsSendModeTitle',
          descriptionKey: 'settingsSendModeDesc',
          type: SettingType.radio,
          defaultValue: 'enter',
          icon: Icons.keyboard,
          options: [
            SettingOption(value: 'enter', labelKey: 'settingsSendModeEnter'),
            SettingOption(
                value: 'ctrlEnter', labelKey: 'settingsSendModeCtrlEnter'),
          ],
        ),
        SettingItem(
          key: 'enableMarkdownRendering',
          titleKey: 'settingsEnableMarkdownTitle',
          descriptionKey: 'settingsEnableMarkdownDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.text_format,
        ),
        SettingItem(
          key: 'cardOpacity',
          titleKey: 'settingsCardOpacityTitle',
          descriptionKey: 'settingsCardOpacityDesc',
          type: SettingType.slider,
          defaultValue: 1.0,
          icon: Icons.opacity,
        ),
        SettingItem(
          key: 'windowOpacity',
          titleKey: 'settingsWindowOpacityTitle',
          descriptionKey: 'settingsWindowOpacityDesc',
          type: SettingType.slider,
          defaultValue: 1.0,
          icon: Icons.blur_on,
        ),
        SettingItem(
          key: 'backgroundImage',
          titleKey: 'settingsBackgroundImageTitle',
          descriptionKey: 'settingsBackgroundImageDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.wallpaper,
        ),
        SettingItem(
          key: 'customTheme',
          titleKey: 'settingsCustomThemeTitle',
          descriptionKey: 'settingsCustomThemeDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.palette,
        ),
      ],
    ),
    SettingCategoryData(
      category: SettingCategory.notifications,
      titleKey: 'settingsCategoryNotifications',
      icon: Icons.notifications_active,
      items: [
        SettingItem(
          key: 'systemNotifications',
          titleKey: 'settingsSystemNotificationsTitle',
          descriptionKey: 'settingsSystemNotificationsDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.notifications,
        ),
        SettingItem(
          key: 'inAppNotifications',
          titleKey: 'settingsInAppNotificationsTitle',
          descriptionKey: 'settingsInAppNotificationsDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.notifications_active,
        ),
        SettingItem(
          key: 'notificationSound',
          titleKey: 'settingsNotificationSoundTitle',
          descriptionKey: 'settingsNotificationSoundDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.volume_up,
        ),
        SettingItem(
          key: 'chatNotifications',
          titleKey: 'settingsChatNotificationsTitle',
          descriptionKey: 'settingsChatNotificationsDesc',
          type: SettingType.dropdown,
          defaultValue: 'both',
          icon: Icons.chat,
          options: [],
          subItems: [
            SettingItem(
              key: 'privateChat',
              titleKey: 'settingsPrivateChatTitle',
              descriptionKey: null,
              type: SettingType.switchSetting,
              defaultValue: true,
              icon: Icons.person,
            ),
            SettingItem(
              key: 'groupChat',
              titleKey: 'settingsGroupChatTitle',
              descriptionKey: null,
              type: SettingType.switchSetting,
              defaultValue: true,
              icon: Icons.group,
            ),
          ],
        ),
      ],
    ),
    SettingCategoryData(
      category: SettingCategory.about,
      titleKey: 'settingsCategoryAbout',
      icon: Icons.info_outline,
      items: [
        SettingItem(
          key: 'aboutApp',
          titleKey: 'settingsAboutAppTitle',
          descriptionKey: null,
          type: SettingType.navigation,
          defaultValue: null,
          icon: Icons.info_outline,
        ),
      ],
    ),
  ];
}
