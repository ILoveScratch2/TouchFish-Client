import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
import '../widgets/markdown_renderer.dart';
import '../models/settings_service.dart';
import 'package:exif/exif.dart';
import '../utils/talker.dart';
import '../models/file_attachment.dart';
import 'file_attachment_view.dart';
import '../services/auth_state.dart';
import 'sheet_scaffold.dart';

class MessageBubble extends HookWidget {
  final ChatMessage message;
  final ValueChanged<ChatMessage>? onReply;
  final ValueChanged<ChatMessage>? onForward;
  final ValueChanged<ChatMessage>? onRecall;
  final ValueChanged<int>? onQuoteTap;
  final bool showAvatar;
  final bool canRecall;

  const MessageBubble({
    super.key,
    required this.message,
    this.onReply,
    this.onForward,
    this.onRecall,
    this.onQuoteTap,
    this.showAvatar = true,
    this.canRecall = false,
  });

  @override
  Widget build(BuildContext context) {
    final cachedBytes = useMemoized<Uint8List?>(() {
      final media = message.media;
      return media?.bytes != null ? Uint8List.fromList(media!.bytes!) : null;
    }, [message.media?.bytes]);

    return _MessageBubbleContent(
      message: message,
      cachedBytes: cachedBytes,
      onReply: onReply,
      onForward: onForward,
      onRecall: onRecall,
      onQuoteTap: onQuoteTap,
      showAvatar: showAvatar,
      canRecall: canRecall,
    );
  }
}

class _MessageBubbleContent extends StatefulWidget {
  final ChatMessage message;
  final Uint8List? cachedBytes;
  final ValueChanged<ChatMessage>? onReply;
  final ValueChanged<ChatMessage>? onForward;
  final ValueChanged<ChatMessage>? onRecall;
  final ValueChanged<int>? onQuoteTap;
  final bool showAvatar;
  final bool canRecall;

  const _MessageBubbleContent({
    required this.message,
    this.cachedBytes,
    this.onReply,
    this.onForward,
    this.onRecall,
    this.onQuoteTap,
    required this.showAvatar,
    required this.canRecall,
  });

  @override
  State<_MessageBubbleContent> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubbleContent> {
  static _MessageBubbleState? _activeHoverOwner;

  final GlobalKey _bubbleKey = GlobalKey();
  OverlayEntry? _hoverOverlay;
  Timer? _hoverShowTimer;
  Timer? _hoverHideTimer;
  Offset? _secondaryTapPosition;
  Offset? _longPressOrigin;
  Timer? _longPressTimer;

  @override
  void dispose() {
    _longPressTimer?.cancel();
    _hoverShowTimer?.cancel();
    _hoverHideTimer?.cancel();
    _hideHoverActionsImmediately();
    super.dispose();
  }

  void _scheduleShowHoverActions() {
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
    final bubbleTopLeft = bubbleBox.localToGlobal(
      Offset.zero,
      ancestor: overlayBox,
    );
    final menuWidth = _hoverMenuWidth;
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
            child: _buildHoverActionMenu(),
          ),
        ),
      ),
    );
    _activeHoverOwner = this;
    Overlay.of(context).insert(_hoverOverlay!);
  }

  double get _hoverMenuWidth {
    var width = 0.0;
    if (!widget.message.isDeleted && widget.message.mid != null) {
      width += 64;
    }
    if (widget.canRecall) width += 41;
    return width;
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
    showModalBottomSheet(
      context: context,
      builder: (context) => _MessageActionSheet(
        message: widget.message,
        onReply: widget.onReply,
        onForward: widget.onForward,
        onRecall: widget.onRecall,
        canRecall: widget.canRecall,
      ),
    );
  }

  Future<void> _showDesktopMenu() async {
    final position = _secondaryTapPosition;
    if (position == null) return;
    final l10n = AppLocalizations.of(context)!;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'reply',
          enabled: !widget.message.isDeleted && widget.message.mid != null,
          child: ListTile(
            dense: true,
            leading: const Icon(Symbols.reply),
            title: Text(l10n.messageActionReply),
          ),
        ),
        PopupMenuItem(
          value: 'forward',
          enabled: !widget.message.isDeleted && widget.message.mid != null,
          child: ListTile(
            dense: true,
            leading: const Icon(Symbols.forward),
            title: Text(l10n.messageActionForward),
          ),
        ),
        if (widget.canRecall)
          PopupMenuItem(
            value: 'recall',
            child: ListTile(
              dense: true,
              leading: Icon(
                Symbols.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(l10n.messageActionRecall),
            ),
          ),
      ],
    );
    if (selected == 'reply') widget.onReply?.call(widget.message);
    if (selected == 'forward') widget.onForward?.call(widget.message);
    if (selected == 'recall') widget.onRecall?.call(widget.message);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final textColor = widget.message.isMe
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final containerColor = widget.message.isMe
        ? colorScheme.primaryContainer.withValues(alpha: 0.5)
        : colorScheme.surfaceContainer;
    final senderName = widget.message.senderName?.trim().isNotEmpty == true
        ? widget.message.senderName!
        : widget.message.isMe
        ? AuthState.instance.currentUser?.username ?? 'Me'
        : 'User ${widget.message.senderUid ?? ''}';
    final senderAvatar =
        widget.message.senderAvatar ??
        (widget.message.isMe ? AuthState.instance.currentUser?.avatar : null);

    return Align(
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
                                  _formatTime(widget.message.timestamp),
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
                            crossAxisAlignment: CrossAxisAlignment.end,
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
                                    _buildStatusIndicator(textColor),
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
                              child: Text(
                                _formatTime(widget.message.timestamp),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: textColor.withValues(alpha: 0.7),
                                ),
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
  }

  Widget _buildHoverActionMenu() {
    return _MessageHoverActionMenu(
      onReply: widget.message.isDeleted || widget.message.mid == null
          ? null
          : () => widget.onReply?.call(widget.message),
      onForward: widget.message.isDeleted || widget.message.mid == null
          ? null
          : () => widget.onForward?.call(widget.message),
      onRecall: widget.canRecall
          ? () => widget.onRecall?.call(widget.message)
          : null,
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme, String? senderAvatar) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.primaryContainer,
      child: senderAvatar != null
          ? ClipOval(
              child: Image.network(
                senderAvatar,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.person,
                  size: 18,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
            )
          : Icon(Icons.person, size: 18, color: colorScheme.onPrimaryContainer),
    );
  }

  Widget _buildStatusIndicator(Color textColor) {
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
      return const Icon(Icons.error_outline, size: 12, color: Colors.red);
    }
    return const SizedBox.shrink();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(time);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return '昨天 ${DateFormat.Hm().format(time)}';
    } else if (now.difference(time).inDays < 7) {
      return '${DateFormat.E('zh_CN').format(time)} ${DateFormat.Hm().format(time)}';
    } else {
      return DateFormat.MMMd('zh_CN').add_Hm().format(time);
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
      MessageType.text => _buildTextMessage(context, colorScheme, textTheme),
    };
    final quote = widget.message.quotePreview ?? widget.message.forwardPreview;
    if (quote == null) return content;
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
        content,
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
    final settingsService = SettingsService.instance;
    final enableMarkdown = settingsService.getValue<bool>(
      'enableMarkdownRendering',
      true,
    );

    return enableMarkdown
        ? Theme(
            data: Theme.of(context).copyWith(
              textTheme: textTheme.copyWith(
                bodyMedium: textTheme.bodyMedium?.copyWith(
                  color: widget.message.isMe
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurface,
                ),
              ),
            ),
            child: MarkdownRenderer(
              data: widget.message.text,
              selectable: true,
            ),
          )
        : Text(
            widget.message.text,
            style: textTheme.bodyMedium?.copyWith(
              color: widget.message.isMe
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurface,
            ),
          );
  }

  Widget _buildImageMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null)
      return _buildTextMessage(
        context,
        colorScheme,
        Theme.of(context).textTheme,
      );

    if (media.fileHash != null) {
      return _buildRemoteAttachment(media);
    }
    return GestureDetector(
      onTap: () async {
        Map<String, dynamic>? exifData;
        try {
          Uint8List bytes;
          // Priority: cachedBytes > read from file
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
            child: widget.cachedBytes != null
                ? Image.memory(
                    widget.cachedBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : _isRemotePath(media.path)
                ? Image.network(media.path, fit: BoxFit.cover)
                : Image.file(File(media.path), fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null)
      return _buildTextMessage(
        context,
        colorScheme,
        Theme.of(context).textTheme,
      );

    if (media.fileHash != null) return _buildRemoteAttachment(media);
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
    if (media == null)
      return _buildTextMessage(
        context,
        colorScheme,
        Theme.of(context).textTheme,
      );

    if (media.fileHash != null) return _buildRemoteAttachment(media);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: AudioPlayer(
        audioPath: media.path,
        audioBytes: widget.cachedBytes,
        filename: media.fileName,
        autoplay: false,
      ),
    );
  }

  Widget _buildFileMessage(
    BuildContext context,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    final media = widget.message.media;
    if (media == null)
      return _buildTextMessage(context, colorScheme, textTheme);

    return _buildRemoteAttachment(media);
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
        ),
        sourceUrl: sourceUrl,
        bytes: widget.cachedBytes,
      ),
    );
  }
}

class _MessageHoverActionMenu extends StatelessWidget {
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onRecall;

  const _MessageHoverActionMenu({
    required this.onReply,
    required this.onForward,
    this.onRecall,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onReply != null)
            SizedBox.square(
              dimension: 32,
              child: IconButton(
                icon: const Icon(Symbols.reply, size: 16),
                onPressed: onReply,
                tooltip: l10n.messageActionReply,
                padding: EdgeInsets.zero,
              ),
            ),
          if (onForward != null)
            SizedBox.square(
              dimension: 32,
              child: IconButton(
                icon: const Icon(Symbols.forward, size: 16),
                onPressed: onForward,
                tooltip: l10n.messageActionForward,
                padding: EdgeInsets.zero,
              ),
            ),
          if (onRecall != null) ...[
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).colorScheme.outlineVariant,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            SizedBox.square(
              dimension: 32,
              child: IconButton(
                icon: const Icon(Symbols.delete, size: 16, color: Colors.red),
                onPressed: onRecall,
                tooltip: l10n.messageActionRecall,
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageActionSheet extends StatelessWidget {
  final ChatMessage message;
  final ValueChanged<ChatMessage>? onReply;
  final ValueChanged<ChatMessage>? onForward;
  final ValueChanged<ChatMessage>? onRecall;
  final bool canRecall;

  const _MessageActionSheet({
    required this.message,
    this.onReply,
    this.onForward,
    this.onRecall,
    required this.canRecall,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SheetScaffold(
      titleText: l10n.messageActions,
      heightFactor: 0.55,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (!message.isDeleted && message.mid != null) ...[
            _ActionListTile(
              icon: Symbols.reply,
              label: l10n.messageActionReply,
              onTap: () {
                Navigator.pop(context);
                onReply?.call(message);
              },
            ),
            _ActionListTile(
              icon: Symbols.forward,
              label: l10n.messageActionForward,
              onTap: () {
                Navigator.pop(context);
                onForward?.call(message);
              },
            ),
          ],
          if (canRecall) ...[
            const Divider(height: 17),
            _ActionListTile(
              icon: Symbols.delete,
              label: l10n.messageActionRecall,
              color: Theme.of(context).colorScheme.error,
              onTap: () {
                Navigator.pop(context);
                onRecall?.call(message);
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
