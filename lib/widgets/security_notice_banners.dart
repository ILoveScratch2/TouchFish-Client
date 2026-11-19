import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/secure_credentials.dart';
import '../services/security_notice_service.dart';
import '../theme/tokens.dart';

/// Web 端处于非安全上下文（非 HTTPS）
class InsecureStorageBanner extends StatelessWidget {
  const InsecureStorageBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        SecureCredentials.instance,
        SecurityNoticeService.instance,
      ]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final visible =
            SecureCredentials.instance.isInsecureWebContext &&
            !SecurityNoticeService.instance.insecureContextDismissed;
        return _SecurityNoticeSwitcher(
          visible: visible,
          bannerId: 'insecure-storage-banner',
          icon: Icons.lock_open_rounded,
          title: l10n.insecureStorageBannerTitle,
          message: l10n.insecureStorageBannerMessage,
          dismissLabel: l10n.insecureStorageBannerDismiss,
          onDismiss: () {
            unawaited(SecurityNoticeService.instance.dismissInsecureContext());
          },
        );
      },
    );
  }
}

/// 已启用 HTTPS 但服务器无法建立加密连接
class HttpsFallbackBanner extends StatelessWidget {
  const HttpsFallbackBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SecurityNoticeService.instance,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context)!;
        final visible =
            SecurityNoticeService.instance.httpsFallbackActive &&
            !SecurityNoticeService.instance.httpsFallbackDismissed;
        return _SecurityNoticeSwitcher(
          visible: visible,
          bannerId: 'https-fallback-banner',
          icon: Icons.no_encryption_rounded,
          title: l10n.httpsFallbackBannerTitle,
          message: l10n.httpsFallbackBannerMessage,
          dismissLabel: l10n.httpsFallbackBannerDismiss,
          onDismiss: () {
            unawaited(SecurityNoticeService.instance.dismissHttpsFallback());
          },
        );
      },
    );
  }
}

class _SecurityNoticeSwitcher extends StatelessWidget {
  const _SecurityNoticeSwitcher({
    required this.visible,
    required this.bannerId,
    required this.icon,
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final bool visible;
  final String bannerId;
  final IconData icon;
  final String title;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: TFMotion.base,
      switchInCurve: TFMotion.standard,
      switchOutCurve: TFMotion.exit,
      child: visible
          ? _NoticeCard(
              key: ValueKey(bannerId),
              icon: icon,
              title: title,
              message: message,
              dismissLabel: dismissLabel,
              onDismiss: onDismiss,
            )
          : SizedBox.shrink(key: ValueKey('$bannerId-hidden')),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.dismissLabel,
    required this.onDismiss,
  });

  final IconData icon;
  final String title;
  final String message;
  final String dismissLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onErrorContainer;
    final textTheme = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.only(top: TFSpace.sm),
        child: Material(
          color: colorScheme.errorContainer,
          elevation: 6,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, TFSpace.md, 6, TFSpace.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(icon, color: foreground, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: TFSpace.xs),
                      Text(
                        message,
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
                  // 不能用 tooltip
                  icon: Semantics(
                    label: dismissLabel,
                    child: const Icon(Icons.close_rounded, size: 18),
                  ),
                  color: foreground,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
