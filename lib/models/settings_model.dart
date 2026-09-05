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
  connection,
  storage,
  security,
  drafts,
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

  const SettingOption({required this.value, required this.labelKey});
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
            SettingOption(value: 'och', labelKey: 'settingsLanguageCc'),
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
              value: 'ctrlEnter',
              labelKey: 'settingsSendModeCtrlEnter',
            ),
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
          key: 'messageDisplayStyle',
          titleKey: 'settingsMessageDisplayStyleTitle',
          descriptionKey: 'settingsMessageDisplayStyleDesc',
          type: SettingType.dropdown,
          defaultValue: 'bubble',
          icon: Icons.chat_bubble_outline,
          options: [
            SettingOption(value: 'bubble', labelKey: 'settingsMessageDisplayStyleBubble'),
            SettingOption(value: 'compact', labelKey: 'settingsMessageDisplayStyleCompact'),
            SettingOption(value: 'column', labelKey: 'settingsMessageDisplayStyleColumn'),
          ],
        ),
        SettingItem(
          key: 'automaticPreviewMaxMiB',
          titleKey: 'settingsAutomaticPreviewTitle',
          descriptionKey: 'settingsAutomaticPreviewDesc',
          type: SettingType.customWidget,
          defaultValue: 10,
          icon: Icons.preview,
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
        SettingItem(
          key: 'enableAnimations',
          titleKey: 'settingsEnableAnimationsTitle',
          descriptionKey: 'settingsEnableAnimationsDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.animation,
        ),
        SettingItem(
          key: 'layoutMode',
          titleKey: 'settingsLayoutModeTitle',
          descriptionKey: 'settingsLayoutModeDesc',
          type: SettingType.dropdown,
          defaultValue: 'auto',
          icon: Icons.phone_iphone,
          options: [
            SettingOption(value: 'auto', labelKey: 'settingsLayoutModeAuto'),
            SettingOption(
              value: 'forceWide',
              labelKey: 'settingsLayoutModeForceWide',
            ),
            SettingOption(
              value: 'forceNarrow',
              labelKey: 'settingsLayoutModeForceNarrow',
            ),
          ],
        ),
        SettingItem(
          key: 'wideScreenThreshold',
          titleKey: 'settingsWideThresholdTitle',
          descriptionKey: 'settingsWideThresholdDesc',
          type: SettingType.customWidget,
          defaultValue: 600,
          icon: Icons.vertical_align_center,
        ),
      ],
    ),
    SettingCategoryData(
      category: SettingCategory.notifications,
      titleKey: 'settingsCategoryNotifications',
      icon: Icons.notifications_active,
      items: [
        SettingItem(
          key: 'closeToTray',
          titleKey: 'settingsCloseToTrayTitle',
          descriptionKey: 'settingsCloseToTrayDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.system_update_alt,
        ),
        SettingItem(
          key: 'systemNotifications',
          titleKey: 'settingsSystemNotificationsTitle',
          descriptionKey: 'settingsSystemNotificationsDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.notifications,
        ),
        SettingItem(
          key: 'notificationLevel',
          titleKey: 'settingsNotificationLevelTitle',
          descriptionKey: 'settingsNotificationLevelDesc',
          type: SettingType.dropdown,
          defaultValue: '2',
          icon: Icons.notifications_paused,
          options: [
            SettingOption(
              value: '1',
              labelKey: 'settingsNotificationLevelMinimal',
            ),
            SettingOption(
              value: '2',
              labelKey: 'settingsNotificationLevelPerSender',
            ),
            SettingOption(
              value: '3',
              labelKey: 'settingsNotificationLevelFull',
            ),
          ],
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
          key: 'notifyWithHaptic',
          titleKey: 'settingsNotifyWithHaptic',
          descriptionKey: 'settingsNotifyWithHapticDescription',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.vibration,
        ),
        SettingItem(
          key: 'lockscreenReply',
          titleKey: 'settingsLockscreenReplyTitle',
          descriptionKey: 'settingsLockscreenReplyDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.lock_open,
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
      category: SettingCategory.connection,
      titleKey: 'settingsCategoryConnection',
      icon: Icons.link,
      items: [
        SettingItem(
          key: 'mediaProxyEnabled',
          titleKey: 'settingsMediaProxy',
          descriptionKey: 'settingsMediaProxyDescription',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.speed,
        ),
        SettingItem(
          key: 'weakNetworkMode',
          titleKey: 'settingsWeakNetworkTitle',
          descriptionKey: 'settingsWeakNetworkDesc',
          type: SettingType.switchSetting,
          defaultValue: false,
          icon: Icons.network_check,
        ),
        SettingItem(
          key: 'dataSavingMode',
          titleKey: 'settingsDataSavingTitle',
          descriptionKey: 'settingsDataSavingDesc',
          type: SettingType.switchSetting,
          defaultValue: false,
          icon: Icons.data_saver_on,
        ),
        SettingItem(
          key: 'ipOverrideMode',
          titleKey: 'settingsIpOverrideTitle',
          descriptionKey: 'settingsIpOverrideDesc',
          type: SettingType.dropdown,
          defaultValue: 'off',
          icon: Icons.dns,
          options: [
            SettingOption(value: 'off', labelKey: 'settingsIpOverrideOff'),
            SettingOption(value: 'mixed', labelKey: 'settingsIpOverrideMixed'),
            SettingOption(
              value: 'complete',
              labelKey: 'settingsIpOverrideComplete',
            ),
          ],
        ),
        SettingItem(
          key: 'ipOverrideDomains',
          titleKey: 'settingsIpOverrideDomainsTitle',
          descriptionKey: 'settingsIpOverrideDomainsDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.domain,
        ),
        SettingItem(
          key: 'ipOverrideEntries',
          titleKey: 'settingsIpOverrideEntriesTitle',
          descriptionKey: 'settingsIpOverrideEntriesDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.lan,
        ),
        SettingItem(
          key: 'connectionStatus',
          titleKey: 'settingsConnectionStatusTitle',
          descriptionKey: 'settingsConnectionStatusDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.network_check,
        ),
        SettingItem(
          key: 'connectivitySelfCheck',
          titleKey: 'settingsConnectivitySelfCheckTitle',
          descriptionKey: 'settingsConnectivitySelfCheckDesc',
          type: SettingType.navigation,
          defaultValue: null,
          icon: Icons.rule,
        ),
        SettingItem(
          key: 'forceExplicitSync',
          titleKey: 'settingsForceExplicitSyncTitle',
          descriptionKey: 'settingsForceExplicitSyncDesc',
          type: SettingType.switchSetting,
          defaultValue: false,
          icon: Icons.sync,
        ),
        SettingItem(
          key: 'explicitSyncCooldownSeconds',
          titleKey: 'settingsExplicitSyncCooldownTitle',
          descriptionKey: 'settingsExplicitSyncCooldownDesc',
          type: SettingType.dropdown,
          defaultValue: '30',
          icon: Icons.timer_outlined,
          options: [
            SettingOption(value: '10', labelKey: 'settingsSeconds10'),
            SettingOption(value: '30', labelKey: 'settingsSeconds30'),
            SettingOption(value: '60', labelKey: 'settingsSeconds60'),
            SettingOption(value: '120', labelKey: 'settingsSeconds120'),
            SettingOption(value: '300', labelKey: 'settingsSeconds300'),
          ],
        ),
        SettingItem(
          key: 'domainTrustImageBlockEnabled',
          titleKey: 'settingsDomainTrustImageBlockTitle',
          descriptionKey: 'settingsDomainTrustImageBlockDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.image_not_supported_outlined,
        ),
        SettingItem(
          key: 'domainTrustLinkWarningEnabled',
          titleKey: 'settingsDomainTrustLinkWarningTitle',
          descriptionKey: 'settingsDomainTrustLinkWarningDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.travel_explore,
        ),
        SettingItem(
          key: 'trustedDomains',
          titleKey: 'settingsTrustedDomainsTitle',
          descriptionKey: 'settingsTrustedDomainsDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.domain,
        ),
        SettingItem(
          key: 'legacyAuthMode',
          titleKey: 'settingsLegacyAuthTitle',
          descriptionKey: 'settingsLegacyAuthDesc',
          type: SettingType.switchSetting,
          defaultValue: false,
          icon: Icons.password,
        ),
        SettingItem(
          key: 'savedRsaKeys',
          titleKey: 'settingsRsaKeysTitle',
          descriptionKey: 'settingsRsaKeysDesc',
          type: SettingType.navigation,
          defaultValue: null,
          icon: Icons.key_outlined,
        ),
      ],
    ),
    SettingCategoryData(
      category: SettingCategory.storage,
      titleKey: 'settingsCategoryStorage',
      icon: Icons.storage,
      items: [
        SettingItem(
          key: 'localStorage',
          titleKey: 'settingsCategoryStorage',
          type: SettingType.customWidget,
          defaultValue: null,
        ),
        SettingItem(
          key: 'maxCachedRooms',
          titleKey: 'maxCachedRooms',
          descriptionKey: 'maxCachedRoomsDesc',
          type: SettingType.customWidget,
          defaultValue: 50,
          icon: Icons.memory,
        ),
        SettingItem(
          key: 'autoLoadingStickers',
          titleKey: 'settingsAutoLoadStickersTitle',
          descriptionKey: 'settingsAutoLoadStickersDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.sticky_note_2_outlined,
        ),
        SettingItem(
          key: 'chatStickerRecentTab',
          titleKey: 'settingsChatStickerRecentTabTitle',
          descriptionKey: 'settingsChatStickerRecentTabDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.history,
        ),
      ],
    ),
    SettingCategoryData(
      category: SettingCategory.security,
      titleKey: 'settingsCategorySecurity',
      icon: Icons.lock_outline,
      items: [
        SettingItem(
          key: 'masterPassword',
          titleKey: 'settingsSecurityMasterPasswordTitle',
          descriptionKey: 'settingsSecurityMasterPasswordDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.password,
        ),
        SettingItem(
          key: 'biometricUnlock',
          titleKey: 'settingsSecurityBiometricTitle',
          descriptionKey: 'settingsSecurityBiometricDesc',
          type: SettingType.customWidget,
          defaultValue: false,
          icon: Icons.fingerprint,
        ),
        SettingItem(
          key: 'lockNow',
          titleKey: 'settingsSecurityLockNowTitle',
          descriptionKey: 'settingsSecurityLockNowDesc',
          type: SettingType.customWidget,
          defaultValue: null,
          icon: Icons.lock,
        ),
        SettingItem(
          key: 'showOnLockScreen',
          titleKey: 'settingsShowOnLockScreenTitle',
          descriptionKey: 'settingsShowOnLockScreenDesc',
          type: SettingType.switchSetting,
          defaultValue: false,
          icon: Icons.lock_open,
        ),
        SettingItem(
          key: 'builtInKeyboardMode',
          titleKey: 'settingsBuiltInKeyboardTitle',
          descriptionKey: 'settingsBuiltInKeyboardDesc',
          type: SettingType.dropdown,
          defaultValue: 'never',
          icon: Icons.keyboard,
          options: [
            SettingOption(
              value: 'never',
              labelKey: 'settingsBuiltInKeyboardNever',
            ),
            SettingOption(
              value: 'lock',
              labelKey: 'settingsBuiltInKeyboardLock',
            ),
            SettingOption(
              value: 'always',
              labelKey: 'settingsBuiltInKeyboardAlways',
            ),
          ],
        ),
        SettingItem(
          key: 'linkOpenMode',
          titleKey: 'settingsLinkOpenModeTitle',
          descriptionKey: 'settingsLinkOpenModeDesc',
          type: SettingType.dropdown,
          defaultValue: 'inapp',
          icon: Icons.public,
          options: [
            SettingOption(
              value: 'inapp',
              labelKey: 'settingsLinkOpenModeInapp',
            ),
            SettingOption(
              value: 'external',
              labelKey: 'settingsLinkOpenModeExternal',
            ),
          ],
        ),
        SettingItem(
          key: 'browserSearchEngine',
          titleKey: 'settingsBrowserSearchEngineTitle',
          descriptionKey: 'settingsBrowserSearchEngineDesc',
          type: SettingType.dropdown,
          defaultValue: 'bing',
          icon: Icons.search,
          options: [
            SettingOption(
              value: 'bing',
              labelKey: 'settingsBrowserSearchEngineBing',
            ),
            SettingOption(
              value: 'duckduckgo',
              labelKey: 'settingsBrowserSearchEngineDuckduckgo',
            ),
            SettingOption(
              value: 'baidu',
              labelKey: 'settingsBrowserSearchEngineBaidu',
            ),
          ],
        ),
        SettingItem(
          key: 'browserUserAgent',
          titleKey: 'settingsBrowserUserAgentTitle',
          descriptionKey: 'settingsBrowserUserAgentDesc',
          type: SettingType.customWidget,
          defaultValue: '',
          icon: Icons.devices,
        ),
        SettingItem(
          key: 'browserMixedContent',
          titleKey: 'settingsBrowserMixedContentTitle',
          descriptionKey: 'settingsBrowserMixedContentDesc',
          type: SettingType.dropdown,
          defaultValue: 'block',
          icon: Icons.warning_amber_rounded,
          options: [
            SettingOption(
              value: 'block',
              labelKey: 'settingsBrowserMixedContentBlock',
            ),
            SettingOption(
              value: 'allow',
              labelKey: 'settingsBrowserMixedContentAllow',
            ),
          ],
        ),
        SettingItem(
          key: 'launchInAppBrowser',
          titleKey: 'settingsLaunchBrowserTitle',
          descriptionKey: 'settingsLaunchBrowserDesc',
          type: SettingType.navigation,
          defaultValue: null,
          icon: Icons.public,
        ),
        SettingItem(
          key: 'savedRsaKeysSecurity',
          titleKey: 'settingsRsaKeysTitle',
          descriptionKey: 'settingsRsaKeysDesc',
          type: SettingType.navigation,
          defaultValue: null,
          icon: Icons.key_outlined,
        ),
      ],
    ),
    SettingCategoryData(
      category: SettingCategory.drafts,
      titleKey: 'settingsCategoryDrafts',
      icon: Icons.edit_note,
      items: [
        SettingItem(
          key: 'saveChatDrafts',
          titleKey: 'settingsSaveChatDraftsTitle',
          descriptionKey: 'settingsSaveChatDraftsDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.chat_bubble_outline,
        ),
        SettingItem(
          key: 'saveForumDrafts',
          titleKey: 'settingsSaveForumDraftsTitle',
          descriptionKey: 'settingsSaveForumDraftsDesc',
          type: SettingType.switchSetting,
          defaultValue: true,
          icon: Icons.forum_outlined,
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
