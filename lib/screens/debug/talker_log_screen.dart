import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../../utils/talker.dart';
import '../../l10n/app_localizations.dart';

class TalkerLogScreen extends StatelessWidget {
  const TalkerLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return TalkerScreen(
      talker: talker,
      theme: TalkerScreenTheme(
        backgroundColor: Theme.of(context).colorScheme.surface,
        textColor: Theme.of(context).colorScheme.onSurface,
        cardColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      appBarTitle: l10n.debugLogs,
    );
  }
}
