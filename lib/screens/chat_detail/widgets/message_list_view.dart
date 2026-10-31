import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../models/message_model.dart';
import '../../../models/chat_model.dart';
import '../../../models/settings_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/message_bubble.dart';
import '../../../widgets/media/image_lightbox.dart';
import '../../../widgets/ui/empty_state.dart';
import '../../../widgets/ui/error_state.dart';
import '../../../widgets/ui/refreshable.dart';
import '../../../widgets/ui/skeleton.dart';
import '../../../theme/tokens.dart';
import '../../../providers/chat/image_gallery_provider.dart';
import '../../../widgets/ui/flash_highlight.dart';

const String _swipeKeyPrefix = 'swipe-';

const int entranceAnimationBatchLimit = 10;

void _noopMessage(ChatMessage message) {}

String chatMessageStableKey(ChatMessage message) =>
    message.clientMid ?? message.mid?.toString() ?? message.id;

/// 尾部新追加消息的稳定键
Set<String> newlyAppendedMessageKeys(
  List<ChatMessage> previous,
  List<ChatMessage> next, {
  int batchLimit = entranceAnimationBatchLimit,
}) {
  final added = next.length - previous.length;
  if (added <= 0 || previous.isEmpty) return const {};
  // 旧列表必须逐条仍在新列表的前缀里
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
  final Map<String, int> imageIndexById;
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
  final Function(ChatMessage) onRetry;
  final ValueChanged<int> onQuoteTap;
  final Function(ChatMessage) onPinToggle;
  final Function(ChatMessage) onEssenceToggle;
  final bool Function(ChatMessage) canRecall;
  final bool Function(ChatMessage) canDeleteLocally;
  final String noMessagesText;
  final ColorScheme colorScheme;

  /// 需要闪烁提示落点的消息
  final int? highlightedMid;

  final bool isLoading;

  /// 首屏加载失败文案
  final String? errorText;

  final bool isSelectionMode;
  final Set<String> selectedMessageKeys;
  final ValueChanged<ChatMessage> onEnterSelectionMode;
  final ValueChanged<ChatMessage> onToggleSelection;

  /// 已读回执：全服开关是否开启。
  final bool readReceiptEnabled;

  /// 私聊：对方已读序号
  /// 群聊：mid -> 已读人数。
  final int? peerReadSeq;
  final Map<int, int> groupReadCounts;

  /// 本轮新增消息（见 [newlyAppendedMessageKeys]），这些气泡播一次入场动画。
  final Set<String> entranceKeys;

  /// mid -> GlobalKey：让父级能用 currentContext 精确定位到某条消息。
  final Map<int, GlobalKey> messageKeys;

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
    this.onRetry = _noopMessage,
    required this.onQuoteTap,
    required this.onPinToggle,
    required this.onEssenceToggle,
    required this.canRecall,
    required this.canDeleteLocally,
    required this.noMessagesText,
    required this.colorScheme,
    this.isLoading = false,
    this.errorText,
    this.isSelectionMode = false,
    this.selectedMessageKeys = const {},
    this.onEnterSelectionMode = _noopMessage,
    this.onToggleSelection = _noopMessage,
    this.readReceiptEnabled = false,
    this.peerReadSeq,
    this.groupReadCounts = const {},
    this.entranceKeys = const {},
    this.messageKeys = const {},
    this.highlightedMid,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) => _buildList(context),
    );
  }

  Widget _buildList(BuildContext context) {
    // 外 ListenableBuilder 已在设置变化时重建本方法
    final displayStyle = SettingsService.instance.getValue<String>(
      'messageDisplayStyle',
      'bubble',
    );
    // 置顶/精华判断提到这里做一次 Set，itemBuilder 内即为常数时间
    final pinnedMidSet = <int>{for (final p in pinnedMessages) p.messageId};
    final essenceMidSet = essenceMids.toSet();

    if (messages.isEmpty) {
      if (isLoading) {
        return const MessageListSkeleton();
      }
      if (errorText != null) {
        return PullToRefresh.content(
          onRefresh: () async => onRefresh(),
          child: ErrorState(
            title: errorText!,
            onRetry: onRefresh,
          ),
        );
      }
      return PullToRefresh.content(
        onRefresh: () async => onRefresh(),
        child: EmptyState(
          icon: Icons.chat_bubble_outline,
          title: noMessagesText,
        ),
      );
    }

    // 移动端气泡自带滑动回复手势处理
    // 其他平台才需要
    final themePlatform = Theme.of(context).platform;
    final bubbleHandlesSwipe =
        !kIsWeb &&
        (themePlatform == TargetPlatform.android ||
            themePlatform == TargetPlatform.iOS);

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

    // 已读回执只显示一处
    var readMarkerIndex = -1;
    if (readReceiptEnabled) {
      for (var i = messages.length - 1; i >= 0; i--) {
        final m = messages[i];
        if (m.isMe && !m.isDeleted && m.mid != null && _isReadByPeer(m)) {
          readMarkerIndex = i;
          break;
        }
      }
    }

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      cacheExtent: 400,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messages.length,
      findChildIndexCallback: findChildIndex,
      itemBuilder: (context, index) {
        final messageIndex = messages.length - 1 - index;
        final message = messages[messageIndex];
        final previous = messageIndex > 0 ? messages[messageIndex - 1] : null;
        final showAvatar =
            previous == null ||
            previous.senderUid != message.senderUid ||
            message.timestamp.difference(previous.timestamp).inMinutes >= 5;
        // 优先用 clientMid
        // TCP.ACK WAITING TRANSMISSTION((()))
        // ack id from clientMid -> mid
        // 不然会 sb reload
        final stableKey = chatMessageStableKey(message);

        // 占位消息（对方上传中）不参与滑动回复等交互，但保留头像/名称展示
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
            displayStyle: displayStyle,
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
          onRetry: () => onRetry(message),
          onQuoteTap: onQuoteTap,
          showAvatar: showAvatar,
          galleryItems: galleryItems.isEmpty ? null : galleryItems,
          galleryIndex: imageIndexById[imageGalleryKey(message)] ?? 0,
          canRecall: canRecall(message),
          isEssence:
              message.mid != null &&
              essenceEnabled &&
              essenceMidSet.contains(message.mid),
          isPinned: message.mid != null && pinnedMidSet.contains(message.mid),
          canPin:
              currentRoom?.type == ChatType.group &&
              canModerateGroup &&
              message.mid != null &&
              !message.isDeleted,
          essenceEnabled: essenceEnabled,
          onPinToggle: message.mid != null ? () => onPinToggle(message) : null,
          onEssenceToggle: message.mid != null && essenceEnabled
              ? () => onEssenceToggle(message)
              : null,
          isSelectionMode: isSelectionMode,
          onEnterSelectionMode: isSelectionMode
              ? null
              : () => onEnterSelectionMode(message),
          readReceiptLabel: _readReceiptLabelFor(
            context,
            messageIndex,
            message,
            readMarkerIndex,
          ),
          displayStyle: displayStyle,
        );

        // 跳转定位用的 GlobalKey 只能挂在 Dismissible 之内
        final mid = message.mid;
        final globalKey = mid == null ? null : messageKeys[mid];
        // 落点闪烁
        final highlighted = message.mid != null && message.mid == highlightedMid
            ? FlashHighlight(active: true, child: bubble)
            : bubble;
        final bubbleBody = globalKey == null
            ? highlighted
            : KeyedSubtree(key: globalKey, child: highlighted);

        final selectionWrapped = _SelectionWrapper(
          isSelectionMode: isSelectionMode,
          isSelected:
              isSelectionMode && selectedMessageKeys.contains(stableKey),
          onTap: () => onToggleSelection(message),
          child: bubbleBody,
        );

        // 外层键始终存在
        // findChildIndexCallback 依赖 'swipe-' 前缀定位
        final keyed = KeyedSubtree(
          key: ValueKey('$_swipeKeyPrefix$stableKey'),
          child: selectionWrapped,
        );

        if (bubbleHandlesSwipe) return keyed;

        return Dismissible(
          key: ValueKey('$_swipeKeyPrefix$stableKey'),
          direction: message.isDeleted || isSelectionMode
              ? DismissDirection.none
              : DismissDirection.endToStart,
          dismissThresholds: const {DismissDirection.endToStart: 0.22},
          resizeDuration: null,
          movementDuration: const Duration(milliseconds: 120),
          confirmDismiss: (_) async {
            onReply(message);
            return false;
          },
          background: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: TFSpace.xxl),
              child: Icon(Icons.reply, color: colorScheme.primary),
            ),
          ),
          child: keyed,
        );
      },
    );
  }

  /// 对方是否已读到我这条消息
  bool _isReadByPeer(ChatMessage message) {
    if (currentRoom?.type == ChatType.group) {
      return (groupReadCounts[message.mid!] ?? 0) > 0;
    }
    final seq = message.roomSeq;
    return seq != null && peerReadSeq != null && peerReadSeq! >= seq;
  }

  /// 计算某条消息下的已读回执文案
  String? _readReceiptLabelFor(
    BuildContext context,
    int index,
    ChatMessage message,
    int readMarkerIndex,
  ) {
    if (!readReceiptEnabled || index != readMarkerIndex) return null;
    if (!message.isMe || message.isDeleted || message.mid == null) return null;
    final l10n = AppLocalizations.of(context)!;
    if (currentRoom?.type == ChatType.group) {
      final count = groupReadCounts[message.mid!];
      if (count == null || count <= 0) return null;
      return l10n.chatReadReceiptCount(count);
    }
    return l10n.chatReadReceiptRead;
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
                child: IgnorePointer(ignoring: isSelectionMode, child: child),
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
