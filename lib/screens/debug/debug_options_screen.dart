import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../l10n/app_localizations.dart';
import '../../widgets/app_alert_dialog.dart';
import './api_test_screen.dart';
import './markdown_test_screen.dart';
import './talker_log_screen.dart';

class DebugOptionsScreen extends StatelessWidget {
  const DebugOptionsScreen({super.key});

  Future<void> _showInfoDialogPreview(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final materialL10n = MaterialLocalizations.of(context);
    final result = await showTouchFishInfoDialog<String>(
      context,
      title: l10n.debugInfoDialogDemoTitle,
      message: l10n.debugInfoDialogDemoMessage,
      actions: [
        TouchFishDialogAction<String>(
          label: materialL10n.cancelButtonLabel,
          result: materialL10n.cancelButtonLabel,
        ),
        TouchFishDialogAction<String>(
          label: l10n.settingsTitle,
          result: l10n.settingsTitle,
          isPrimary: true,
        ),
      ],
    );

    if (!context.mounted || result == null) return;
    _showDialogSelectionSnackBar(context, result);
  }

  Future<void> _showErrorDialogPreview(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showTouchFishErrorDialog<String>(
      context,
      title: l10n.debugErrorDialogDemoTitle,
      message: l10n.debugErrorDialogDemoMessage,
      barrierDismissible: false,
      actions: [
        TouchFishDialogAction<String>(label: l10n.cancel, result: l10n.cancel),
        TouchFishDialogAction<String>(
          label: l10n.settingsTitle,
          result: l10n.settingsTitle,
        ),
        TouchFishDialogAction<String>(
          label: l10n.retry,
          result: l10n.retry,
          isPrimary: true,
        ),
      ],
    );

    if (!context.mounted || result == null) return;
    _showDialogSelectionSnackBar(context, result);
  }

  void _showDialogSelectionSnackBar(BuildContext context, String action) {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.debugDialogSelectedAction(action))),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountDebugOptions)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(Symbols.terminal, color: colorScheme.primary),
            trailing: const Icon(Symbols.chevron_right),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(l10n.debugLogs),
            subtitle: Text(l10n.debugLogsDescription),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TalkerLogScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.text_snippet_outlined, color: colorScheme.primary),
            trailing: const Icon(Symbols.chevron_right),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(l10n.debugMarkdownTester),
            subtitle: Text(l10n.debugMarkdownTesterDescription),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const MarkdownTestScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.api_rounded, color: colorScheme.primary),
            trailing: const Icon(Symbols.chevron_right),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(l10n.debugApiTester),
            subtitle: Text(l10n.debugApiTesterDescription),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ApiTestScreen()),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Symbols.info_rounded, color: colorScheme.primary),
            trailing: const Icon(Symbols.chevron_right),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(l10n.debugCustomInfoDialog),
            subtitle: Text(l10n.debugCustomInfoDialogDescription),
            onTap: () => _showInfoDialogPreview(context),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Symbols.error, color: colorScheme.error),
            trailing: const Icon(Symbols.chevron_right),
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            title: Text(l10n.debugCustomErrorDialog),
            subtitle: Text(l10n.debugCustomErrorDialogDescription),
            onTap: () => _showErrorDialogPreview(context),
          ),
          const Divider(height: 1),
        ],
      ),
    );
  }
}
