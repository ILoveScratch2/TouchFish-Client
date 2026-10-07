import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// 可疑登录告警对话框
class SuspiciousLoginAlert extends StatelessWidget {
  const SuspiciousLoginAlert({
    super.key,
    required this.reason,
    required this.deviceName,
    required this.location,
    required this.timestamp,
    this.onDismiss,
    this.onReviewSessions,
  });

  final String reason;
  final String deviceName;
  final String location;
  final DateTime timestamp;
  final VoidCallback? onDismiss;
  final VoidCallback? onReviewSessions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      icon: Icon(
        Icons.warning_amber_rounded,
        size: 48,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(l10n.suspiciousLoginTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.suspiciousLoginMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          _InfoRow(
            icon: Icons.devices_other,
            label: l10n.suspiciousLoginDevice,
            value: deviceName,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: l10n.suspiciousLoginLocation,
            value: location,
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.access_time,
            label: l10n.suspiciousLoginTime,
            value: _formatTimestamp(timestamp),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: onDismiss ?? () => Navigator.of(context).pop(),
          child: Text(l10n.suspiciousLoginDismiss),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onReviewSessions?.call();
          },
          icon: const Icon(Icons.security),
          label: Text(l10n.suspiciousLoginReviewSessions),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return '刚刚';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟前';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}小时前';
    } else {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodySmall,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 可疑登录通知服务
class SuspiciousLoginNotificationService {
  SuspiciousLoginNotificationService._();
  static final instance = SuspiciousLoginNotificationService._();

  /// 显示可疑登录告警
  void showAlert(
    BuildContext context, {
    required String reason,
    required String deviceName,
    required String location,
    required DateTime timestamp,
    VoidCallback? onReviewSessions,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SuspiciousLoginAlert(
        reason: reason,
        deviceName: deviceName,
        location: location,
        timestamp: timestamp,
        onReviewSessions: onReviewSessions,
      ),
    );
  }
}
