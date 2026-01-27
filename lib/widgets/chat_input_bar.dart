import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttachmentTap;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttachmentTap,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main input row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Expand/Collapse button
                IconButton(
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isExpanded ? Symbols.close : Symbols.add,
                      key: ValueKey(_isExpanded),
                    ),
                  ),
                  tooltip: _isExpanded ? l10n.chatInputCollapse : l10n.chatInputExpand,
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Symbols.attach_file),
                  tooltip: l10n.chatInputAttachment,
                  onSelected: (value) {
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'photo',
                      child: Row(
                        children: [
                          const Icon(Symbols.add_a_photo),
                          const SizedBox(width: 12),
                          Text(l10n.chatInputTakePhoto),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'video',
                      child: Row(
                        children: [
                          const Icon(Symbols.videocam),
                          const SizedBox(width: 12),
                          Text(l10n.chatInputTakeVideo),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'file',
                      child: Row(
                        children: [
                          const Icon(Symbols.file_upload),
                          const SizedBox(width: 12),
                          Text(l10n.chatInputUploadFile),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'audio',
                      child: Row(
                        children: [
                          const Icon(Symbols.mic),
                          const SizedBox(width: 12),
                          Text(l10n.chatInputRecordAudio),
                        ],
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    maxLines: 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: l10n.chatInputPlaceholder,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      if (widget.controller.text.trim().isNotEmpty) {
                        widget.onSend();
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: colorScheme.primary,
                  onPressed: () {
                    if (widget.controller.text.trim().isNotEmpty) {
                      widget.onSend();
                    }
                  },
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: _isExpanded
                  ? Container(
                      height: 180,
                      margin: const EdgeInsets.only(top: 8, bottom: 3),
                      decoration: BoxDecoration(
                        border: Border.all(
                          width: 1,
                          color: colorScheme.outline.withOpacity(0.3),
                        ),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(24),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          l10n.chatInputFeatureArea,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
