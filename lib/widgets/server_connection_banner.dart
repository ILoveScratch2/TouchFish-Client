import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/server_connection_status_service.dart';

class ServerConnectionBanner extends StatelessWidget {
  final ServerConnectionBannerPhase phase;
  final VoidCallback? onTap;

  const ServerConnectionBanner({
    super.key,
    required this.phase,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (phase) {
      ServerConnectionBannerPhase.connecting =>
        l10n.connectionBannerConnecting,
      ServerConnectionBannerPhase.disconnected =>
        l10n.connectionBannerDisconnected,
      ServerConnectionBannerPhase.connected =>
        l10n.connectionBannerConnected,
      ServerConnectionBannerPhase.hidden => '',
    };

    final backgroundColor = switch (phase) {
      ServerConnectionBannerPhase.connecting => colorScheme.primaryContainer,
      ServerConnectionBannerPhase.disconnected => colorScheme.errorContainer,
      ServerConnectionBannerPhase.connected => colorScheme.tertiaryContainer,
      ServerConnectionBannerPhase.hidden => colorScheme.surfaceContainerHigh,
    };

    final foregroundColor = switch (phase) {
      ServerConnectionBannerPhase.connecting =>
        colorScheme.onPrimaryContainer,
      ServerConnectionBannerPhase.disconnected => colorScheme.onErrorContainer,
      ServerConnectionBannerPhase.connected => colorScheme.onTertiaryContainer,
      ServerConnectionBannerPhase.hidden => colorScheme.onSurface,
    };

    Widget leading;
    switch (phase) {
      case ServerConnectionBannerPhase.connecting:
        leading = SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
          ),
        );
        break;
      case ServerConnectionBannerPhase.disconnected:
        leading = Icon(Icons.cloud_off_rounded, color: foregroundColor);
        break;
      case ServerConnectionBannerPhase.connected:
        leading = Icon(Icons.cloud_done_rounded, color: foregroundColor);
        break;
      case ServerConnectionBannerPhase.hidden:
        leading = const SizedBox.shrink();
        break;
    }

    final canRetry = phase == ServerConnectionBannerPhase.disconnected;

    return Material(
      color: backgroundColor,
      elevation: 8,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: canRetry ? onTap : null,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 10),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (canRetry) ...[
                const SizedBox(width: 8),
                Text(
                  l10n.connectionBannerTapToRetry,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: foregroundColor.withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}