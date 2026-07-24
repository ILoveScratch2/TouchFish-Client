import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_symbols_icons/symbols.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../models/settings_service.dart';
import 'mention_text_field.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(PlatformFile file, MessageType type)? onFilePicked;
  final List<MentionUser> mentionUsers;
  final ChatMessage? actionMessage;
  final bool actionIsForward;
  final VoidCallback? onClearAction;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onFilePicked,
    this.mentionUsers = const [],
    this.actionMessage,
    this.actionIsForward = false,
    this.onClearAction,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final TabController _tabController;
  late final FocusNode _inputFocusNode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _inputFocusNode = FocusNode(onKeyEvent: _handleInputKeyEvent);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleInputKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        (event.logicalKey != LogicalKeyboardKey.enter &&
            event.logicalKey != LogicalKeyboardKey.numpadEnter)) {
      return KeyEventResult.ignored;
    }

    final value = widget.controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    final controlOrMeta = keyboard.isControlPressed || keyboard.isMetaPressed;
    final sendMode = SettingsService.instance.getValue<String>(
      'sendMode',
      'enter',
    );
    final shouldSend = sendMode == 'ctrlEnter'
        ? controlOrMeta && !keyboard.isShiftPressed && !keyboard.isAltPressed
        : !controlOrMeta && !keyboard.isShiftPressed && !keyboard.isAltPressed;

    if (shouldSend) {
      if (value.text.trim().isNotEmpty || widget.actionIsForward) {
        widget.onSend();
      }
      return KeyEventResult.handled;
    }

    if (sendMode == 'enter' && controlOrMeta) {
      _insertNewline();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _insertNewline() {
    final value = widget.controller.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    widget.controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, '\n'),
      selection: TextSelection.collapsed(offset: start + 1),
      composing: TextRange.empty,
    );
  }

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
            _buildMessageActionPreview(context),
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
                  tooltip: _isExpanded
                      ? l10n.chatInputCollapse
                      : l10n.chatInputExpand,
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Symbols.attach_file),
                  tooltip: l10n.chatInputAttachment,
                  onSelected: (value) async {
                    await _handleAttachment(value);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'image',
                      child: Row(
                        children: [
                          const Icon(Symbols.image),
                          const SizedBox(width: 12),
                          Text(l10n.mediaPickImage),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'video',
                      child: Row(
                        children: [
                          const Icon(Symbols.videocam),
                          const SizedBox(width: 12),
                          Text(l10n.mediaPickVideo),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'audio',
                      child: Row(
                        children: [
                          const Icon(Symbols.audiotrack),
                          const SizedBox(width: 12),
                          Text(l10n.mediaPickAudio),
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
                  ],
                ),
                Expanded(
                  child: MentionTextField(
                    controller: widget.controller,
                    focusNode: _inputFocusNode,
                    mentionUsers: widget.mentionUsers,
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
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  color: colorScheme.primary,
                  onPressed: () {
                    if (widget.controller.text.trim().isNotEmpty ||
                        widget.actionIsForward) {
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
                      height: 200,
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
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TabBar(
                              controller: _tabController,
                              tabs: [
                                Tab(text: l10n.chatFunctionTabFiles),
                                Tab(text: l10n.chatFunctionTabEmoji),
                                Tab(text: l10n.chatFunctionTabSpecial),
                              ],
                              labelStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 13,
                              ),
                              indicatorSize: TabBarIndicatorSize.label,
                              labelColor: colorScheme.primary,
                              unselectedLabelColor:
                                  colorScheme.onSurfaceVariant,
                              indicatorPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              dividerColor: Colors.transparent,
                              tabAlignment: TabAlignment.center,
                              splashFactory: NoSplash.splashFactory,
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildFilesTab(colorScheme, l10n),
                                _buildEmojiTab(colorScheme, l10n),
                                _buildSpecialMessagesTab(colorScheme, l10n),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageActionPreview(BuildContext context) {
    final message = widget.actionMessage;
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: child,
          ),
        ),
      ),
      child: message == null
          ? const SizedBox.shrink(key: ValueKey('no-message-action'))
          : Container(
              key: ValueKey(
                '${widget.actionIsForward ? 'forward' : 'reply'}-${message.id}',
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        widget.actionIsForward
                            ? Symbols.forward
                            : Symbols.reply,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.actionIsForward
                              ? l10n.messageActionForward
                              : l10n.messageReplyingTo(
                                  message.isMe
                                      ? 'Me'
                                      : message.senderName ?? 'Unknown',
                                ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox.square(
                        dimension: 24,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: widget.onClearAction,
                          tooltip: l10n.messageReplyDismiss,
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 26),
                    child: Text(
                      message.type == MessageType.file
                          ? l10n.mediaFileMessage
                          : message.text,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildFilesTab(ColorScheme colorScheme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatFunctionTabFilesHint,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () async {
              final selected = await showMenu<String>(
                context: context,
                position: const RelativeRect.fromLTRB(0, 0, 0, 0),
                items: [
                  PopupMenuItem(
                    value: 'image',
                    child: Row(children: [
                      const Icon(Icons.image),
                      const SizedBox(width: 12),
                      Text(l10n.mediaPickImage),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'video',
                    child: Row(children: [
                      const Icon(Icons.videocam),
                      const SizedBox(width: 12),
                      Text(l10n.mediaPickVideo),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'audio',
                    child: Row(children: [
                      const Icon(Icons.audiotrack),
                      const SizedBox(width: 12),
                      Text(l10n.mediaPickAudio),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'file',
                    child: Row(children: [
                      const Icon(Icons.file_upload),
                      const SizedBox(width: 12),
                      Text(l10n.chatInputUploadFile),
                    ]),
                  ),
                ],
              );
              if (selected != null) {
                await _handleAttachment(selected);
              }
            },
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.chatFunctionPickFile),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiTab(ColorScheme colorScheme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emoji_emotions_outlined,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatFunctionTabEmojiHint,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialMessagesTab(
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline,
            size: 40,
            color: colorScheme.onSurfaceVariant.withOpacity(0.4),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.chatFunctionTabSpecialHint,
            style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAttachment(String type) async {
    FilePickerResult? result;

    switch (type) {
      case 'image':
        if (!kIsWeb && Platform.isAndroid) {
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: [
              'jpg',
              'jpeg',
              'png',
              'gif',
              'bmp',
              'webp',
              'heic',
              'heif',
            ],
            allowMultiple: false,
            withData: false,
          );
        } else {
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            withData: true,
          );
        }
        if (result != null && widget.onFilePicked != null) {
          final file = result.files.single;
          if (file.bytes != null || file.path != null) {
            widget.onFilePicked!(file, MessageType.image);
          }
        }
        break;

      case 'video':
        result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
          withData: kIsWeb,
        );
        if (result != null && widget.onFilePicked != null) {
          if (kIsWeb && result.files.single.bytes != null) {
            widget.onFilePicked!(result.files.single, MessageType.video);
          } else if (!kIsWeb && result.files.single.path != null) {
            widget.onFilePicked!(result.files.single, MessageType.video);
          }
        }
        break;

      case 'audio':
        result = await FilePicker.platform.pickFiles(
          type: FileType.audio,
          allowMultiple: false,
          withData: kIsWeb,
        );
        if (result != null && widget.onFilePicked != null) {
          if (kIsWeb && result.files.single.bytes != null) {
            widget.onFilePicked!(result.files.single, MessageType.audio);
          } else if (!kIsWeb && result.files.single.path != null) {
            widget.onFilePicked!(result.files.single, MessageType.audio);
          }
        }
        break;

      case 'file':
        result = await FilePicker.platform.pickFiles(
          type: FileType.any,
          allowMultiple: false,
          withData: kIsWeb,
        );
        if (result != null && widget.onFilePicked != null) {
          final file = result.files.single;
          if ((kIsWeb && file.bytes != null) ||
              (!kIsWeb && file.path != null)) {
            String? mimeType;
            if (kIsWeb) {
              mimeType = lookupMimeType(file.name);
            } else {
              mimeType = lookupMimeType(file.path!);
            }

            MessageType messageType = MessageType.file;
            if (mimeType != null) {
              if (mimeType.startsWith('image/')) {
                messageType = MessageType.image;
              } else if (mimeType.startsWith('video/')) {
                messageType = MessageType.video;
              } else if (mimeType.startsWith('audio/')) {
                messageType = MessageType.audio;
              }
            }

            widget.onFilePicked!(file, messageType);
          }
        }
        break;
    }
  }
}
