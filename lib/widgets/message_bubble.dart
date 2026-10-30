import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'data_saving_image.dart';
import 'optimized_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../models/message_model.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../widgets/media/image_lightbox.dart';
import '../widgets/media/video_viewer.dart';
import '../widgets/media/audio_player.dart';
import '../widgets/media/voice_message_bubble.dart';
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import 'package:exif/exif.dart';
import '../utils/talker.dart';
import '../utils/clipboard_utils.dart';
import '../models/file_attachment.dart';
import 'file_attachment_view.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/snackbar_service.dart';
import '../providers/task/task_manager_provider.dart';
import '../models/file_task.dart';
import 'sheet_scaffold.dart';
import 'sticker_text_renderer.dart';
import 'message_swipeable_wrapper.dart';
import 'redirect_message_view.dart';

final _stickerTestPattern = RegExp(r':[A-Za-z0-9_]+\+[A-Za-z0-9_-]+:');

/// 仅 root 可用：查看已撤回消息的服务端原始记录。
Future<void> _showRecalledOriginalDialog(
  BuildContext context,
  ChatMessage message,
) async {
  final uid = AuthState.instance.uid;
  final password = AuthState.instance.password;
  final mid = message.mid;
  final l10n = AppLocalizations.of(context)!;
  if (uid == null || mid == null) return;

  final original = await TfApiClient.instance.getRecalledOriginal(
    uid,
    password,
    mid,
  );
  if (!context.mounted) return;
  if (original == null) {
    TouchFishSnackbarService.instance.show(l10n.messageRecalledOriginalFailed);
    return;
  }

  final senderUid = original['sender_uid']?.toString() ?? '';
  final contentType = original['content_type']?.toString() ?? 'plain';
  final content = original['content']?.toString() ?? '';
  final String body;
  if (contentType == 'file') {
    final name = original['file_name']?.toString() ?? content;
    body = '$name\n$content';
  } else if (content.isEmpty) {
    body = l10n.messageRecalledOriginalNone;
  } else {
    body = content;
  }

  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.messageRecalledOriginalTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${l10n.messageRecalledOriginalSender}: $senderUid'),
            const SizedBox(height: 8),
            Text('${l10n.messageRecalledOriginalContent}:'),
            const SizedBox(height: 4),
            SelectableText(body),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    ),
  );
}

/// 消息动作类别。作为 [MessageAction] 与各呈现层筛选的规范标识。
enum MessageActionKind {
  copy,
  reply,
  forward,
  selectMultiple,
  pin,
  essence,
  recall,
  delete,
  viewOriginal,
}

/// 单条消息动作的规范定义：图标、文案、颜色与回调。
///
/// 桌面 hover 菜单、右键菜单、移动端长按 sheet 都由
/// [buildMessageActions] 产出的同一份列表（按各自的 [MessageActionKind]
/// 集合筛选后）渲染，避免三处动作表漂移。
class MessageAction {
  final MessageActionKind kind;
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onInvoke;

  const MessageAction({
    required this.kind,
    required this.icon,
    required this.label,
    required this.onInvoke,
    this.color,
  });
}

Future<void> _copyMessage(BuildContext context, ChatMessage message) async {
  final l10n = AppLocalizations.of(context)!;
  final copied = await copyTextToClipboard(message.text);
  TouchFishSnackbarService.instance.show(
    copied ? l10n.aboutCopiedToClipboard : l10n.copyFailedText,
    type: copied ? SnackbarType.info : SnackbarType.error,
  );
}

/// 构建消息动作的单一事实源列表（规范顺序）。
List<MessageAction> buildMessageActions(
  BuildContext context, {
  required ChatMessage message,
  required bool canRecall,
  required bool canPin,
  required bool essenceEnabled,
  required bool isPinned,
  required bool isEssence,
  ValueChanged<ChatMessage>? onReply,
  ValueChanged<ChatMessage>? onForward,
  ValueChanged<ChatMessage>? onRecall,
  ValueChanged<ChatMessage>? onDelete,
  VoidCallback? onPinToggle,
  VoidCallback? onEssenceToggle,
  VoidCallback? onEnterSelectionMode,
}) {
  final l10n = AppLocalizations.of(context)!;
  final colorScheme = Theme.of(context).colorScheme;
  final actionable = !message.isDeleted && message.mid != null;
  final isRoot = AuthState.instance.currentUser?.isRoot == true;

  return [
    // 撤回/删除后 text 只剩占位文案，复制过去没有意义。
    if (!message.isDeleted)
      MessageAction(
        kind: MessageActionKind.copy,
        icon: Symbols.content_copy,
        label: l10n.messageActionCopy,
        onInvoke: () => _copyMessage(context, message),
      ),
    if (actionable && onReply != null)
      MessageAction(
        kind: MessageActionKind.reply,
        icon: Symbols.reply,
        label: l10n.messageActionReply,
        onInvoke: () => onReply(message),
      ),
    if (actionable && onForward != null)
      MessageAction(
        kind: MessageActionKind.forward,
        icon: Symbols.forward,
        label: l10n.messageActionForward,
        onInvoke: () => onForward(message),
      ),
    if (actionable && onEnterSelectionMode != null)
      MessageAction(
        kind: MessageActionKind.selectMultiple,
        icon: Symbols.select_all,
        label: l10n.messageActionSelectMultiple,
        onInvoke: onEnterSelectionMode,
      ),
    if (canPin)
      MessageAction(
        kind: MessageActionKind.pin,
        icon: Symbols.push_pin,
        label: isPinned ? l10n.messageActionUnpin : l10n.messageActionPin,
        color: isPinned ? colorScheme.error : null,
        onInvoke: onPinToggle ?? () {},
      ),
    if (canPin && essenceEnabled)
      MessageAction(
        kind: MessageActionKind.essence,
        icon: Symbols.auto_awesome,
        label: isEssence ? l10n.essenceRemove : l10n.essenceAdd,
        color: isEssence ? colorScheme.error : null,
        onInvoke: onEssenceToggle ?? () {},
      ),
    if (canRecall)
      MessageAction(
        kind: MessageActionKind.recall,
        icon: Symbols.delete,
        label: l10n.messageActionRecall,
        color: colorScheme.error,
        onInvoke: () => onRecall?.call(message),
      ),
    if (onDelete != null && !message.isDeleted)
      MessageAction(
        kind: MessageActionKind.delete,
        icon: Symbols.delete_forever,
        label: l10n.messageActionDelete,
        color: colorScheme.error,
        onInvoke: () => onDelete(message),
      ),
    if (message.isDeleted && isRoot)
      MessageAction(
        kind: MessageActionKind.viewOriginal,
        icon: Symbols.history,
        label: l10n.messageActionViewOriginal,
        onInvoke: () => _showRecalledOriginalDialog(context, message),
      ),
  ];
}

/// 命中桌面 hover 菜单可呈现的动作子集（紧凑横向图标）。
const Set<MessageActionKind> _hoverActionKinds = {
  MessageActionKind.reply,
  MessageActionKind.forward,
  MessageActionKind.pin,
  MessageActionKind.essence,
  MessageActionKind.recall,
  MessageActionKind.delete,
};

/// 命中右键菜单可呈现的动作子集。
const Set<MessageActionKind> _desktopMenuKinds = {
  MessageActionKind.copy,
  MessageActionKind.reply,
  MessageActionKind.forward,
  MessageActionKind.recall,
  MessageActionKind.delete,
  MessageActionKind.pin,
  MessageActionKind.essence,
  MessageActionKind.viewOriginal,
};

/// 桌面 hover 菜单的按钮尺寸与分隔线占位。
///
/// 菜单装在 `Positioned(width: menuWidth, height: 32)` 里，槽位必须和
/// 渲染出来的宽度完全一致：槽位算窄了就是 "RenderFlex overflowed on the right"，
/// 算宽了菜单会离气泡右边缘一截。两边共用这两个常量，不再各自维护一份数字。
const double _hoverMenuButtonSize = 32;
const double _hoverMenuSeparatorWidth = 9; // 1px 竖线 + 左右各 4px 外边距

double _hoverMenuWidth(List<MessageAction> actions) {
  var width = 0.0;
  for (var i = 0; i < actions.length; i++) {
    if (i > 0 && actions[i].kind != MessageActionKind.forward) {
      width += _hoverMenuSeparatorWidth;
    }
    width += _hoverMenuButtonSize;
  }
  return width;
}

class MessageBubble extends HookWidget {
  final ChatMessage message;
  final ValueChanged<ChatMessage>? onReply;
  final ValueChanged<ChatMessage>? onForward;
  final ValueChanged<ChatMessage>? onRecall;
  final ValueChanged<ChatMessage>? onDelete;
  final ValueChanged<int>? onQuoteTap;
  final bool showAvatar;
  final bool canRecall;
  final bool isPinned;
  final bool isEssence;
  final bool canPin;
  final bool essenceEnabled;
  final VoidCallback? onPinToggle;
  final VoidCallback? onEssenceToggle;

  /// 发送失败的消息，点击状态图标重发。
  final VoidCallback? onRetry;

  /// 已读回执文案（私聊「已读」/群聊「N 人已读」），仅自己的消息展示。
  final String? readReceiptLabel;

  /// 当前聊天的图片画廊条目（按时间序）；为 null 时灯箱单图模式。
  final List<LightboxImageItem>? galleryItems;

  /// 本条消息在画廊中的下标。
  final int galleryIndex;
  final bool animateEntrance;

  final bool isSelectionMode;
  final VoidCallback? onEnterSelectionMode;

  /// 由列表统一下发的展示样式
  final String? displayStyle;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onForward,
    this.onRecall,
    this.onDelete,
    this.onQuoteTap,
    this.showAvatar = true,
    this.canRecall = false,
    this.isPinned = false,
    this.isEssence = false,
    this.canPin = false,
    this.essenceEnabled = true,
    this.onPinToggle,
    this.onEssenceToggle,
    this.onRetry,
    this.readReceiptLabel,
    this.galleryItems,
    this.galleryIndex = 0,
    this.animateEntrance = false,
    this.isSelectionMode = false,
    this.onEnterSelectionMode,
    this.displayStyle,
  });

  @override
  Widget build(BuildContext context) {
    // print("msg: $message, ispinned: $isPinned, isessence: $isEssence");
    final cachedBytes = useMemoized<Uint8List?>(() {
      final media = message.media;
      return media?.bytes != null ? Uint8List.fromList(media!.bytes!) : null;
    }, [message.media?.bytes]);

    return _MessageBubbleContent(
      message: message,
      cachedBytes: cachedBytes,
      animateEntrance: animateEntrance,
      onReply: onReply,
      onForward: onForward,
      onRecall: onRecall,
      onDelete: onDelete,
      onQuoteTap: onQuoteTap,
      showAvatar: showAvatar,
      canRecall: canRecall,
      isPinned: isPinned,
      isEssence: isEssence,
      canPin: canPin,
      essenceEnabled: essenceEnabled,
      onPinToggle: onPinToggle,
      onEssenceToggle: onEssenceToggle,
      onRetry: onRetry,
      readReceiptLabel: readReceiptLabel,
      galleryItems: galleryItems,
      galleryIndex: galleryIndex,
      isSelectionMode: isSelectionMode,
      onEnterSelectionMode: onEnterSelectionMode,
      displayStyle: displayStyle,
    );
  }
}

/// 新消息入场：淡入 + 从下方滑入 + 撑开高度
///
/// 只在 [animate] 首次为 true 时播放一次，元素复用/重建不会重播。
class _MessageEntrance extends StatefulWidget {
  final bool animate;
  final Widget child;

  const _MessageEntrance({required this.animate, required this.child});

  @override
  State<_MessageEntrance> createState() => _MessageEntranceState();
}

class _MessageEntranceState extends State<_MessageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final CurvedAnimation _progress = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutQuart,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.1, 1, curve: Curves.easeOut),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
    end: Offset.zero,
  ).animate(_progress);

  /// 播过动画后一直保持包装层，避免动画结束换结构把子树元素重建掉。
  bool _entered = false;

  @override
  void initState() {
    super.initState();
    _entered = widget.animate;
    if (_entered) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_entered) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SizeTransition(
        sizeFactor: _progress,
        child: SlideTransition(position: _slide, child: widget.child),
      ),
    );
  }
}

class _MessageBubbleContent extends StatefulWidget {
  final ChatMessage message;
  final Uint8List? cachedBytes;
  final ValueChanged<ChatMessage>? onReply;
  final ValueChanged<ChatMessage>? onForward;
  final ValueChanged<ChatMessage>? onRecall;
  final ValueChanged<ChatMessage>? onDelete;
  final ValueChanged<int>? onQuoteTap;
  final bool showAvatar;
  final bool canRecall;
  final bool isPinned;
  final bool isEssence;
  final bool canPin;
  final bool essenceEnabled;
  final VoidCallback? onPinToggle;
  final VoidCallback? onEssenceToggle;
  final VoidCallback? onRetry;
  final String? readReceiptLabel;
  final List<LightboxImageItem>? galleryItems;
  final int galleryIndex;
  final bool animateEntrance;
  final bool isSelectionMode;
  final VoidCallback? onEnterSelectionMode;

  /// 消息展示样式（bubble / compact / column）
  final String? displayStyle;

  const _MessageBubbleContent({
    required this.message,
    this.cachedBytes,
    this.animateEntrance = false,
    this.onReply,
    this.onForward,
    this.onRecall,
    this.onDelete,
    this.onQuoteTap,
    required this.showAvatar,
    required this.canRecall,
    this.isPinned = false,
    this.isEssence = false,
    this.canPin = false,
    this.essenceEnabled = true,
    this.onPinToggle,
    this.onEssenceToggle,
    this.onRetry,
    this.readReceiptLabel,
    this.galleryItems,
    this.galleryIndex = 0,
    this.isSelectionMode = false,
    this.onEnterSelectionMode,
    this.displayStyle,
  });

  @override
  State<_MessageBubbleContent> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubbleContent>
    with AutomaticKeepAliveClientMixin {
  static _MessageBubbleState? _activeHoverOwner;

  final GlobalKey _bubbleKey = GlobalKey();
  OverlayEntry? _hoverOverlay;
  Timer? _hoverShowTimer;
  Timer? _hoverHideTimer;
  Offset? _secondaryTapPosition;
  Offset? _longPressOrigin;
  Timer? _longPressTimer;

  // 只有音视频需要保留状态（播放器/进度）；图片的字节仍在 message.media 里，
  // 让 ListView 正常回收可以显著降低长会话的内存占用。
  @override
  bool get wantKeepAlive {
    final mime = widget.message.media?.mimeType ?? '';
    return mime.startsWith('audio/') || mime.startsWith('video/');
  }

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    _hideHoverActionsImmediately();
    super.dispose();
  }

  void _scheduleShowHoverActions() {
    if (widget.isSelectionMode) return;
    _hoverHideTimer?.cancel();
    _hoverShowTimer?.cancel();
    if (_activeHoverOwner != null && _activeHoverOwner != this) {
      _activeHoverOwner!._hideHoverActionsImmediately();
    }
    _hoverShowTimer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) _showHoverActionsNow();
    });
  }

  void _showHoverActionsNow() {
    _hoverHideTimer?.cancel();
    if (_hoverOverlay != null) return;
    final bubbleBox =
        _bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (bubbleBox == null || overlayBox == null) return;
    final actions = _hoverActions(context);
    final menuWidth = _hoverMenuWidth(actions);
    final bubbleTopLeft = bubbleBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final left = (bubbleTopLeft.dx + bubbleBox.size.width - menuWidth - 4)
        .clamp(4.0, overlayBox.size.width - menuWidth - 4);
    final top = (bubbleTopLeft.dy - 32).clamp(4.0, overlayBox.size.height - 36);
    _hoverOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        width: menuWidth,
        height: 32,
        child: MouseRegion(
          onEnter: (_) {
            _hoverShowTimer?.cancel();
            _hoverHideTimer?.cancel();
          },
          onExit: (_) => _scheduleHideHoverActions(),
          child: KeyedSubtree(
            key: ValueKey('message-actions-${widget.message.id}'),
            child: _MessageHoverActionMenu(actions: actions),
          ),
        ),
      ),
    );
    _activeHoverOwner = this;
    Overlay.of(context).insert(_hoverOverlay!);
  }

  /// 桌面 hover 菜单的动作子集（来自 [buildMessageActions] 单一事实源）。
  List<MessageAction> _hoverActions(BuildContext context) {
    return buildMessageActions(
      context,
      message: widget.message,
      canRecall: widget.canRecall,
      canPin: widget.canPin,
      essenceEnabled: widget.essenceEnabled,
      isPinned: widget.isPinned,
      isEssence: widget.isEssence,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onRecall: widget.onRecall,
      onDelete: widget.onDelete,
      onPinToggle: widget.onPinToggle,
      onEssenceToggle: widget.onEssenceToggle,
    ).where((action) => _hoverActionKinds.contains(action.kind)).toList();
  }

  void _scheduleHideHoverActions() {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    _hoverHideTimer = Timer(const Duration(milliseconds: 250), () {
      _hideHoverActionsImmediately();
    });
  }

  void _hideHoverActionsImmediately() {
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    _hoverOverlay?.remove();
    _hoverOverlay = null;
    if (_activeHoverOwner == this) _activeHoverOwner = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (event.buttons != kPrimaryButton) return;
    _longPressOrigin = event.position;
    _longPressTimer?.cancel();
    _longPressTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      _longPressOrigin = null;
      _showActionSheet();
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    final origin = _longPressOrigin;
    if (origin != null && (event.position - origin).distance > 12) {
      _cancelLongPress();
    }
  }

  void _cancelLongPress([PointerEvent? _]) {
    _longPressTimer?.cancel();
    _longPressTimer = null;
    _longPressOrigin = null;
  }

  bool _isRemotePath(String path) {
    return path.startsWith('http://') || path.startsWith('https://');
  }

  void _showActionSheet() {
    final actions = buildMessageActions(
      context,
      message: widget.message,
      canRecall: widget.canRecall,
      canPin: widget.canPin,
      essenceEnabled: widget.essenceEnabled,
      isPinned: widget.isPinned,
      isEssence: widget.isEssence,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onRecall: widget.onRecall,
      onDelete: widget.onDelete,
      onPinToggle: widget.onPinToggle,
      onEssenceToggle: widget.onEssenceToggle,
      onEnterSelectionMode: widget.onEnterSelectionMode,
    );
    // 已撤回且本人无权处理的旧消息可能一个动作都不剩，别弹出空 sheet。
    if (actions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _MessageActionSheet(actions: actions),
    );
  }

  Future<void> _showDesktopMenu() async {
    final position = _secondaryTapPosition;
    if (position == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final actions = buildMessageActions(
      context,
      message: widget.message,
      canRecall: widget.canRecall,
      canPin: widget.canPin,
      essenceEnabled: widget.essenceEnabled,
      isPinned: widget.isPinned,
      isEssence: widget.isEssence,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onRecall: widget.onRecall,
      onDelete: widget.onDelete,
      onPinToggle: widget.onPinToggle,
      onEssenceToggle: widget.onEssenceToggle,
    ).where((action) => _desktopMenuKinds.contains(action.kind)).toList();
    if (actions.isEmpty) return;
    final selected = await showMenu<MessageAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        for (final action in actions)
          PopupMenuItem<MessageAction>(
            value: action,
            child: ListTile(
              dense: true,
              leading: Icon(action.icon, color: action.color),
              title: Text(
                action.label,
                style: action.color == null
                    ? null
                    : TextStyle(color: action.color),
              ),
            ),
          ),
      ],
    );
    selected?.onInvoke();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    if (widget.message.isPlaceholder) {
      return _buildPlaceholderBubble(context);
    }

    final style =
        widget.displayStyle ??
        SettingsService.instance.getValue<String>(
          'messageDisplayStyle',
          'bubble',
        );
    final content = style == 'compact' || style == 'column'
        ? _buildLinearLayout(context, isCompact: style == 'compact')
        : _buildBubbleLayout(context);
    // 始终包一层（结构稳定，不会因为动画结束而重建子树的元素）
    return _MessageEntrance(animate: widget.animateEntrance, child: content);
  }

  Widget _buildPlaceholderBubble(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final progress = (widget.message.uploadProgress ?? 0.0).clamp(0.0, 1.0);

    final senderName = widget.message.senderName?.trim().isNotEmpty == true
        ? widget.message.senderName!
        : 'User ${widget.message.senderUid ?? ''}';
    final senderAvatar = widget.message.senderAvatar;

    final bubbleContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: 14,
              child: Theme(
                data: Theme.of(context).copyWith(
                  progressIndicatorTheme: const ProgressIndicatorThemeData(
                    circularTrackPadding: EdgeInsets.zero,
                  ),
                ),
                child: CircularProgressIndicator(
                  value: progress > 0 ? progress : null,
                  strokeWidth: 2,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              l10n.chatPlaceholderUploading((progress * 100).toInt()),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        if (progress > 0) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: 180,
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
              color: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    senderName,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTime(widget.message.timestamp, context),
                    style: TextStyle(
                      fontSize: 10,
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvatar(colorScheme, senderAvatar),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: bubbleContent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubbleLayout(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final textColor = widget.message.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final containerColor = widget.message.isMe
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : colorScheme.surfaceContainer;
    final senderUid = widget.message.senderUid;
    final senderName = widget.message.senderName?.trim().isNotEmpty == true
        ? widget.message.senderName!
        : widget.message.isMe
        ? AuthState.instance.currentUser?.username ?? l10n.chatMeLabel
        : senderUid == null
        ? l10n.commonUnknown
        : l10n.chatUserFallback('$senderUid');
    final senderAvatar =
        widget.message.senderAvatar ??
        (widget.message.isMe ? AuthState.instance.currentUser?.avatar : null);

    // 滑动手势包装器
    final bubbleContent = Align(
      key: ValueKey('message-alignment-${widget.message.id}'),
      alignment: widget.message.isMe
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Stack(
            children: [
              MouseRegion(
                onEnter: (_) => _scheduleShowHoverActions(),
                onExit: (_) => _scheduleHideHoverActions(),
                child: Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _cancelLongPress,
                  onPointerCancel: _cancelLongPress,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapDown: (details) =>
                        _secondaryTapPosition = details.globalPosition,
                    onSecondaryTap: _showDesktopMenu,
                    child: Column(
                      crossAxisAlignment: widget.message.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.isPinned)
                          Padding(
                            padding: EdgeInsets.only(
                              left: widget.message.isMe ? 0 : 40,
                              bottom: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Symbols.push_pin,
                                  size: 12,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.pinnedMessageLabel,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: textColor.withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (widget.isEssence && widget.essenceEnabled)
                          Padding(
                            padding: EdgeInsets.only(
                              left: widget.message.isMe ? 0 : 40,
                              bottom: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Symbols.auto_awesome,
                                  size: 12,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  l10n.essenceName,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: textColor.withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        if (!widget.message.isMe && widget.showAvatar)
                          Padding(
                            padding: const EdgeInsets.only(left: 40, bottom: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  senderName,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _formatTime(
                                    widget.message.timestamp,
                                    context,
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: textColor.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: Row(
                            mainAxisAlignment: widget.message.isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!widget.message.isMe) ...[
                                widget.showAvatar
                                    ? _buildAvatar(colorScheme, senderAvatar)
                                    : const SizedBox(width: 32),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Container(
                                        key: _bubbleKey,
                                        decoration: BoxDecoration(
                                          color: containerColor,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: widget.message.mentionsMe
                                              ? Border.all(
                                                  color: colorScheme.tertiary,
                                                )
                                              : null,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        child: _buildMessageContent(
                                          context,
                                          colorScheme,
                                          textTheme,
                                          textColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    _buildStatusIndicator(context, textColor),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.message.isMe)
                          Align(
                            key: ValueKey('message-time-${widget.message.id}'),
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2, right: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatTime(
                                      widget.message.timestamp,
                                      context,
                                    ),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                  if (widget.readReceiptLabel != null) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.readReceiptLabel!,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: textColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 移动端添加滑动手势支持
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return MessageSwipeableWrapper(
        messageId: widget.message.id,
        isCurrentUser: widget.message.isMe,
        onReply: widget.onReply == null
            ? null
            : () => widget.onReply!(widget.message),
        onForward: widget.onForward == null
            ? null
            : () => widget.onForward!(widget.message),
        onShowMenu: _showActionSheet,
        child: bubbleContent,
      );
    }

    return bubbleContent;
  }

  // ---------- compact / column ----------

  bool get _linearMine => widget.message.isMe;

  String get _linearSenderName {
    final message = widget.message;
    if (message.senderName?.trim().isNotEmpty == true) {
      return message.senderName!;
    }
    if (message.isMe) {
      return AuthState.instance.currentUser?.username ?? 'Me';
    }
    return 'User ${message.senderUid ?? ''}';
  }

  String? get _linearSenderAvatar {
    final message = widget.message;
    return message.senderAvatar ??
        (message.isMe ? AuthState.instance.currentUser?.avatar : null);
  }

  /// 弄点区分色
  Color _linearSenderColor(ColorScheme colorScheme) {
    if (_linearMine) return colorScheme.primary;
    final uid = widget.message.senderUid ?? 0;
    final hue = (uid.abs() * 137.508) % 360.0;
    final dark = colorScheme.brightness == Brightness.dark;
    return HSLColor.fromAHSL(
      1,
      hue,
      dark ? 0.55 : 0.6,
      dark ? 0.78 : 0.34,
    ).toColor();
  }

  Widget _buildLinearLayout(BuildContext context, {required bool isCompact}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final mine = _linearMine;
    final showHeader = widget.showAvatar;
    final textColor = mine
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final nameColor = _linearSenderColor(colorScheme);
    final timeColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.75);

    final header = <Widget>[
      if (widget.isPinned)
        _linearBadge(
          text: l10n.pinnedMessageLabel,
          icon: Symbols.push_pin,
          color: timeColor,
        ),
      if (widget.isEssence && widget.essenceEnabled)
        _linearBadge(
          text: l10n.essenceName,
          icon: Symbols.auto_awesome,
          color: timeColor,
        ),
    ];

    final content = _buildMessageContent(
      context,
      colorScheme,
      textTheme,
      textColor,
    );

    return Align(
      key: ValueKey('message-alignment-${widget.message.id}'),
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 12,
            vertical: isCompact ? 1 : 3,
          ),
          child: Stack(
            children: [
              MouseRegion(
                onEnter: (_) => _scheduleShowHoverActions(),
                onExit: (_) => _scheduleHideHoverActions(),
                child: Listener(
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _cancelLongPress,
                  onPointerCancel: _cancelLongPress,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onSecondaryTapDown: (details) =>
                        _secondaryTapPosition = details.globalPosition,
                    onSecondaryTap: _showDesktopMenu,
                    child: Row(
                      crossAxisAlignment: mine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        if (!isCompact)
                          showHeader
                              ? Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _buildAvatar(
                                    colorScheme,
                                    _linearSenderAvatar,
                                  ),
                                )
                              : const SizedBox(width: 40),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (header.isNotEmpty) ...[
                                for (final badge in header)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: badge,
                                  ),
                                const SizedBox(height: 2),
                              ],
                              if (showHeader)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _linearSenderName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: textTheme.bodySmall?.copyWith(
                                            color: nameColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatTime(
                                          widget.message.timestamp,
                                          context,
                                        ),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: timeColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              // 消息内容宽度封顶
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 720,
                                ),
                                child: KeyedSubtree(
                                  key: _bubbleKey,
                                  child: content,
                                ),
                              ),
                              if (mine && widget.readReceiptLabel != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    widget.readReceiptLabel!,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: timeColor.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (mine &&
                            widget.message.status != MessageStatus.sent) ...[
                          const SizedBox(width: 6),
                          _buildStatusIndicator(context, timeColor),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linearBadge({
    required String text,
    required IconData icon,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme, String? senderAvatar) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.primaryContainer,
      child: senderAvatar != null
          ? ClipOval(
              child: DataSavingImage(
                url: senderAvatar,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            )
          : Icon(Icons.person, size: 18, color: colorScheme.onPrimaryContainer),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, Color textColor) {
    if (!widget.message.isMe || widget.message.status == MessageStatus.sent) {
      return const SizedBox.shrink();
    }
    if (widget.message.status == MessageStatus.pending) {
      return SizedBox.square(
        dimension: 10,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: textColor.withValues(alpha: 0.7),
        ),
      );
    }
    if (widget.message.status == MessageStatus.failed) {
      return Tooltip(
        message: AppLocalizations.of(context)!.messageRetrySend,
        child: GestureDetector(
          onTap: widget.onRetry,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(
              Icons.error_outline,
              size: 13,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _formatTime(DateTime time, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(time);
    }
    final locale = Localizations.localeOf(context);
    if (messageDate == today.subtract(const Duration(days: 1))) {
      return '${l10n.chatYesterday} ${DateFormat.Hm().format(time)}';
    }
    if (now.difference(time).inDays < 7) {
      try {
        return '${DateFormat.E(locale.toString()).format(time)} ${DateFormat.Hm().format(time)}';
      } catch (e) {
        return '${DateFormat.E(locale.languageCode == 'och' ? 'zh' : locale.languageCode).format(time)} ${DateFormat.Hm().format(time)}';
      }
    }
    try {
      return DateFormat.MMMd(locale.toString()).add_Hm().format(time);
    } catch (e) {
      return DateFormat.MMMd(
        locale.languageCode == 'och' ? 'zh' : locale.languageCode,
      ).add_Hm().format(time);
    }
  }

  Widget _buildMessageContent(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
    Color textColor,
  ) {
    if (widget.message.isDeleted) {
      return _buildTombstone(context, colorScheme, textTheme);
    }
    final Widget content = switch (widget.message.type) {
      MessageType.image => _buildImageMessage(context, colorScheme),
      MessageType.video => _buildVideoMessage(context, colorScheme),
      MessageType.audio => _buildAudioMessage(context, colorScheme),
      MessageType.file => _buildFileMessage(context, colorScheme, textTheme),
      MessageType.mergedForward =>
        _buildMergedForwardMessage(context, colorScheme, textTheme),
      MessageType.text => _buildTextMessage(context, colorScheme, textTheme),
    };
    final contentWithProgress = _wrapWithUploadProgress(content);
    // 合并转发消息自带来源卡片/内联内容，且 forwarded 仅作溯源用途，
    // 不再渲染普通的"转发 / 原消息不可用"引用框。
    if (widget.message.type == MessageType.mergedForward) {
      return contentWithProgress;
    }
    final quote = widget.message.quotePreview ?? widget.message.forwardPreview;
    if (quote == null) return contentWithProgress;
    final isForward = widget.message.forwardPreview != null;
    return Column(
      crossAxisAlignment: widget.message.isMe
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _buildQuotePreview(
            context,
            quote,
            isForward: isForward,
            textColor: textColor,
          ),
        ),
        contentWithProgress,
      ],
    );
  }

  /// 若该消息是"自己正在上传"的 pending 消息，则叠加上传进度遮罩。
  Widget _wrapWithUploadProgress(Widget content) {
    final message = widget.message;
    // 只有自己发送、处于 pending 且带附件的消息才可能正在上传。
    if (!message.isMe || message.status != MessageStatus.pending) {
      return content;
    }
    if (message.media == null) return content;
    final clientMid = message.clientMid;
    if (clientMid == null) return content;

    return Stack(
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            child: _UploadProgressOverlay(clientMid: clientMid),
          ),
        ),
      ],
    );
  }

  Widget _buildTombstone(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Symbols.block, size: 16, color: colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text(
          AppLocalizations.of(context)!.messageRecalled,
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildQuotePreview(
    BuildContext context,
    QuotedMessagePreview quote, {
    required bool isForward,
    required Color textColor,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final text = quote.isDeleted
        ? l10n.messageQuoteRecalled
        : quote.isMissing
        ? l10n.messageQuoteMissing
        : quote.contentType == 'file'
        ? l10n.mediaFileMessage
        : quote.content;
    final senderLabel = quote.senderName?.trim().isNotEmpty == true
        ? quote.senderName!
        : quote.senderUid != null
        ? 'UID:${quote.senderUid}'
        : '';
    final canOpen = !quote.isDeleted && !quote.isMissing && quote.mid != null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: colorScheme.primaryFixedDim.withValues(alpha: 0.4),
        child: InkWell(
          onTap: canOpen ? () => widget.onQuoteTap?.call(quote.mid!) : null,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 320),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isForward ? Symbols.forward : Symbols.reply,
                      size: 14,
                      color: textColor,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isForward
                            ? senderLabel.isEmpty
                                  ? l10n.messageActionForward
                                  : '${l10n.messageActionForward} $senderLabel'
                            : quote.isMissing
                            ? l10n.messageQuoteMissing
                            : l10n.messageReplyingTo(senderLabel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  text.isEmpty ? l10n.messageQuoteMissing : text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: textColor),
                ),
                if (quote.contentType == 'file' && quote.fileHash != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 120,
                        maxWidth: 180,
                        maxHeight: 96,
                      ),
                      child: FileAttachmentView(
                        attachment: FileAttachment(
                          hash: quote.fileHash!,
                          fileName: quote.fileName ?? quote.fileHash!,
                        ),
                        compact: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextMessage(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final textColor = widget.message.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final textStyle = textTheme.bodyMedium?.copyWith(color: textColor);

    final hasStickers = _stickerTestPattern.hasMatch(widget.message.text);
    if (hasStickers) {
      return StickerTextRenderer(text: widget.message.text, style: textStyle);
    }

    final settingsService = SettingsService.instance;
    final enableMarkdown = settingsService.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );

    return enableMarkdown
        ? Theme(
            data: Theme.of(
              context,
            ).copyWith(textTheme: textTheme.copyWith(bodyMedium: textStyle)),
            child: MarkdownRenderer(
              data: widget.message.text,
              selectable: true,
              selectionContextMenuBuilder: _buildMessageTextContextMenu,
            ),
          )
        : Text(widget.message.text, style: textStyle);
  }

  Widget _buildMessageTextContextMenu(
    BuildContext context,
    SelectableRegionState state,
  ) {
    final message = widget.message;
    final actions = buildMessageActions(
      context,
      message: message,
      canRecall: widget.canRecall,
      canPin: widget.canPin,
      essenceEnabled: widget.essenceEnabled,
      isPinned: widget.isPinned,
      isEssence: widget.isEssence,
      onReply: widget.onReply,
      onForward: widget.onForward,
      onRecall: widget.onRecall,
      onDelete: widget.onDelete,
      onPinToggle: widget.onPinToggle,
      onEssenceToggle: widget.onEssenceToggle,
    ).where((action) => _desktopMenuKinds.contains(action.kind));

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: state.contextMenuAnchors,
      buttonItems: [
        ...state.contextMenuButtonItems,
        for (final action in actions)
          ContextMenuButtonItem(
            label: action.label,
            onPressed: () {
              ContextMenuController.removeAny();
              action.onInvoke();
            },
          ),
      ],
    );
  }

  Widget _buildImageMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null) {
      return _buildTextMessage(
        context,
        colorScheme,
        Theme.of(context).textTheme,
      );
    }

    // 本地字节仍在，which means 自己刚发送的图片！
    if (media.fileHash != null && widget.cachedBytes == null) {
      return _buildRemoteAttachment(media);
    }
    return GestureDetector(
      onTap: () async {
        Map<String, dynamic>? exifData;
        try {
          Uint8List bytes;
          if (widget.cachedBytes != null) {
            bytes = widget.cachedBytes!;
          } else if (!kIsWeb &&
              media.path.isNotEmpty &&
              !_isRemotePath(media.path)) {
            final file = File(media.path);
            bytes = await file.readAsBytes();
          } else {
            bytes = Uint8List(0);
          }

          if (bytes.isNotEmpty) {
            final tags = await readExifFromBytes(bytes);

            if (tags.isNotEmpty) {
              exifData = {};
              if (tags.containsKey('Image DateTime')) {
                exifData['DateTime'] = tags['Image DateTime'].toString();
              }
              if (tags.containsKey('Image Model')) {
                exifData['Model'] = tags['Image Model'].toString();
              }
              if (tags.containsKey('EXIF ISOSpeedRatings')) {
                exifData['ISOSpeedRatings'] = tags['EXIF ISOSpeedRatings']
                    .toString();
              }
              if (tags.containsKey('EXIF FNumber')) {
                exifData['FNumber'] = tags['EXIF FNumber'].toString();
              }
              if (tags.containsKey('EXIF ExposureTime')) {
                exifData['ExposureTime'] = tags['EXIF ExposureTime'].toString();
              }
              if (tags.containsKey('EXIF FocalLength')) {
                exifData['FocalLength'] = tags['EXIF FocalLength'].toString();
              }
            }
          }
        } catch (e) {
          talker.error('Failed to read EXIF', e);
        }

        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageLightbox(
                imagePath: media.path,
                imageBytes: widget.cachedBytes,
                heroTag: 'image_${widget.message.id}',
                exifData: exifData,
                items: widget.galleryItems,
                initialIndex: widget.galleryIndex,
              ),
            ),
          );
        }
      },
      child: Hero(
        tag: 'image_${widget.message.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
            child: OptimizedImage(
              provider: widget.cachedBytes != null
                  ? MemoryImage(widget.cachedBytes!)
                  : _isRemotePath(media.path)
                  ? NetworkImage(media.path)
                  : FileImage(File(media.path)),
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null) {
      return _buildTextMessage(
        context,
        colorScheme,
        Theme.of(context).textTheme,
      );
    }

    if (media.fileHash != null && widget.cachedBytes == null) {
      return _buildRemoteAttachment(media);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300, maxHeight: 400),
        child: AspectRatio(
          aspectRatio: media.aspectRatio ?? 16 / 9,
          child: VideoViewer(
            videoPath: media.path,
            videoBytes: widget.cachedBytes,
            aspectRatio: media.aspectRatio ?? 16 / 9,
            autoplay: false,
          ),
        ),
      ),
    );
  }

  Widget _buildAudioMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null) {
      return _buildTextMessage(
        context,
        colorScheme,
        Theme.of(context).textTheme,
      );
    }

    // 语音消息（带时长元数据）用波形气泡渲染。
    if (media.durationMs != null) {
      return VoiceMessageBubble(
        audioPath: media.path,
        audioBytes: widget.cachedBytes,
        durationMs: media.durationMs,
        fileHash: media.fileHash,
      );
    }

    if (media.fileHash != null && widget.cachedBytes == null) {
      return _buildRemoteAttachment(media);
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: AudioPlayer(
        audioPath: media.path,
        audioBytes: widget.cachedBytes,
        filename: media.fileName,
        autoplay: false,
        durationMs: media.durationMs,
      ),
    );
  }

  Widget _buildFileMessage(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final media = widget.message.media;
    if (media == null) {
      return _buildTextMessage(context, colorScheme, textTheme);
    }

    return _buildRemoteAttachment(media);
  }

  Widget _buildMergedForwardMessage(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final preview = widget.message.mergedForward;
    if (preview == null) {
      return _buildTextMessage(context, colorScheme, textTheme);
    }
    final textColor = widget.message.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;

    // 单条转发 → 内联展示；多条历史段 → 可展开卡片。
    final isSingle = preview.version == 1 && preview.messages.length <= 1;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: isSingle
          ? RedirectInlineContent(redirect: preview, textColor: textColor)
          : RedirectMessageCard(redirect: preview, textColor: textColor),
    );
  }

  Widget _buildRemoteAttachment(MessageMedia media) {
    final hash = media.fileHash ?? media.path;
    final sourceUrl = _isRemotePath(media.path) ? media.path : null;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: FileAttachmentView(
        attachment: FileAttachment(
          hash: hash,
          fileName: media.fileName ?? hash,
          fileSize: media.fileSize,
          mimeType: media.mimeType,
          width: media.width,
          height: media.height,
          blurhash: media.blurhash,
          hasThumb: media.hasThumb,
        ),
        sourceUrl: sourceUrl,
        bytes: widget.cachedBytes,
        durationMs: media.durationMs,
        galleryItems: widget.galleryItems,
        galleryIndex: widget.galleryIndex,
      ),
    );
  }
}

class _UploadProgressOverlay extends ConsumerWidget {
  final String clientMid;

  const _UploadProgressOverlay({required this.clientMid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(
      taskManagerProvider.select((tasks) {
        for (final t in tasks) {
          if (t.clientMid == clientMid) return t;
        }
        return null;
      }),
    );

    if (task == null ||
        (task.status != FileTaskStatus.preparing &&
            task.status != FileTaskStatus.transferring)) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final progress = task.progress;
    final isInstantUpload =
        task.status == FileTaskStatus.preparing && progress == null;

    return Container(
      // 柔和半透明遮罩，更优雅的视觉效果
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface.withValues(alpha: 0.0),
            colorScheme.surface.withValues(alpha: 0.92),
          ],
          stops: const [0.3, 1.0],
        ),
      ),
      alignment: Alignment.bottomCenter,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox.square(
                dimension: 14,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    progressIndicatorTheme: const ProgressIndicatorThemeData(
                      circularTrackPadding: EdgeInsets.zero,
                    ),
                  ),
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2,
                    color: isInstantUpload
                        ? colorScheme.tertiary
                        : colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  isInstantUpload
                      ? l10n.chatInstantUploadProgress
                      : l10n.chatUploadingProgress(task.progressLabel),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (progress != null && progress > 0) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  color: colorScheme.primary,
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageHoverActionMenu extends StatelessWidget {
  final List<MessageAction> actions;

  const _MessageHoverActionMenu({required this.actions});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final children = <Widget>[];
    for (var i = 0; i < actions.length; i++) {
      final action = actions[i];
      if (i > 0 && action.kind != MessageActionKind.forward) {
        children.add(
          Container(
            width: 1,
            height: 24,
            color: colorScheme.outlineVariant,
            margin: const EdgeInsets.symmetric(horizontal: 4),
          ),
        );
      }
      children.add(
        SizedBox.square(
          dimension: _hoverMenuButtonSize,
          child: IconButton(
            icon: Icon(action.icon, size: 16, color: action.color),
            onPressed: action.onInvoke,
            tooltip: action.label,
            padding: EdgeInsets.zero,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _MessageActionSheet extends StatelessWidget {
  final List<MessageAction> actions;

  const _MessageActionSheet({required this.actions});

  /// 这些动作在 sheet 中相邻成组，组内不插入分隔线。
  static const Set<MessageActionKind> _composeGroup = {
    MessageActionKind.reply,
    MessageActionKind.forward,
    MessageActionKind.selectMultiple,
  };

  static bool _sameGroup(MessageActionKind a, MessageActionKind b) =>
      _composeGroup.contains(a) && _composeGroup.contains(b);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SheetScaffold(
      titleText: l10n.messageActions,
      heightFactor: 0.7,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0 && !_sameGroup(actions[i - 1].kind, actions[i].kind))
              const Divider(height: 17),
            _ActionListTile(
              icon: actions[i].icon,
              label: actions[i].label,
              color: actions[i].color,
              onTap: () {
                Navigator.pop(context);
                actions[i].onInvoke();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionListTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 48,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: color),
      title: Text(label, style: color == null ? null : TextStyle(color: color)),
      onTap: onTap,
    );
  }
}
