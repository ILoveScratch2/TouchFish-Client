import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/secure_credentials.dart';

/// Web 端处于非安全上下文（非 HTTPS）降级
class InsecureStorageBanner extends StatefulWidget {
  const InsecureStorageBanner({super.key});

  @override
  State<InsecureStorageBanner> createState() => _InsecureStorageBannerState();
}

class _InsecureStorageBannerState extends State<InsecureStorageBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SecureCredentials.instance,
      builder: (context, _) {
        final visible =
            SecureCredentials.instance.isInsecureWebContext && !_dismissed;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: visible
              ? _BannerCard(
                  key: const ValueKey('insecure-storage-banner'),
                  onDismiss: () => setState(() => _dismissed = true),
                )
              : const SizedBox.shrink(key: ValueKey('insecure-storage-hidden')),
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onErrorContainer;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Material(
          color: colorScheme.errorContainer,
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.lock_open_rounded, color: foreground, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.insecureStorageBannerTitle,
                        style: textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.insecureStorageBannerMessage,
                        style: textTheme.bodySmall?.copyWith(
                          color: foreground.withValues(alpha: 0.88),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: foreground,
                  visualDensity: VisualDensity.compact,
                  tooltip: l10n.insecureStorageBannerDismiss,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
