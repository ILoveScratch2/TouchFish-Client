import 'dart:io';
import 'dart:typed_data';
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
import 'package:path/path.dart' as path;
import 'package:exif/exif.dart';

class MessageBubble extends HookWidget {
  final ChatMessage message;

  const MessageBubble({
    super.key,
    required this.message,
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
    );
  }
}

class _MessageBubbleContent extends StatefulWidget {
  final ChatMessage message;
  final Uint8List? cachedBytes;

  const _MessageBubbleContent({
    required this.message,
    this.cachedBytes,
  });

  @override
  State<_MessageBubbleContent> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubbleContent> {
  bool _isHovered = false;

  void _showActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => _MessageActionSheet(
        message: widget.message,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Align(
      alignment: widget.message.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: GestureDetector(
                onLongPress: _showActionSheet,
                onSecondaryTap: _showActionSheet,
                child: Row(
                  mainAxisAlignment:
                      widget.message.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!widget.message.isMe) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: colorScheme.primaryContainer,
                          child: widget.message.senderAvatar != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.message.senderAvatar!,
                                    width: 32,
                                    height: 32,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.person,
                                        size: 18,
                                        color: colorScheme.onPrimaryContainer,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 18,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Column(
                        crossAxisAlignment: widget.message.isMe
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          if (!widget.message.isMe && widget.message.senderName != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 2),
                              child: Text(
                                widget.message.senderName!,
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          _buildMessageContent(context, colorScheme, textTheme),
                          Padding(
                            padding: const EdgeInsets.only(top: 2, left: 12, right: 12),
                            child: Text(
                              _formatTime(widget.message.timestamp),
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Hover action menu
            if (_isHovered)
              Positioned(
                top: -15,
                right: widget.message.isMe ? 15 : null,
                left: !widget.message.isMe ? 60 : null,
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  child: _MessageHoverActionMenu(
                    isMe: widget.message.isMe,
                    onReply: () {},
                    onForward: () {},
                    onDelete: widget.message.isMe ? () {} : null,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
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

  Widget _buildMessageContent(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    switch (widget.message.type) {
      case MessageType.image:
        return _buildImageMessage(context, colorScheme);
      case MessageType.video:
        return _buildVideoMessage(context, colorScheme);
      case MessageType.audio:
        return _buildAudioMessage(context, colorScheme);
      case MessageType.file:
        return _buildFileMessage(context, colorScheme, textTheme);
      case MessageType.text:
      default:
        return _buildTextMessage(context, colorScheme, textTheme);
    }
  }

  Widget _buildTextMessage(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.message.isMe
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: widget.message.isMe ? const Radius.circular(18) : const Radius.circular(4),
          topRight: widget.message.isMe ? const Radius.circular(4) : const Radius.circular(18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
      ),
      child: Text(
        widget.message.text,
        style: textTheme.bodyMedium?.copyWith(
          color: widget.message.isMe ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildImageMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null) return _buildTextMessage(context, colorScheme, Theme.of(context).textTheme);

    return GestureDetector(
      onTap: () async {
        Map<String, dynamic>? exifData;
        try {
          Uint8List bytes;
          // Priority: cachedBytes > read from file
          if (widget.cachedBytes != null) {
            bytes = widget.cachedBytes!;
          } else if (!kIsWeb && media.path.isNotEmpty) {
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
                exifData['ISOSpeedRatings'] = tags['EXIF ISOSpeedRatings'].toString();
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
          print('Failed to read EXIF: $e');
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
            constraints: const BoxConstraints(
              maxWidth: 300,
              maxHeight: 400,
            ),
            child: widget.cachedBytes != null
                ? Image.memory(
                    widget.cachedBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : Image.file(
                    File(media.path),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context, ColorScheme colorScheme) {
    final media = widget.message.media;
    if (media == null) return _buildTextMessage(context, colorScheme, Theme.of(context).textTheme);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 300,
          maxHeight: 400,
        ),
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
    if (media == null) return _buildTextMessage(context, colorScheme, Theme.of(context).textTheme);

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

  Widget _buildFileMessage(BuildContext context, ColorScheme colorScheme, TextTheme textTheme) {
    final media = widget.message.media;
    if (media == null) return _buildTextMessage(context, colorScheme, textTheme);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.message.isMe
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.insert_drive_file,
            color: widget.message.isMe
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  media.fileName ?? AppLocalizations.of(context)!.mediaFileMessage,
                  style: textTheme.bodyMedium?.copyWith(
                    color: widget.message.isMe
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (media.fileSize != null)
                  Text(
                    _formatFileSize(media.fileSize!),
                    style: textTheme.bodySmall?.copyWith(
                      color: widget.message.isMe
                          ? colorScheme.onPrimaryContainer.withOpacity(0.7)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _MessageHoverActionMenu extends StatelessWidget {
  final bool isMe;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback? onDelete;

  const _MessageHoverActionMenu({
    required this.isMe,
    required this.onReply,
    required this.onForward,
    this.onDelete,
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
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isMe)
            IconButton(
              icon: const Icon(Symbols.reply, size: 16),
              onPressed: onReply,
              tooltip: l10n.messageActionReply,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          IconButton(
            icon: const Icon(Symbols.forward, size: 16),
            onPressed: onForward,
            tooltip: l10n.messageActionForward,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          if (onDelete != null) ...[
            Container(
              width: 1,
              height: 24,
              color: Theme.of(context).colorScheme.outlineVariant,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            IconButton(
              icon: const Icon(Symbols.delete, size: 16, color: Colors.red),
              onPressed: onDelete,
              tooltip: l10n.messageActionDelete,
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageActionSheet extends StatelessWidget {
  final ChatMessage message;

  const _MessageActionSheet({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.messageActions,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Symbols.reply),
            title: Text(l10n.messageActionReply),
            onTap: () {
              Navigator.pop(context);
              // 没有回复
            },
          ),
          ListTile(
            leading: const Icon(Symbols.forward),
            title: Text(l10n.messageActionForward),
            onTap: () {
              Navigator.pop(context);
              // 没有转发
            },
          ),
          if (message.isMe)
            ListTile(
              leading: const Icon(Symbols.delete, color: Colors.red),
              title: Text(
                l10n.messageActionDelete,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement delete action
              },
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
