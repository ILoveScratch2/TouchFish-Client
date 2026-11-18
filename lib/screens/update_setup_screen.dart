import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../constants/app_constants.dart';
import '../l10n/app_localizations.dart';
import '../routes/app_routes.dart';
import '../services/update_preferences.dart';
import '../theme/tokens.dart';
import '../utils/talker.dart';

class UpdateSetupScreen extends StatefulWidget {
  const UpdateSetupScreen({super.key});

  @override
  State<UpdateSetupScreen> createState() => _UpdateSetupScreenState();
}

class _UpdateSetupScreenState extends State<UpdateSetupScreen> {
  bool _autoCheck = UpdatePreferences.autoCheckEnabled;
  bool _submitting = false;
  String _currentVersion = AppConstants.defaultVersion;

  /// Web 端没有更新
  bool get _unsupported => !UpdatePreferences.isSupported;

  @override
  void initState() {
    super.initState();
    if (_unsupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(UpdatePreferences.markSetupHandled());
        _leave();
      });
      return;
    }
    unawaited(_loadVersion());
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _currentVersion = info.version);
    } catch (error) {
      talker.warning('Failed to read app version on update setup: $error');
    }
  }

  Future<void> _finish({bool skip = false}) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    if (!skip) {
      await UpdatePreferences.setAutoCheckEnabled(_autoCheck);
    }
    await UpdatePreferences.markSetupHandled();
    if (!mounted) return;
    _leave();
  }

  void _leave() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_unsupported) return const Scaffold(body: SizedBox.shrink());

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.updateSetupTitle),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => _finish(skip: true),
            child: Text(l10n.updateSetupSkip),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      TFSpace.page,
                      TFSpace.lg,
                      TFSpace.page,
                      TFSpace.lg,
                    ),
                    children: [
                      Icon(
                        Icons.system_update_alt_rounded,
                        size: 56,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: TFSpace.lg),
                      Text(
                        l10n.updateSetupHeadline,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: TFSpace.md),
                      Text(
                        l10n.updateSetupIntro,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: TFSpace.xl),
                      Card(
                        margin: EdgeInsets.zero,
                        child: SwitchListTile(
                          secondary: const Icon(Icons.autorenew_rounded),
                          title: Text(l10n.updateAutoCheckTitle),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: TFSpace.xxs),
                            child: Text(l10n.updateAutoCheckDescription),
                          ),
                          value: _autoCheck,
                          onChanged: _submitting
                              ? null
                              : (value) async {
                                  setState(() => _autoCheck = value);
                                  await UpdatePreferences.setAutoCheckEnabled(
                                    value,
                                  );
                                },
                        ),
                      ),
                      const SizedBox(height: TFSpace.md),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: TFSpace.lg,
                        ),
                        leading: const Icon(Icons.info_outline_rounded),
                        title: Text(l10n.updateSetupCurrentVersion),
                        trailing: Text(
                          _currentVersion,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(height: TFSpace.sm),
                      Text(
                        l10n.updateSetupFootNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TFSpace.page,
                    TFSpace.sm,
                    TFSpace.page,
                    TFSpace.xl,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _finish,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(l10n.updateSetupContinue),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
