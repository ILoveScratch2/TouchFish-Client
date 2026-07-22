import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_symbols_icons/symbols.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import 'mention_text_field.dart';

class ChatInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final Function(PlatformFile file, MessageType type)? onFilePicked;
  final List<MentionUser> mentionUsers;

  const ChatInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onFilePicked,
    this.mentionUsers = const [],
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
