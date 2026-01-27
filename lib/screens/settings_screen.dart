import 'package:flutter/material.dart';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import '../l10n/app_localizations.dart';
import '../models/settings_model.dart';
import '../models/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with TickerProviderStateMixin {
  final _settingsService = SettingsService.instance;
  SettingCategory? _selectedCategory;
  late AnimationController _categoryAnimationController;

  @override
  void initState() {
    super.initState();
    _settingsService.init();
    
    _categoryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _categoryAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 600;

        if (isWideScreen && _selectedCategory == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedCategory == null) {
              setState(() {
                _selectedCategory = SettingsData.categories.first.category;
              });
            }
          });
        }

        if (isWideScreen) {
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.settingsTitle),
            ),
            body: _buildWideLayout(context),
          );
        } else {
          if (_selectedCategory == null) {
            return Scaffold(
              appBar: AppBar(
                title: Text(AppLocalizations.of(context)!.settingsTitle),
              ),
              body: _buildNarrowLayout(context),
            );
          } else {
            return _buildNarrowLayout(context);
          }
        }
      },
    );
  }

  Widget _buildWideLayout(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 240,
          child: _buildCategoryList(context, isWideLayout: true),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _selectedCategory == null
                ? KeyedSubtree(
                    key: const ValueKey('empty'),
                    child: _buildEmptyState(context),
                  )
                : KeyedSubtree(
                    key: ValueKey(_selectedCategory),
                    child: _buildSettingsContent(context, _selectedCategory!),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        );
      },
      child: _selectedCategory == null
          ? KeyedSubtree(
              key: const ValueKey('category_list'),
              child: _buildCategoryList(context, isWideLayout: false),
            )
          : KeyedSubtree(
              key: ValueKey(_selectedCategory),
              child: _buildSettingsContent(context, _selectedCategory!),
            ),
    );
  }

  Widget _buildCategoryList(BuildContext context,
      {required bool isWideLayout}) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      children: SettingsData.categories.map((category) {
        final isSelected = _selectedCategory == category.category;
        final title = _getCategoryTitle(l10n, category.titleKey);

        return ListTile(
          leading: Icon(category.icon),
          title: Text(title),
          selected: isWideLayout && isSelected,
          onTap: () {
            setState(() {
              _selectedCategory = category.category;
            });
          },
          trailing: isWideLayout ? null : const Icon(Icons.chevron_right),
        );
      }).toList(),
    );
  }

  Widget _buildSettingsContent(BuildContext context, SettingCategory category) {
    final l10n = AppLocalizations.of(context)!;
    final categoryData = SettingsData.categories
        .firstWhere((c) => c.category == category);
    final isWideScreen = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: isWideScreen
          ? null
          : AppBar(
              title: Text(_getCategoryTitle(l10n, categoryData.titleKey)),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedCategory = null;
                  });
                },
              ),
            ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: categoryData.items.length,
        itemBuilder: (context, index) {
          final item = categoryData.items[index];
          return _buildSettingItem(context, item);
        },
      ),
    );
  }

  Widget _buildSettingItem(BuildContext context, SettingItem item) {
    final l10n = AppLocalizations.of(context)!;

    switch (item.type) {
      case SettingType.switchSetting:
        return _buildSwitchSetting(context, l10n, item);
      case SettingType.dropdown:
        if (item.key == 'language' || item.key == 'themeColor') {
          return _buildCustomDropdownSetting(context, l10n, item);
        }
        if (item.key == 'theme') {
          return _buildToggleSwitchSetting(context, l10n, item);
        }
        return _buildDropdownSetting(context, l10n, item);
      case SettingType.radio:
        return _buildRadioSetting(context, l10n, item);
      case SettingType.navigation:
        return _buildNavigationSetting(context, l10n, item);
    }
  }

  Widget _buildCustomDropdownSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<String>(
          item.key,
          item.defaultValue as String,
        );

        final selectedLabel = _getSettingTitle(
          l10n, 
          item.options!.firstWhere((o) => o.value == value).labelKey
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSettingTitle(l10n, item.titleKey),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (item.descriptionKey != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _getSettingTitle(l10n, item.descriptionKey!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 140,
                    child: CustomDropdown<String>(
                      hintText: '',
                      initialItem: selectedLabel,
                      items: item.options!.map((o) => _getSettingTitle(l10n, o.labelKey)).toList(),
                      decoration: CustomDropdownDecoration(
                        closedBorderRadius: BorderRadius.circular(8),
                        expandedBorderRadius: BorderRadius.circular(8),
                        closedFillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        expandedFillColor: Theme.of(context).colorScheme.surface,
                      ),
                      onChanged: (newValue) {
                        if (newValue != null) {
                          final option = item.options!.firstWhere(
                            (o) => _getSettingTitle(l10n, o.labelKey) == newValue,
                          );
                          _settingsService.setValue(item.key, option.value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToggleSwitchSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<String>(
          item.key,
          item.defaultValue as String,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  if (item.icon != null) ...[
                    Icon(item.icon),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getSettingTitle(l10n, item.titleKey),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (item.descriptionKey != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _getSettingTitle(l10n, item.descriptionKey!),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  AnimatedToggleSwitch<String>.size(
                    current: value,
                    values: item.options!.map((o) => o.value).toList(),
                    iconOpacity: 0.8,
                    indicatorSize: const Size.square(40),
                    iconAnimationType: AnimationType.onHover,
                    style: ToggleStyle(
                      borderColor: Colors.transparent,
                      borderRadius: BorderRadius.circular(10.0),
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      indicatorColor: Theme.of(context).colorScheme.primary,
                    ),
                    customIconBuilder: (context, local, global) {
                      final iconData = _getToggleIcon(item.key, local.value);
                      return Center(
                        child: Icon(
                          iconData,
                          size: 20,
                          color: Color.lerp(
                            Theme.of(context).colorScheme.onSurfaceVariant,
                            Theme.of(context).colorScheme.onPrimary,
                            local.animationValue,
                          ),
                        ),
                      );
                    },
                    onChanged: (newValue) {
                      _settingsService.setValue(item.key, newValue);
                    },
                    height: 40,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSwitchSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<bool>(
          item.key,
          item.defaultValue as bool,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: SwitchListTile(
              secondary: item.icon != null ? Icon(item.icon) : null,
              title: Text(_getSettingTitle(l10n, item.titleKey)),
              subtitle: item.descriptionKey != null
                  ? Text(_getSettingTitle(l10n, item.descriptionKey!))
                  : null,
              value: value,
              onChanged: (newValue) {
                _settingsService.setValue(item.key, newValue);
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        if (item.subItems != null && item.options!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: item.icon != null ? Icon(item.icon) : null,
                    title: Text(_getSettingTitle(l10n, item.titleKey)),
                    subtitle: item.descriptionKey != null
                        ? Text(_getSettingTitle(l10n, item.descriptionKey!))
                        : null,
                  ),
                  const Divider(height: 1),
                  ...item.subItems!.map((subItem) {
                    return _buildSubSwitchSetting(context, l10n, subItem);
                  }),
                ],
              ),
            ),
          );
        }
        final value = _settingsService.getValue<String>(
          item.key,
          item.defaultValue as String,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  leading: item.icon != null ? Icon(item.icon) : null,
                  title: Text(_getSettingTitle(l10n, item.titleKey)),
                  subtitle: item.descriptionKey != null
                      ? Text(_getSettingTitle(l10n, item.descriptionKey!))
                      : null,
                  trailing: DropdownButton<String>(
                    value: value,
                    items: item.options!.map((option) {
                      return DropdownMenuItem(
                        value: option.value,
                        child: Text(_getSettingTitle(l10n, option.labelKey)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        _settingsService.setValue(item.key, newValue);
                      }
                    },
                  ),
                ),
              ),
              if (item.subItems != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                  child: Column(
                    children: item.subItems!
                        .map((subItem) => _buildSettingItem(context, subItem))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildSubSwitchSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<bool>(
          item.key,
          item.defaultValue as bool,
        );

        return SwitchListTile(
          secondary: item.icon != null ? Icon(item.icon) : null,
          title: Text(_getSettingTitle(l10n, item.titleKey)),
          subtitle: item.descriptionKey != null
              ? Text(_getSettingTitle(l10n, item.descriptionKey!))
              : null,
          value: value,
          onChanged: (newValue) {
            _settingsService.setValue(item.key, newValue);
          },
        );
      },
    );
  }

  Widget _buildRadioSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<String>(
          item.key,
          item.defaultValue as String,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (item.icon != null) ...[
                            Icon(item.icon),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getSettingTitle(l10n, item.titleKey),
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (item.descriptionKey != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _getSettingTitle(l10n, item.descriptionKey!),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ...item.options!.map((option) {
                  return RadioListTile<String>(
                    title: Text(_getSettingTitle(l10n, option.labelKey)),
                    value: option.value,
                    // ignore: deprecated_member_use
                    groupValue: value,
                    // ignore: deprecated_member_use
                    onChanged: (newValue) {
                      if (newValue != null) {
                        _settingsService.setValue(item.key, newValue);
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationSetting(
      BuildContext context, AppLocalizations l10n, SettingItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        child: ListTile(
          leading: item.icon != null ? Icon(item.icon) : null,
          title: Text(_getSettingTitle(l10n, item.titleKey)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // 没写完
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.settingsEmpty,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  String _getCategoryTitle(AppLocalizations l10n, String key) {
    switch (key) {
      case 'settingsCategoryAppearance':
        return l10n.settingsCategoryAppearance;
      case 'settingsCategoryNotifications':
        return l10n.settingsCategoryNotifications;
      case 'settingsCategoryAbout':
        return l10n.settingsCategoryAbout;
      default:
        return key;
    }
  }

  String _getSettingTitle(AppLocalizations l10n, String key) {
    switch (key) {
      // Appearance
      case 'settingsLanguageTitle':
        return l10n.settingsLanguageTitle;
      case 'settingsLanguageDesc':
        return l10n.settingsLanguageDesc;
      case 'settingsLanguageSystem':
        return l10n.settingsLanguageSystem;
      case 'settingsLanguageZh':
        return l10n.settingsLanguageZh;
      case 'settingsLanguageEn':
        return l10n.settingsLanguageEn;
      case 'settingsThemeTitle':
        return l10n.settingsThemeTitle;
      case 'settingsThemeDesc':
        return l10n.settingsThemeDesc;
      case 'settingsThemeSystem':
        return l10n.settingsThemeSystem;
      case 'settingsThemeLight':
        return l10n.settingsThemeLight;
      case 'settingsThemeDark':
        return l10n.settingsThemeDark;
      case 'settingsThemeColorTitle':
        return l10n.settingsThemeColorTitle;
      case 'settingsThemeColorDesc':
        return l10n.settingsThemeColorDesc;
      case 'settingsColorDefault':
        return l10n.settingsColorDefault;
      case 'settingsColorRed':
        return l10n.settingsColorRed;
      case 'settingsColorGreen':
        return l10n.settingsColorGreen;
      case 'settingsColorPurple':
        return l10n.settingsColorPurple;
      case 'settingsColorOrange':
        return l10n.settingsColorOrange;
      case 'settingsSendModeTitle':
        return l10n.settingsSendModeTitle;
      case 'settingsSendModeDesc':
        return l10n.settingsSendModeDesc;
      case 'settingsSendModeEnter':
        return l10n.settingsSendModeEnter;
      case 'settingsSendModeCtrlEnter':
        return l10n.settingsSendModeCtrlEnter;
      // Notifications
      case 'settingsSystemNotificationsTitle':
        return l10n.settingsSystemNotificationsTitle;
      case 'settingsSystemNotificationsDesc':
        return l10n.settingsSystemNotificationsDesc;
      case 'settingsInAppNotificationsTitle':
        return l10n.settingsInAppNotificationsTitle;
      case 'settingsInAppNotificationsDesc':
        return l10n.settingsInAppNotificationsDesc;
      case 'settingsNotificationSoundTitle':
        return l10n.settingsNotificationSoundTitle;
      case 'settingsNotificationSoundDesc':
        return l10n.settingsNotificationSoundDesc;
      case 'settingsChatNotificationsTitle':
        return l10n.settingsChatNotificationsTitle;
      case 'settingsChatNotificationsDesc':
        return l10n.settingsChatNotificationsDesc;
      case 'settingsPrivateChatTitle':
        return l10n.settingsPrivateChatTitle;
      case 'settingsGroupChatTitle':
        return l10n.settingsGroupChatTitle;
      // About
      case 'settingsAboutAppTitle':
        return l10n.settingsAboutAppTitle;
      default:
        return key;
    }
  }

  IconData _getToggleIcon(String settingKey, String value) {
    if (settingKey == 'language') {
      switch (value) {
        case 'system':
          return Icons.settings_suggest;
        case 'zh':
          return Icons.translate;
        case 'en':
          return Icons.abc;
        default:
          return Icons.language;
      }
    } else if (settingKey == 'theme') {
      switch (value) {
        case 'system':
          return Icons.brightness_auto;
        case 'light':
          return Icons.light_mode;
        case 'dark':
          return Icons.dark_mode;
        default:
          return Icons.brightness_medium;
      }
    }
    return Icons.circle;
  }
}
