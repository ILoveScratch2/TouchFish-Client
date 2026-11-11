import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import 'loading_indicator.dart';


class LoadMoreFooter extends StatelessWidget {
  final bool loading;
  final bool hasMore;
  final bool showNoMore;

  const LoadMoreFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    this.showNoMore = true,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const InlineLoadingIndicator();
    if (hasMore || !showNoMore) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          AppLocalizations.of(context)!.listNoMore,
          style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
