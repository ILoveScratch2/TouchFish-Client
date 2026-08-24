import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'dart:io';
import 'package:animated_toggle_switch/animated_toggle_switch.dart';
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:window_manager/window_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import '../l10n/app_localizations.dart';
import '../models/settings_model.dart';
import '../models/settings_service.dart';
import '../services/font_loader_service.dart';
import '../services/draft_service.dart';
import '../services/snackbar_service.dart';
import '../utils/talker.dart';
import '../widgets/app_alert_dialog.dart';
import '../widgets/local_storage_settings.dart';
import '../services/media_proxy_service.dart';
import '../services/ip_override_service.dart';
import '../services/server_connection_status_service.dart';
import '../services/lock_service.dart';
import 'connectivity_self_check_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  static const String _customFontSentinel = '__custom__';

  final _settingsService = SettingsService.instance;
  SettingCategory? _selectedCategory;
  late AnimationController _categoryAnimationController;
  final TextEditingController _customFontController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settingsService.init();
    _selectedCategory = SettingsData.categories.first.category;
    _customFontController.text = _settingsService.getValue<String>(
      'customFontName',
      '',
    );

    _categoryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _customFontController.dispose();
    _categoryAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 600;

        return Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.settingsTitle),
          ),
          body: isWideScreen
              ? _buildWideLayout(context)
              : _buildNarrowLayout(context),
        );
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
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Material(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<SettingCategory>(
                  isExpanded: true,
                  value: _selectedCategory,
                  borderRadius: BorderRadius.circular(8),
                  items: SettingsData.categories
                      .map(
                        (category) => DropdownMenuItem(
                          value: category.category,
                          child: Row(
                            children: [
                              Icon(category.icon, size: 20),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _getCategoryTitle(l10n, category.titleKey),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedCategory = value);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.04, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_selectedCategory),
              child: _buildSettingsContent(context, _selectedCategory!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryList(
    BuildContext context, {
    required bool isWideLayout,
  }) {
    final l10n = AppLocalizations.of(context)!;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: SettingsData.categories.map((category) {
          final isSelected = _selectedCategory == category.category;
          final title = _getCategoryTitle(l10n, category.titleKey);

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              leading: Icon(category.icon),
              title: Text(title),
              selected: isWideLayout && isSelected,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primaryContainer.withValues(alpha: 0.55),
              onTap: () {
                setState(() {
                  _selectedCategory = category.category;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsContent(BuildContext context, SettingCategory category) {
    final l10n = AppLocalizations.of(context)!;
    final categoryData = SettingsData.categories.firstWhere(
      (c) => c.category == category,
    );
    // 通知分级仅 Android 平台可用；其他平台隐藏该设置项（保持原行为）。
    final isAndroid =
        !kIsWeb &&
        Platform.isAndroid &&
        defaultTargetPlatform == TargetPlatform.android;
    final visibleItems = categoryData.items.where((item) {
      if (item.key == 'notificationLevel') return isAndroid;
      if (item.key == 'lockscreenReply') return isAndroid;
      return true;
    }).toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: visibleItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Text(
              _getCategoryTitle(l10n, categoryData.titleKey),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          );
        }
        return _buildSettingItem(context, visibleItems[index - 1]);
      },
    );
  }

  Widget _buildSettingItem(BuildContext context, SettingItem item) {
    final l10n = AppLocalizations.of(context)!;

    switch (item.type) {
      case SettingType.switchSetting:
        return _buildSwitchSetting(context, l10n, item);
      case SettingType.dropdown:
        if (item.key == 'fontFamily') {
          return _buildFontDropdownSetting(context, l10n, item);
        }
        if (item.key == 'language' ||
            item.key == 'themeColor' ||
            item.key == 'explicitSyncCooldownSeconds' ||
            item.key == 'notificationLevel' ||
            item.key == 'ipOverrideMode') {
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
      case SettingType.slider:
        return _buildSliderSetting(context, l10n, item);
      case SettingType.customWidget:
        if (item.key == 'backgroundImage') {
          return _buildBackgroundImageSetting(context, l10n, item);
        }
        if (item.key == 'customTheme') {
          return ListenableBuilder(
            listenable: _settingsService,
            builder: (context, _) {
              final themeColor = _settingsService.getValue<String>(
                'themeColor',
                'blue',
              );
              if (themeColor != 'custom') {
                return const SizedBox.shrink();
              }
              return _buildCustomThemeSetting(context, l10n, item);
            },
          );
        }
        if (item.key == 'maxCachedRooms') {
          return _buildMaxCachedRoomsSetting(context);
        }
        if (item.key == 'automaticPreviewMaxMiB') {
          return _buildAutomaticPreviewSetting(context, l10n, item);
        }
        if (item.key == 'localStorage') {
          return const LocalStorageSettings();
        }
        if (item.key == 'ipOverrideDomains' || item.key == 'ipOverrideEntries') {
          return _buildIpOverrideEditor(context, l10n, item);
        }
        if (item.key == 'connectionStatus') {
          return _buildConnectionStatusPreview(context, l10n, item);
        }
        if (item.key == 'masterPassword') {
          return _buildMasterPasswordSetting(context, l10n);
        }
        if (item.key == 'biometricUnlock') {
          return _buildBiometricSetting(context, l10n);
        }
        if (item.key == 'lockNow') {
          return _buildLockNowSetting(context, l10n);
        }
        return const SizedBox.shrink();
    }
  }

  Widget _buildMasterPasswordSetting(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListenableBuilder(
      listenable: LockService.instance,
      builder: (context, _) {
        final enabled = LockService.instance.isEnabled;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.password),
                  title: Text(l10n.settingsSecurityMasterPasswordTitle),
                  subtitle: Text(l10n.settingsSecurityMasterPasswordDesc),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: Text(
                    enabled
                        ? l10n.settingsSecurityChangePassword
                        : l10n.settingsSecuritySetPassword,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _handlePasswordAction(context, change: enabled),
                ),
                if (enabled)
                  ListTile(
                    leading: const Icon(Icons.lock_open),
                    title: Text(l10n.settingsSecurityDisablePassword),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _handleDisablePassword(context),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handlePasswordAction(
    BuildContext context, {
    required bool change,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<_SecurityPasswordResult>(
      context: context,
      builder: (_) => _SecurityPasswordDialog(
        mode: change
            ? _SecurityPasswordDialogMode.change
            : _SecurityPasswordDialogMode.set,
        l10n: l10n,
      ),
    );
    if (result == null || !context.mounted) return;
    try {
      if (change) {
        await LockService.instance.changeMasterPassword(
          result.current!,
          result.newPassword!,
        );
        if (context.mounted) {
          TouchFishSnackbarService.instance.show(
            l10n.settingsSecurityPasswordChanged,
          );
        }
      } else {
        await LockService.instance.enableMasterPassword(result.newPassword!);
        if (context.mounted) {
          TouchFishSnackbarService.instance.show(
            l10n.settingsSecurityPasswordSet,
          );
        }
      }
    } on LockException {
      if (context.mounted) {
        TouchFishSnackbarService.instance.show(
          l10n.settingsSecurityPasswordIncorrect,
        );
      }
    }
  }

  Future<void> _handleDisablePassword(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showTouchFishErrorDialog<bool>(
      context,
      title: l10n.settingsSecurityDisablePassword,
      message: l10n.settingsSecurityDisablePasswordConfirm,
      icon: Icons.lock_open_rounded,
      actions: [
        TouchFishDialogAction<bool>(label: l10n.cancel, result: false),
        TouchFishDialogAction<bool>(
          label: l10n.settingsSecurityDisablePassword,
          result: true,
          isPrimary: true,
          isDestructive: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    final result = await showDialog<_SecurityPasswordResult>(
      context: context,
      builder: (_) => _SecurityPasswordDialog(
        mode: _SecurityPasswordDialogMode.disable,
        l10n: l10n,
      ),
    );
    if (result?.current == null || !context.mounted) return;
    try {
      await LockService.instance.disableMasterPassword(result!.current!);
      if (context.mounted) {
        TouchFishSnackbarService.instance.show(
          l10n.settingsSecurityPasswordDisabled,
        );
      }
    } on LockException {
      if (context.mounted) {
        TouchFishSnackbarService.instance.show(
          l10n.settingsSecurityPasswordIncorrect,
        );
      }
    }
  }

  Widget _buildBiometricSetting(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListenableBuilder(
      listenable: LockService.instance,
      builder: (context, _) {
        final service = LockService.instance;
        if (!service.isEnabled) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l10n.settingsSecurityBiometricTitle),
              subtitle: Text(l10n.settingsSecurityBiometricDesc),
              value: service.isBiometricEnabled,
              onChanged: (value) async {
                try {
                  if (value) {
                    await service.enableBiometric();
                  } else {
                    await service.disableBiometric();
                  }
                } on LockException catch (error) {
                  if (context.mounted) {
                    TouchFishSnackbarService.instance.show(
                      error.code == 'biometricUnavailable'
                          ? l10n.settingsSecurityBiometricUnavailable
                          : error.code == 'biometricCancelled'
                          ? l10n.settingsSecurityBiometricCancelled
                          : l10n.settingsSecurityBiometricFailed,
                    );
                  }
                } catch (_) {
                  if (context.mounted) {
                    TouchFishSnackbarService.instance.show(
                      l10n.settingsSecurityBiometricFailed,
                    );
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLockNowSetting(BuildContext context, AppLocalizations l10n) {
    return ListenableBuilder(
      listenable: LockService.instance,
      builder: (context, _) {
        final enabled = LockService.instance.isEnabled;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: ListTile(
              enabled: enabled,
              leading: const Icon(Icons.lock),
              title: Text(l10n.settingsSecurityLockNowTitle),
              subtitle: Text(l10n.settingsSecurityLockNowDesc),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => LockService.instance.lock(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomDropdownSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<String>(
          item.key,
          item.defaultValue as String,
        );

        final selectedLabel = _getSettingTitle(
          l10n,
          item.options!.firstWhere((o) => o.value == value).labelKey,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
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
                      items: item.options!
                          .map((o) => _getSettingTitle(l10n, o.labelKey))
                          .toList(),
                      decoration: CustomDropdownDecoration(
                        closedBorderRadius: BorderRadius.circular(8),
                        expandedBorderRadius: BorderRadius.circular(8),
                        closedFillColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        expandedFillColor: Theme.of(
                          context,
                        ).colorScheme.surface,
                      ),
                      onChanged: (newValue) async {
                        if (newValue != null) {
                          final option = item.options!.firstWhere(
                            (o) =>
                                _getSettingTitle(l10n, o.labelKey) == newValue,
                          );
                            await _settingsService.setValue(item.key, option.value);
                           if (item.key == 'ipOverrideMode') {
                             await IpOverrideService.instance.setMode(
                               IpOverrideMode.values.firstWhere(
                                 (mode) => mode.name == option.value,
                               ),
                             );
                           }
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

  Widget _buildFontDropdownSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    return FutureBuilder<List<String>>(
      future: FontLoaderService.instance.getSystemFonts(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
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
                    const SizedBox(
                      width: 140,
                      height: 40,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final fonts = snapshot.data!;

        return ListenableBuilder(
          listenable: _settingsService,
          builder: (context, _) {
            var value = _settingsService.getValue<String>(
              item.key,
              item.defaultValue as String,
            );
            if (value == 'harmonyos') {
              value = 'HarmonyOS Sans SC';
              _settingsService.setValue(item.key, value);
            } else if (value == 'system') {
              value = 'System Default';
              _settingsService.setValue(item.key, value);
            }
            if (!fonts.contains(value)) {
              value = 'System Default';
              _settingsService.setValue(item.key, value);
            }

            final isCustom = value == _customFontSentinel;
            final customFontName = _settingsService.getValue<String>(
              'customFontName',
              '',
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (item.descriptionKey != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _getSettingTitle(
                                        l10n,
                                        item.descriptionKey!,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 200,
                            child: CustomDropdown<String>(
                              hintText: '',
                              initialItem: value,
                              items: fonts,
                              overlayHeight: 320,
                              decoration: CustomDropdownDecoration(
                                closedBorderRadius: BorderRadius.circular(8),
                                expandedBorderRadius: BorderRadius.circular(8),
                                closedFillColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                expandedFillColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                                listItemStyle: const TextStyle(
                                  fontFamily: null, // Will be set per item
                                ),
                              ),
                              listItemBuilder:
                                  (context, item, isSelected, onItemSelect) {
                                    final displayName = _getFontDisplayName(
                                      l10n,
                                      item,
                                    );
                                    return GestureDetector(
                                      onTap: onItemSelect,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Theme.of(
                                                  context,
                                                ).colorScheme.primaryContainer
                                              : null,
                                        ),
                                        child: Text(
                                          displayName,
                                          style: TextStyle(
                                            fontFamily:
                                                (item == 'System Default' ||
                                                    item == _customFontSentinel)
                                                ? null
                                                : item,
                                            height: 1.4,
                                            color: isSelected
                                                ? Theme.of(context)
                                                      .colorScheme
                                                      .onPrimaryContainer
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                              headerBuilder: (context, selectedItem, enabled) {
                                final displayName = _getFontDisplayName(
                                  l10n,
                                  selectedItem,
                                );
                                return Text(
                                  displayName,
                                  style: TextStyle(
                                    fontFamily: selectedItem == 'System Default'
                                        ? null
                                        : (selectedItem ==
                                                  _customFontSentinel &&
                                              customFontName.isNotEmpty)
                                        ? customFontName
                                        : selectedItem,
                                  ),
                                );
                              },
                              onChanged: (newValue) async {
                                if (newValue != null) {
                                  if (newValue == _customFontSentinel) {
                                    final name = _settingsService
                                        .getValue<String>('customFontName', '');
                                    if (name.isNotEmpty) {
                                      await FontLoaderService.instance.loadFont(
                                        name,
                                      );
                                    }
                                  } else {
                                    await FontLoaderService.instance.loadFont(
                                      newValue,
                                    );
                                  }
                                  _settingsService.setValue(item.key, newValue);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isCustom) ...[
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.settingsCustomFontTitle,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              l10n.settingsCustomFontDesc,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _customFontController,
                              decoration: InputDecoration(
                                labelText: l10n.settingsCustomFontTitle,
                                hintText: l10n.settingsCustomFontHint,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                _settingsService.setValue(
                                  'customFontName',
                                  value,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildToggleSwitchSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
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
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
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
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
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
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
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
              onChanged: (newValue) async {
                await _settingsService.setValue(item.key, newValue);
                if (!newValue && item.key == 'mediaProxyEnabled') {
                  await MediaProxyService.instance.stop();
                }
                if (!newValue && item.key == 'saveChatDrafts') {
                  await DraftService.instance.clearDraftGroup('chat');
                } else if (!newValue && item.key == 'saveForumDrafts') {
                  await DraftService.instance.clearDraftGroup('forum');
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdownSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
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
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
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
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (item.descriptionKey != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _getSettingTitle(
                                        l10n,
                                        item.descriptionKey!,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
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
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        child: ListTile(
          leading: item.icon != null ? Icon(item.icon) : null,
          title: Text(_getSettingTitle(l10n, item.titleKey)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Navigate based on setting key
            if (item.key == 'aboutApp') {
              context.push('/about');
            } else if (item.key == 'connectivitySelfCheck') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConnectivitySelfCheckScreen()),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildMaxCachedRoomsSetting(BuildContext context) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final currentVal = _settingsService
            .getValue<int>('maxCachedRooms', 50)
            .toDouble();
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.memory),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '消息缓存房间数',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                '内存中保留的最大聊天房间数，超出后驱逐最久未使用的记录',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${currentVal.round()} 个',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: currentVal.clamp(10.0, 200.0),
                    min: 10,
                    max: 200,
                    divisions: 19,
                    label: '${currentVal.round()}',
                    onChanged: (v) async {
                      await _settingsService.setValue(
                        'maxCachedRooms',
                        v.round(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutomaticPreviewSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<int>(item.key, 10);
        final presets = <int>[0, 1, 10, 50, 100];
        final customLabel = l10n.settingsColorCustom;
        final selectedLabel = presets.contains(value)
            ? value == 0
                  ? l10n.settingsAutomaticPreviewDisabled
                  : l10n.settingsAutomaticPreviewSize(value)
            : l10n.settingsAutomaticPreviewSize(value);
        final items = [
          ...presets.map(
            (size) => size == 0
                ? l10n.settingsAutomaticPreviewDisabled
                : l10n.settingsAutomaticPreviewSize(size),
          ),
          customLabel,
        ];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(l10n.settingsAutomaticPreviewTitle),
              subtitle: Text(l10n.settingsAutomaticPreviewDesc),
              trailing: SizedBox(
                width: 150,
                child: CustomDropdown<String>(
                  hintText: selectedLabel,
                  initialItem: presets.contains(value) ? selectedLabel : null,
                  items: items,
                  decoration: CustomDropdownDecoration(
                    closedBorderRadius: BorderRadius.circular(8),
                    expandedBorderRadius: BorderRadius.circular(8),
                    closedFillColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    expandedFillColor: Theme.of(context).colorScheme.surface,
                  ),
                  onChanged: (selection) async {
                    if (selection == null) return;
                    if (selection == customLabel) {
                      await _showCustomPreviewLimit(context, value);
                      return;
                    }
                    final index = items.indexOf(selection);
                    if (index >= 0 && index < presets.length) {
                      await _settingsService.setValue(item.key, presets[index]);
                    }
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCustomPreviewLimit(
    BuildContext context,
    int currentValue,
  ) async {
    var rawValue = '$currentValue';
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.settingsColorCustom),
        content: TextFormField(
          initialValue: rawValue,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(suffixText: 'MiB'),
          onChanged: (value) => rawValue = value,
          onFieldSubmitted: (raw) {
            final parsed = int.tryParse(raw);
            if (parsed != null) Navigator.pop(dialogContext, parsed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(rawValue);
              if (parsed != null) Navigator.pop(dialogContext, parsed);
            },
            child: Text(AppLocalizations.of(context)!.confirm),
          ),
        ],
      ),
    );
    if (value != null) {
      await _settingsService.setValue('automaticPreviewMaxMiB', value);
    }
  }

  Widget _buildIpOverrideEditor(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    final service = IpOverrideService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        final value = item.key == 'ipOverrideDomains'
            ? service.domains.join(', ')
            : service.entries.map((entry) => '${entry.ip}${entry.port == null ? '' : ':${entry.port}'}').join(', ');
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(_getSettingTitle(l10n, item.titleKey)),
              subtitle: Text(value.isEmpty ? _getSettingTitle(l10n, item.descriptionKey!) : value),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                if (item.key == 'ipOverrideDomains') {
                  final controller = TextEditingController(text: service.domains.join('\n'));
                  final result = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(_getSettingTitle(l10n, item.titleKey)),
                      content: TextField(
                        controller: controller,
                        maxLines: 6,
                        decoration: InputDecoration(hintText: _getSettingTitle(l10n, item.descriptionKey!)),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(l10n.confirm)),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (result != null) {
                    await service.setDomains(result.split(RegExp(r'[\n,]')).map((v) => v.trim()).where((v) => v.isNotEmpty).toList());
                  }
                } else {
                  final controller = TextEditingController(text: service.entries.map((entry) => '${entry.ip}${entry.port == null ? '' : ':${entry.port}'}').join('\n'));
                  final result = await showDialog<String>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: Text(_getSettingTitle(l10n, item.titleKey)),
                      content: TextField(controller: controller, maxLines: 6, decoration: InputDecoration(hintText: '1.2.3.4:443')),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
                        FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text), child: Text(l10n.confirm)),
                      ],
                    ),
                  );
                  controller.dispose();
                  if (result != null) {
                    final entries = result.split(RegExp(r'[\n,]')).map((value) {
                      final parts = value.trim().split(':');
                      final port = parts.length > 1 ? int.tryParse(parts.last) : null;
                      return IpOverrideEntry(ip: parts.first, port: port);
                    }).where((entry) => entry.ip.isNotEmpty).toList();
                    await service.setEntries(entries);
                  }
                }
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatusPreview(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    return ListenableBuilder(
      listenable: Listenable.merge([IpOverrideService.instance, ServerConnectionStatusService.instance]),
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Card(
          child: ListTile(
            leading: const Icon(Icons.network_check),
            title: Text(_getSettingTitle(l10n, item.titleKey)),
            subtitle: Text('${ServerConnectionStatusService.instance.phase.name} · ${IpOverrideService.instance.mode.name} · ${IpOverrideService.instance.entries.isEmpty ? l10n.settingsIpOverrideNoEntry : IpOverrideService.instance.entries.first.ip}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ConnectivitySelfCheckScreen()),
            ),
          ),
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
      case 'settingsCategoryDrafts':
        return l10n.settingsCategoryDrafts;
      case 'settingsCategoryConnection':
        return l10n.settingsCategoryConnection;
      case 'settingsCategoryStorage':
        return l10n.settingsCategoryStorage;
      case 'settingsCategorySecurity':
        return l10n.settingsCategorySecurity;
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
      case 'settingsLanguageCc':
        return l10n.settingsLanguageCc;
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
      case 'settingsColorCustom':
        return l10n.settingsColorCustom;
      case 'settingsFontFamilyTitle':
        return l10n.settingsFontFamilyTitle;
      case 'settingsFontFamilyDesc':
        return l10n.settingsFontFamilyDesc;
      case 'settingsFontHarmonyOS':
        return l10n.settingsFontHarmonyOS;
      case 'settingsFontSystem':
        return l10n.settingsFontSystem;
      case 'settingsFontCustomOption':
        return l10n.settingsFontCustomOption;
      case 'settingsSendModeTitle':
        return l10n.settingsSendModeTitle;
      case 'settingsSendModeDesc':
        return l10n.settingsSendModeDesc;
      case 'settingsSendModeEnter':
        return l10n.settingsSendModeEnter;
      case 'settingsSendModeCtrlEnter':
        return l10n.settingsSendModeCtrlEnter;
      case 'settingsEnableMarkdownTitle':
        return l10n.settingsEnableMarkdownTitle;
      case 'settingsEnableMarkdownDesc':
        return l10n.settingsEnableMarkdownDesc;
      case 'settingsAutomaticPreviewTitle':
        return l10n.settingsAutomaticPreviewTitle;
      case 'settingsAutomaticPreviewDesc':
        return l10n.settingsAutomaticPreviewDesc;
      case 'settingsCardOpacityTitle':
        return l10n.settingsCardOpacityTitle;
      case 'settingsCardOpacityDesc':
        return l10n.settingsCardOpacityDesc;
      case 'settingsWindowOpacityTitle':
        return l10n.settingsWindowOpacityTitle;
      case 'settingsWindowOpacityDesc':
        return l10n.settingsWindowOpacityDesc;
      case 'settingsBackgroundImageTitle':
        return l10n.settingsBackgroundImageTitle;
      case 'settingsBackgroundImageDesc':
        return l10n.settingsBackgroundImageDesc;
      case 'settingsCustomThemeTitle':
        return l10n.settingsCustomThemeTitle;
      case 'settingsCustomThemeDesc':
        return l10n.settingsCustomThemeDesc;
      case 'settingsEnableAnimationsTitle':
        return l10n.settingsEnableAnimationsTitle;
      case 'settingsEnableAnimationsDesc':
        return l10n.settingsEnableAnimationsDesc;
      case 'settingsWeakNetworkTitle':
        return l10n.settingsWeakNetworkTitle;
      case 'settingsWeakNetworkDesc':
        return l10n.settingsWeakNetworkDesc;
      case 'settingsDataSavingTitle':
        return l10n.settingsDataSavingTitle;
      case 'settingsDataSavingDesc':
        return l10n.settingsDataSavingDesc;
      case 'settingsIpOverrideTitle':
        return l10n.settingsIpOverrideTitle;
      case 'settingsIpOverrideDesc':
        return l10n.settingsIpOverrideDesc;
      case 'settingsIpOverrideOff':
        return l10n.settingsIpOverrideOff;
      case 'settingsIpOverrideMixed':
        return l10n.settingsIpOverrideMixed;
      case 'settingsIpOverrideComplete':
        return l10n.settingsIpOverrideComplete;
      case 'settingsIpOverrideDomainsTitle':
        return l10n.settingsIpOverrideDomainsTitle;
      case 'settingsIpOverrideDomainsDesc':
        return l10n.settingsIpOverrideDomainsDesc;
      case 'settingsIpOverrideEntriesTitle':
        return l10n.settingsIpOverrideEntriesTitle;
      case 'settingsIpOverrideEntriesDesc':
        return l10n.settingsIpOverrideEntriesDesc;
      case 'settingsConnectionStatusTitle':
        return l10n.settingsConnectionStatusTitle;
      case 'settingsConnectionStatusDesc':
        return l10n.settingsConnectionStatusDesc;
      case 'settingsConnectivitySelfCheckTitle':
        return l10n.settingsConnectivitySelfCheckTitle;
      case 'settingsConnectivitySelfCheckDesc':
        return l10n.settingsConnectivitySelfCheckDesc;
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
      case 'settingsNotifyWithHaptic':
        return l10n.settingsNotifyWithHaptic;
      case 'settingsNotifyWithHapticDescription':
        return l10n.settingsNotifyWithHapticDescription;
      case 'settingsMediaProxy':
        return l10n.settingsMediaProxy;
      case 'settingsMediaProxyDescription':
        return kIsWeb
            ? l10n.settingsMediaProxyUnsupported
            : l10n.settingsMediaProxyDescription;
      case 'settingsForceExplicitSyncTitle':
        return l10n.settingsForceExplicitSyncTitle;
      case 'settingsForceExplicitSyncDesc':
        return l10n.settingsForceExplicitSyncDesc;
      case 'settingsExplicitSyncCooldownTitle':
        return l10n.settingsExplicitSyncCooldownTitle;
      case 'settingsExplicitSyncCooldownDesc':
        return l10n.settingsExplicitSyncCooldownDesc;
      case 'settingsSeconds10':
        return l10n.settingsSeconds10;
      case 'settingsSeconds30':
        return l10n.settingsSeconds30;
      case 'settingsSeconds60':
        return l10n.settingsSeconds60;
      case 'settingsSeconds120':
        return l10n.settingsSeconds120;
      case 'settingsSeconds300':
        return l10n.settingsSeconds300;
      case 'settingsChatNotificationsTitle':
        return l10n.settingsChatNotificationsTitle;
      case 'settingsChatNotificationsDesc':
        return l10n.settingsChatNotificationsDesc;
      case 'settingsPrivateChatTitle':
        return l10n.settingsPrivateChatTitle;
      case 'settingsGroupChatTitle':
        return l10n.settingsGroupChatTitle;
      case 'settingsNotificationLevelTitle':
        return l10n.settingsNotificationLevelTitle;
      case 'settingsNotificationLevelDesc':
        return l10n.settingsNotificationLevelDesc;
      case 'settingsNotificationLevelMinimal':
        return l10n.settingsNotificationLevelMinimal;
      case 'settingsNotificationLevelPerSender':
        return l10n.settingsNotificationLevelPerSender;
      case 'settingsNotificationLevelFull':
        return l10n.settingsNotificationLevelFull;
      case 'settingsSaveChatDraftsTitle':
        return l10n.settingsSaveChatDraftsTitle;
      case 'settingsSaveChatDraftsDesc':
        return l10n.settingsSaveChatDraftsDesc;
      case 'settingsSaveForumDraftsTitle':
        return l10n.settingsSaveForumDraftsTitle;
      case 'settingsSaveForumDraftsDesc':
        return l10n.settingsSaveForumDraftsDesc;
      // About
      case 'settingsAboutAppTitle':
        return l10n.settingsAboutAppTitle;
      // Security
      case 'settingsSecurityMasterPasswordTitle':
        return l10n.settingsSecurityMasterPasswordTitle;
      case 'settingsSecurityMasterPasswordDesc':
        return l10n.settingsSecurityMasterPasswordDesc;
      case 'settingsSecurityBiometricTitle':
        return l10n.settingsSecurityBiometricTitle;
      case 'settingsSecurityBiometricDesc':
        return l10n.settingsSecurityBiometricDesc;
      case 'settingsSecurityLockNowTitle':
        return l10n.settingsSecurityLockNowTitle;
      case 'settingsSecurityLockNowDesc':
        return l10n.settingsSecurityLockNowDesc;
      default:
        return key;
    }
  }

  String _getFontDisplayName(AppLocalizations l10n, String font) {
    if (font == 'System Default') {
      return l10n.settingsFontSystem;
    }
    if (font == 'HarmonyOS Sans SC') {
      return l10n.settingsFontHarmonyOS;
    }
    if (font == _customFontSentinel) {
      return l10n.settingsFontCustomOption;
    }
    return font;
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

  Widget _buildSliderSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    final isDesktopOnly = item.key == 'windowOpacity';
    final isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);
    if (isDesktopOnly && !isDesktop) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final value = _settingsService.getValue<double>(
          item.key,
          item.defaultValue as double,
        );

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Card(
            child: Padding(
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
                      Text(
                        '${(value * 100).round()}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: value,
                    min: item.key == 'windowOpacity' ? 0.1 : 0.0,
                    max: 1.0,
                    divisions: item.key == 'windowOpacity' ? 18 : 20,
                    label: '${(value * 100).round()}%',
                    onChanged: (newValue) async {
                      await _settingsService.setValue(item.key, newValue);
                      if (item.key == 'windowOpacity' && !kIsWeb) {
                        final isDesktop =
                            Platform.isWindows ||
                            Platform.isMacOS ||
                            Platform.isLinux;
                        if (isDesktop) {
                          await windowManager.setOpacity(newValue);
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackgroundImageSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

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
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.settingsBackgroundImageSelect),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final picker = ImagePicker();
                final image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  await _settingsService.setValue(
                    'backgroundImagePath',
                    image.path,
                  );
                  if (context.mounted) {
                    TouchFishSnackbarService.instance.show(
                      l10n.settingsBackgroundImageSelectSuccess,
                    );
                  }
                }
              },
            ),
            ListenableBuilder(
              listenable: _settingsService,
              builder: (context, _) {
                final imagePath = _settingsService.getValue<String>(
                  'backgroundImagePath',
                  '',
                );
                if (imagePath.isEmpty) return const SizedBox.shrink();

                return Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.delete_outline),
                      title: Text(l10n.settingsBackgroundImageClear),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await _settingsService.remove('backgroundImagePath');
                        if (context.mounted) {
                          TouchFishSnackbarService.instance.show(
                            l10n.settingsBackgroundImageClearSuccess,
                          );
                        }
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.color_lens),
                      title: Text(l10n.settingsBackgroundImageGenColor),
                      subtitle: Text(l10n.settingsBackgroundImageGenColorDesc),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await _generateThemeFromImage(context, imagePath);
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateThemeFromImage(
    BuildContext context,
    String imagePath,
  ) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Extract dominant colors using a simple algorithm
      // Resize image for faster processing
      final resized = img.copyResize(image, width: 100);

      // Count color frequencies
      final colorMap = <int, int>{};
      for (int y = 0; y < resized.height; y++) {
        for (int x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          // Quantize colors to reduce variations
          final quantizedR = (r ~/ 32) * 32;
          final quantizedG = (g ~/ 32) * 32;
          final quantizedB = (b ~/ 32) * 32;

          final colorValue =
              (0xFF << 24) |
              (quantizedR << 16) |
              (quantizedG << 8) |
              quantizedB;
          colorMap[colorValue] = (colorMap[colorValue] ?? 0) + 1;
        }
      }

      // Sort by frequency and get most common color
      final sortedColors = colorMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedColors.isNotEmpty) {
        final dominantColor = sortedColors.first.key;

        // Generate custom color scheme
        final customColors = <String, int>{'seedColor': dominantColor};

        // Try to find vibrant and muted colors from top colors
        if (sortedColors.length > 1) {
          customColors['primary'] = sortedColors[1].key;
        }
        if (sortedColors.length > 2) {
          customColors['secondary'] = sortedColors[2].key;
        }

        await _settingsService.setJsonValue('customColors', customColors);
        // Switch to custom theme to apply the generated colors
        await _settingsService.setValue('themeColor', 'custom');

        if (context.mounted) {
          TouchFishSnackbarService.instance.show(
            AppLocalizations.of(
              context,
            )!.settingsBackgroundImageGenColorSuccess,
          );
        }
      }
    } catch (e) {
      talker.error('Failed to generate theme from image', e);
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        TouchFishSnackbarService.instance.show(
          l10n.settingsBackgroundImageGenColorError(e.toString()),
        );
      }
    }
  }

  Widget _buildCustomThemeSetting(
    BuildContext context,
    AppLocalizations l10n,
    SettingItem item,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Card(
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            leading: item.icon != null ? Icon(item.icon) : null,
            title: Text(_getSettingTitle(l10n, item.titleKey)),
            subtitle: item.descriptionKey != null
                ? Text(_getSettingTitle(l10n, item.descriptionKey!))
                : null,
            children: [
              const Divider(height: 1),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemeSeedColor,
                'seedColor',
              ),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemePrimary,
                'primary',
              ),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemeSecondary,
                'secondary',
              ),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemeTertiary,
                'tertiary',
              ),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemeSurface,
                'surface',
              ),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemeBackground,
                'background',
              ),
              _buildColorPickerTile(
                context,
                l10n.settingsCustomThemeError,
                'error',
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: Text(l10n.settingsCustomThemeReset),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final confirmed = await showTouchFishInfoDialog<bool>(
                    context,
                    title: l10n.settingsCustomThemeReset,
                    message: l10n.settingsCustomThemeResetConfirm,
                    icon: Icons.refresh_rounded,
                    actions: [
                      TouchFishDialogAction<bool>(
                        label: l10n.cancel,
                        result: false,
                      ),
                      TouchFishDialogAction<bool>(
                        label: l10n.confirm,
                        result: true,
                        isPrimary: true,
                      ),
                    ],
                  );

                  if (confirmed == true) {
                    await _settingsService.remove('customColors');
                    if (context.mounted) {
                      TouchFishSnackbarService.instance.show(
                        l10n.settingsCustomThemeReset,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPickerTile(
    BuildContext context,
    String title,
    String colorKey,
  ) {
    return ListenableBuilder(
      listenable: _settingsService,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final customColors =
            _settingsService.getJsonValue('customColors') ?? {};
        final colorValue = customColors[colorKey] as int?;
        final color = colorValue != null ? Color(colorValue) : null;

        return ListTile(
          title: Text(title),
          trailing: GestureDetector(
            onTap: () async {
              Color selectedColor =
                  color ?? Theme.of(context).colorScheme.primary;

              final result = await showDialog<Color>(
                context: context,
                builder: (context) {
                  Color tempColor = selectedColor;
                  return AlertDialog(
                    title: Text(title),
                    content: SingleChildScrollView(
                      child: ColorPicker(
                        pickerColor: selectedColor,
                        onColorChanged: (c) => tempColor = c,
                        labelTypes: const [],
                        pickerAreaHeightPercent: 0.8,
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(l10n.cancel),
                      ),
                      if (color != null)
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop(null);
                          },
                          child: Text(l10n.clear),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(tempColor),
                        child: Text(l10n.confirm),
                      ),
                    ],
                  );
                },
              );

              if (result == null && color != null) {
                final newColors = Map<String, dynamic>.from(customColors);
                newColors.remove(colorKey);
                await _settingsService.setJsonValue(
                  'customColors',
                  newColors.isEmpty ? null : newColors,
                );
              } else if (result != null) {
                final newColors = Map<String, dynamic>.from(customColors);
                newColors[colorKey] = result.value;
                await _settingsService.setJsonValue('customColors', newColors);
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color ?? Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
              ),
              child: color == null
                  ? Icon(
                      Icons.add,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

enum _SecurityPasswordDialogMode { set, change, disable }

class _SecurityPasswordResult {
  const _SecurityPasswordResult({this.current, this.newPassword});
  final String? current;
  final String? newPassword;
}

class _SecurityPasswordDialog extends StatefulWidget {
  const _SecurityPasswordDialog({required this.mode, required this.l10n});

  final _SecurityPasswordDialogMode mode;
  final AppLocalizations l10n;

  @override
  State<_SecurityPasswordDialog> createState() => _SecurityPasswordDialogState();
}

class _SecurityPasswordDialogState extends State<_SecurityPasswordDialog> {
  final _current = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _newPassword.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.mode) {
      case _SecurityPasswordDialogMode.set:
        return widget.l10n.settingsSecuritySetPassword;
      case _SecurityPasswordDialogMode.change:
        return widget.l10n.settingsSecurityChangePassword;
      case _SecurityPasswordDialogMode.disable:
        return widget.l10n.settingsSecurityDisablePassword;
    }
  }

  String get _actionLabel {
    switch (widget.mode) {
      case _SecurityPasswordDialogMode.set:
        return widget.l10n.settingsSecuritySetPassword;
      case _SecurityPasswordDialogMode.change:
        return widget.l10n.settingsSecurityChangePassword;
      case _SecurityPasswordDialogMode.disable:
        return widget.l10n.settingsSecurityDisablePassword;
    }
  }

  void _submit() {
    final l10n = widget.l10n;
    if (widget.mode != _SecurityPasswordDialogMode.set &&
        _current.text.isEmpty) {
      setState(() => _error = l10n.lockPasswordRequired);
      return;
    }
    if (widget.mode != _SecurityPasswordDialogMode.disable) {
      if (_newPassword.text.length < 4) {
        setState(() => _error = l10n.settingsSecurityPasswordTooShort);
        return;
      }
      if (_newPassword.text != _confirm.text) {
        setState(() => _error = l10n.settingsSecurityPasswordMismatch);
        return;
      }
    }
    Navigator.pop(
      context,
      _SecurityPasswordResult(
        current: widget.mode == _SecurityPasswordDialogMode.set
            ? null
            : _current.text,
        newPassword: widget.mode == _SecurityPasswordDialogMode.disable
            ? null
            : _newPassword.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final fields = <Widget>[];
    if (widget.mode != _SecurityPasswordDialogMode.set) {
      fields.add(
        TextField(
          controller: _current,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.settingsSecurityCurrentPassword,
          ),
          onSubmitted: (_) => _submit(),
        ),
      );
    }
    if (widget.mode != _SecurityPasswordDialogMode.disable) {
      fields.add(
        TextField(
          controller: _newPassword,
          obscureText: true,
          autofocus: widget.mode == _SecurityPasswordDialogMode.set,
          decoration: InputDecoration(labelText: l10n.lockPasswordLabel),
          onSubmitted: (_) => _submit(),
        ),
      );
      fields.add(
        TextField(
          controller: _confirm,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.settingsSecurityConfirmPassword,
          ),
          onSubmitted: (_) => _submit(),
        ),
      );
    }

    return AlertDialog(
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final field in fields) ...[
            field,
            const SizedBox(height: 12),
          ],
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(_actionLabel)),
      ],
    );
  }
}
