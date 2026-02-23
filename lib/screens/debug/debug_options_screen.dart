import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../l10n/app_localizations.dart';
import './talker_log_screen.dart';

class DebugOptionsScreen extends StatelessWidget {
  const DebugOptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountDebugOptions),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: Icon(
              Symbols.terminal,
              color: colorScheme.primary,
            ),
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
        ],
      ),
    );
  }
}
