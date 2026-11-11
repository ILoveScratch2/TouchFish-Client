import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/support_ticket.dart';

/// 工单的文案 / 配色 / 图标 / 标签

String ticketPriorityLabel(AppLocalizations l10n, TicketPriority priority) {
  switch (priority) {
    case TicketPriority.low:
      return l10n.ticketPriorityLow;
    case TicketPriority.normal:
      return l10n.ticketPriorityNormal;
    case TicketPriority.high:
      return l10n.ticketPriorityHigh;
    case TicketPriority.urgent:
      return l10n.ticketPriorityUrgent;
  }
}

Color ticketPriorityColor(ColorScheme scheme, TicketPriority priority) {
  switch (priority) {
    case TicketPriority.low:
      return scheme.outline;
    case TicketPriority.normal:
      return scheme.primary;
    case TicketPriority.high:
      return Colors.orange;
    case TicketPriority.urgent:
      return scheme.error;
  }
}

String ticketStatusLabel(AppLocalizations l10n, TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return l10n.ticketStatusOpen;
    case TicketStatus.processing:
      return l10n.ticketStatusProcessing;
    case TicketStatus.resolved:
      return l10n.ticketStatusResolved;
    case TicketStatus.rejected:
      return l10n.ticketStatusRejected;
  }
}

Color ticketStatusColor(ColorScheme scheme, TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return Colors.orange;
    case TicketStatus.processing:
      return scheme.primary;
    case TicketStatus.resolved:
      return Colors.green;
    case TicketStatus.rejected:
      return scheme.outline;
  }
}

IconData ticketStatusIcon(TicketStatus status) {
  switch (status) {
    case TicketStatus.open:
      return Icons.play_arrow;
    case TicketStatus.processing:
      return Icons.pending;
    case TicketStatus.resolved:
      return Icons.check_circle;
    case TicketStatus.rejected:
      return Icons.cancel;
  }
}

String ticketTypeLabel(AppLocalizations l10n, TicketType type) {
  switch (type) {
    case TicketType.report:
      return l10n.ticketReport;
    case TicketType.consult:
      return l10n.ticketConsult;
    case TicketType.appeal:
      return l10n.ticketAppeal;
  }
}

Color ticketTypeColor(ColorScheme scheme, TicketType type) {
  switch (type) {
    case TicketType.report:
      return scheme.error;
    case TicketType.consult:
      return scheme.primary;
    case TicketType.appeal:
      return Colors.orange;
  }
}

IconData ticketTypeIcon(TicketType type) {
  switch (type) {
    case TicketType.report:
      return Icons.flag;
    case TicketType.consult:
      return Icons.help_outline;
    case TicketType.appeal:
      return Icons.gavel;
  }
}

/// 相关对象类型可读名
String? ticketTargetTypeLabel(AppLocalizations l10n, String? targetType) {
  switch (targetType) {
    case 'post':
      return l10n.ticketTargetPost;
    case 'comment':
      return l10n.ticketTargetComment;
    case 'user':
      return l10n.ticketTargetUser;
    case 'forum':
      return l10n.ticketTargetForum;
    default:
      return null;
  }
}

/// 账号受限时说明
String? restrictionNotice(AppLocalizations l10n, String? error) {
  switch (error) {
    case 'account_muted':
      return l10n.ticketMuted;
    case 'account_banned':
      return l10n.ticketBanned;
    case 'pending_activation':
      return l10n.ticketPendingActivation;
    default:
      return null;
  }
}

/// 列表卡片里的紧凑标签
class TicketTagChip extends StatelessWidget {
  final String label;
  final Color color;

  const TicketTagChip({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// 详情页 / 标题栏里的胶囊标签
class TicketMetaChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const TicketMetaChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
