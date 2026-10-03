import 'package:flutter/material.dart';
import '../../../models/message_model.dart';
import '../../../models/chat_model.dart';
import '../../../models/settings_service.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/media/image_lightbox.dart';

const String _swipeKeyPrefix = 'swipe-';

const int entranceAnimationBatchLimit = 10;

void _noopMessage(ChatMessage message) {}

String chatMessageStableKey(ChatMessage message) =>
    message.clientMid ?? message.mid?.toString() ?? message.id;

/// 尾部新追加消息的稳定键（用于入场动画）。
/// 首屏/批量/翻页 都不算，只有已经在房间里时新到的消息才返回，比对用稳定键而不是对象实例
Set<String> newlyAppendedMessageKeys(
  List<ChatMessage> previous,
  List<ChatMessage> next, {
  int batchLimit = entranceAnimationBatchLimit,
}) {
  final added = next.length - previous.length;
  if (added <= 0 || previous.isEmpty) return const {};
  // 旧列表必须逐条仍在新列表的前缀里（翻页/同步是从头部合并，会对不上）
  for (var i = 0; i < previous.length; i++) {
    if (identical(previous[i], next[i])) continue;
    if (chatMessageStableKey(previous[i]) != chatMessageStableKey(next[i])) {
      return const {};
    }
  }
  if (added > batchLimit) return const {};
  return {
    for (var i = previous.length; i < next.length; i++)
      chatMessageStableKey(next[i]),
  };
}

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

  final bool isSelectionMode;
  final Set<String> selectedMessageKeys;
  final ValueChanged<ChatMessage> onEnterSelectionMode;
  final ValueChanged<ChatMessage> onToggleSelection;

  /// 本轮新增消息（见 [newlyAppendedMessageKeys]），这些气泡播一次入场动画。
  final Set<String> entranceKeys;

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
    this.isSelectionMode = false,
    this.selectedMessageKeys = const {},
    this.onEnterSelectionMode = _noopMessage,
    this.onToggleSelection = _noopMessage,
    this.entranceKeys = const {},
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

    // 列表 reverse + 新消息插在 index 0，所有既有气泡的 index 都会平移，神秘 bug 调试半天
    Map<String, int>? indexByStableKey;
    int? findChildIndex(Key key) {
      if (key is! ValueKey<String>) return null;
      final raw = key.value;
      if (!raw.startsWith(_swipeKeyPrefix)) return null;
      indexByStableKey ??= {
        for (var i = 0; i < messages.length; i++)
          chatMessageStableKey(messages[i]): i,
      };
      final messageIndex =
          indexByStableKey![raw.substring(_swipeKeyPrefix.length)];
      if (messageIndex == null) return null;
      return messages.length - 1 - messageIndex;
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      cacheExtent: 1200,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      findChildIndexCallback: findChildIndex,
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
        final stableKey = chatMessageStableKey(message);

        // 占位消息（对方上传中）不参与滑动回复等交互，但保留头像/名称展示。
        if (message.isPlaceholder) {
          return MessageBubble(
            key: ValueKey('bubble-$stableKey'),
            message: message,
            animateEntrance: false,
            onReply: onReply,
            onForward: onForward,
            onRecall: onRecall,
            onQuoteTap: onQuoteTap,
            showAvatar: true,
            canRecall: false,
            canPin: false,
            essenceEnabled: essenceEnabled,
          );
        }

        final bubble = MessageBubble(
          key: ValueKey('bubble-$stableKey'),
          message: message,
          animateEntrance: entranceKeys.contains(stableKey),
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
          isSelectionMode: isSelectionMode,
          onEnterSelectionMode: isSelectionMode
              ? null
              : () => onEnterSelectionMode(message),
        );

        final selectionWrapped = _SelectionWrapper(
          isSelectionMode: isSelectionMode,
          isSelected: isSelectionMode && selectedMessageKeys.contains(stableKey),
          onTap: () => onToggleSelection(message),
          child: bubble,
        );

        return Dismissible(
          key: ValueKey('$_swipeKeyPrefix$stableKey'),
          direction: message.isDeleted || isSelectionMode
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
          child: selectionWrapped,
        );
      },
    );
  }
}

class _SelectionWrapper extends StatelessWidget {
  static const double _paddingLeft = 10;
  static const double _indicatorSize = 22;
  static const double _paddingRight = 2;

  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onTap;
  final Widget child;

  const _SelectionWrapper({
    required this.isSelectionMode,
    required this.isSelected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final animDuration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return AnimatedContainer(
      duration: animDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: 0.10)
            : colorScheme.surface.withValues(alpha: 0),
        border: Border(
          left: BorderSide(
            color: isSelected ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: isSelectionMode ? onTap : null,
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AnimatedSize(
                duration: animDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: isSelectionMode
                    ? Padding(
                        padding: const EdgeInsets.only(
                          left: _paddingLeft,
                          right: _paddingRight,
                        ),
                        child: _SelectionIndicator(isSelected: isSelected),
                      )
                    : const SizedBox(width: 0, height: 28),
              ),
              Expanded(
                child: IgnorePointer(
                  ignoring: isSelectionMode,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionIndicator extends StatelessWidget {
  final bool isSelected;

  const _SelectionIndicator({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: _SelectionWrapper._indicatorSize,
      height: _SelectionWrapper._indicatorSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? colorScheme.primary : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.outline.withValues(alpha: 0.7),
          width: 2,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.28),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: AnimatedScale(
        scale: isSelected ? 1 : 0.6,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: isSelected ? 1 : 0,
          duration: reduceMotion
              ? Duration.zero
              : const Duration(milliseconds: 120),
          child: Icon(
            Icons.check_rounded,
            size: 14,
            color: colorScheme.onPrimary,
          ),
        ),
      ),
    );
  }
}
