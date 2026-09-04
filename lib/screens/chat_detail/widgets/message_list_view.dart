import 'package:flutter/material.dart';
import '../../../models/message_model.dart';
import '../../../models/chat_model.dart';
import '../../../models/settings_service.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/media/image_lightbox.dart';

/// 消息列表视图
class MessageListView extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final List<LightboxImageItem> galleryItems;
  final Map<ChatMessage, int> imageIndexById;
  final List<int> essenceMids;
  final List<PinnedMessage> pinnedMessages;
  final bool essenceEnabled;
  final ChatRoom? currentRoom;
  final bool canModerateGroup;
  final VoidCallback onRefresh;
  final Function(ChatMessage) onReply;
  final Function(ChatMessage) onForward;
  final Function(ChatMessage) onRecall;
  final Function(ChatMessage)? onDelete;
  final ValueChanged<int> onQuoteTap;
  final Function(ChatMessage) onPinToggle;
  final Function(ChatMessage) onEssenceToggle;
  final bool Function(ChatMessage) canRecall;
  final bool Function(ChatMessage) canDeleteLocally;
  final String noMessagesText;
  final ColorScheme colorScheme;

  const MessageListView({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.galleryItems,
    required this.imageIndexById,
    required this.essenceMids,
    required this.pinnedMessages,
    required this.essenceEnabled,
    required this.currentRoom,
    required this.canModerateGroup,
    required this.onRefresh,
    required this.onReply,
    required this.onForward,
    required this.onRecall,
    this.onDelete,
    required this.onQuoteTap,
    required this.onPinToggle,
    required this.onEssenceToggle,
    required this.canRecall,
    required this.canDeleteLocally,
    required this.noMessagesText,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    if (messages.isEmpty) {
      return RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.4,
              child: Center(
                child: Text(
                  noMessagesText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final messageIndex = messages.length - 1 - index;
        final message = messages[messageIndex];
        final previous = messageIndex > 0 ? messages[messageIndex - 1] : null;
        final showAvatar = previous == null ||
            previous.senderUid != message.senderUid ||
            message.timestamp.difference(previous.timestamp).inMinutes >= 5;
        // 优先用 clientMid
        // TCP.ACK WAITING TRANSMISSTION((())) 
        // ack id from clientMid -> mid
        // 不然会 sb reload
        final stableKey =
            message.clientMid ?? message.mid?.toString() ?? message.id;

        return Dismissible(
          key: ValueKey('swipe-$stableKey'),
          direction: message.isDeleted
              ? DismissDirection.none
              : DismissDirection.endToStart,
          dismissThresholds: const {
            DismissDirection.endToStart: 0.22,
          },
          resizeDuration: null,
          movementDuration: const Duration(milliseconds: 120),
          confirmDismiss: (_) async {
            onReply(message);
            return false;
          },
          background: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Icon(
                Icons.reply,
                color: colorScheme.primary,
              ),
            ),
          ),
          child: MessageBubble(
            key: ValueKey('bubble-$stableKey'),
            message: message,
            onReply: onReply,
            onForward: onForward,
            onRecall: onRecall,
            onDelete: canDeleteLocally(message)
                ? (_) => onDelete?.call(message)
                : null,
            onQuoteTap: onQuoteTap,
            showAvatar: showAvatar,
            galleryItems: galleryItems.isEmpty ? null : galleryItems,
            galleryIndex: imageIndexById[message] ?? 0,
            canRecall: canRecall(message),
            isEssence: message.mid != null &&
                essenceMids.contains(message.mid) &&
                essenceEnabled,
            isPinned: message.mid != null &&
                pinnedMessages.any((p) => p.messageId == message.mid),
            canPin: currentRoom?.type == ChatType.group &&
                canModerateGroup &&
                message.mid != null &&
                !message.isDeleted,
            essenceEnabled: essenceEnabled,
            onPinToggle:
                message.mid != null ? () => onPinToggle(message) : null,
            onEssenceToggle: message.mid != null && essenceEnabled
                ? () => onEssenceToggle(message)
                : null,
          ),
        );
      },
    );
  }
}
