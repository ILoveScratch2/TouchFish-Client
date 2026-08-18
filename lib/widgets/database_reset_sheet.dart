import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'hold_to_confirm_button.dart';

class DatabaseResetSheet extends StatelessWidget {
  final int rooms;
  final int messages;
  final String size;
  final VoidCallback onConfirmed;
  const DatabaseResetSheet({super.key, required this.rooms, required this.messages, required this.size, required this.onConfirmed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.settingsResetLocalMessages, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text('${l10n.settingsResetStatsRooms}: $rooms'),
          Text('${l10n.settingsResetStatsMessages}: $messages'),
          Text('${l10n.settingsResetStatsSize}: $size'),
          const SizedBox(height: 20),
          HoldToConfirmButton(label: l10n.settingsResetLocalMessages, onConfirmed: onConfirmed),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel))),
        ]),
      ),
    );
  }
}
