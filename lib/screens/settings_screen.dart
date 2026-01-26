import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.settingsTitle),
      ),
      body: Center(
        child: Text(AppLocalizations.of(context)!.settingsEmpty),
      ),
    );
  }
}
