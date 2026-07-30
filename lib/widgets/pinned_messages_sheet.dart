import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../services/chat_data_service.dart';
import 'sheet_scaffold.dart';

class PinnedMessagesSheet extends StatelessWidget {
  final String roomId;
  final List<PinnedMessage> pins;
  final bool canUnpin;
  final Future<void> Function(int pinId)? onUnpin;
  final void Function(int mid)? onJumpToMessage;

  const PinnedMessagesSheet({
    super.key,
    required this.roomId,
    required this.pins,
    this.canUnpin = false,
    this.onUnpin,
    this.onJumpToMessage,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final messages = ChatDataService.instance.getMessages(roomId);

    return SheetScaffold(
      titleText: l10n.pinnedMessagesTitle,
      heightFactor: 0.7,
      child: pins.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.push_pin,
                    size: 48,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noPinnedMessages,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: pins.length,
              itemBuilder: (context, index) {
                final pin = pins[index];
                final cachedMsg = messages.cast<ChatMessage?>().firstWhere(
                  (m) => m?.mid == pin.messageId,
                  orElse: () => null,
                );
                final pinnedByName = ChatDataService.instance
                    .getUser('U${pin.pinnedByUid}')
                    ?.username;
                return _PinnedMessageTile(
                  pin: pin,
                  cachedMessage: cachedMsg,
                  pinnedByName: pinnedByName,
                  onTap: onJumpToMessage != null
                      ? () {
                          Navigator.pop(context);
                          onJumpToMessage!(pin.messageId);
                        }
                      : null,
                  onUnpin: canUnpin
                      ? () => onUnpin?.call(pin.pinId)
                      : null,
                );
              },
            ),
    );
  }
}

class _PinnedMessageTile extends StatelessWidget {
  final PinnedMessage pin;
  final ChatMessage? cachedMessage;
  final String? pinnedByName;
  final VoidCallback? onTap;
  final VoidCallback? onUnpin;

  const _PinnedMessageTile({
    required this.pin,
    this.cachedMessage,
    this.pinnedByName,
    this.onTap,
    this.onUnpin,
  });

  String _formatTime(double epoch) {
    final dt = DateTime.fromMillisecondsSinceEpoch(
      (epoch * 1000).toInt(),
    );
    final now = DateTime.now();
    if (now.difference(dt).inDays > 365) {
      return DateFormat('yyyy/MM/dd HH:mm').format(dt);
    } else if (now.difference(dt).inDays > 0) {
      return DateFormat('MM/dd HH:mm').format(dt);
    }
    return DateFormat('HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final timestamp = _formatTime(pin.createdAt);
    final senderName = cachedMessage?.senderName ??
        (cachedMessage?.isMe == true ? 'You' : null);
    final content = cachedMessage?.text ?? '';
    final hasAttachments = cachedMessage?.media != null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Symbols.push_pin,
                size: 18,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (senderName != null)
                        Flexible(
                          child: Text(
                            senderName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      if (timestamp.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timestamp,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  if (content.isNotEmpty)
                    Text(
                      content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (hasAttachments)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Symbols.attach_file,
                          size: 14,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          cachedMessage!.media!.fileName ?? 'Attachment',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    )
                  else
                    Text(
                      'MID: ${pin.messageId}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  if (pinnedByName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${l10n.pinnedMessageLabel} by $pinnedByName',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.4),
                          ),
                    ),
                  ],
                ],
              ),
            ),
            if (onUnpin != null)
              IconButton(
                icon: Icon(
                  Symbols.push_pin,
                  size: 18,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: onUnpin,
                tooltip: l10n.messageActionUnpin,
              ),
          ],
        ),
      ),
    );
  }
}
