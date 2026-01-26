import 'package:flutter/material.dart';
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
          child: ListenableBuilder(
            listenable: _settingsService,
            builder: (context, _) {
              final enableAnimations = _settingsService.getValue<bool>(
                'enableAnimations',
                true,
              );
              
              return AnimatedSwitcher(
                duration: Duration(milliseconds: enableAnimations ? 300 : 0),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  if (!enableAnimations) return child;
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
                    ? _buildEmptyState(context)
                    : _buildSettingsContent(context, _selectedCategory!),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final enableAnimations = _settingsService.getValue<bool>(
          'enableAnimations',
          true,
        );
        
        return AnimatedSwitcher(
          duration: Duration(milliseconds: enableAnimations ? 300 : 0),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            if (!enableAnimations) return child;
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
          child: _selectedCategory == null
              ? _buildCategoryList(context, isWideLayout: false)
              : _buildSettingsContent(context, _selectedCategory!),
        );
      },
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
        return _buildDropdownSetting(context, l10n, item);
      case SettingType.radio:
        return _buildRadioSetting(context, l10n, item);
      case SettingType.navigation:
        return _buildNavigationSetting(context, l10n, item);
    }
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
      case 'settingsAnimationsTitle':
        return l10n.settingsAnimationsTitle;
      case 'settingsAnimationsDesc':
        return l10n.settingsAnimationsDesc;
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
}
