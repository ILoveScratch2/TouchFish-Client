import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../widgets/sheet_scaffold.dart';
import 'chat_search_messages_screen.dart';
import 'user_profile_screen.dart';

class ChatRoomSettingsScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomSettingsScreen({
    super.key,
    required this.chatRoom,
  });

  @override
  State<ChatRoomSettingsScreen> createState() => _ChatRoomSettingsScreenState();
}

class _ChatRoomSettingsScreenState extends State<ChatRoomSettingsScreen> {
  late bool _isPinned;
  int _notifyLevel = 0; // 0: All, 1: Mention, 2: None
  late String _chatName;
  String _chatDescription = "";
  late bool _hasEditPermission; // 随机的，反正没接后端
  late bool _isGroupChat;

  @override
  void initState() {
    super.initState();
    _isPinned = widget.chatRoom.isPinned;
    _chatName = widget.chatRoom.name;
    _isGroupChat = widget.chatRoom.type == ChatType.group;
    _hasEditPermission = DateTime.now().second % 2 == 0;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: colorScheme.surfaceContainerHighest,
              ),
              title: Text(
                _chatName,
              // Pin/Unpin Switch
                  ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Symbols.group),
                onPressed: () {
                  _showMembersBottomSheet();
                },
                tooltip: l10n.chatRoomMembers,
              ),
              IconButton(
                icon: const Icon(Symbols.edit),
                onPressed: () {
                  _showEditChatSheet();
                },
                tooltip: l10n.chatRoomEdit,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => _showEditChatSheet(),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _chatDescription.isEmpty 
                        ? l10n.chatRoomNoDescription 
                        : _chatDescription,
                      style: TextStyle(
                        fontSize: 16,
                        color: _chatDescription.isEmpty 
                          ? colorScheme.onSurfaceVariant 
                          : colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // Pin/Unpin Switch
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                secondary: Icon(
                  Symbols.push_pin,
                  color: colorScheme.onSurfaceVariant,
                ),
                title: Text(l10n.chatRoomPin),
                subtitle: Text(l10n.chatRoomPinDescription),
                value: _isPinned,
                onChanged: (value) {
                  setState(() {
                    _isPinned = value;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        value ? l10n.chatRoomPinned : l10n.chatRoomUnpinned,
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              // Notification Level
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Symbols.notifications),
                trailing: const Icon(Symbols.chevron_right),
                title: Text(l10n.chatNotifyLevel),
                subtitle: Text(_getNotifyLevelText()),
                onTap: () {
                  _showNotifyLevelBottomSheet();
                },
              ),
              const Divider(height: 1),

              // Search Messages
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Symbols.search),
                trailing: const Icon(Symbols.chevron_right),
                title: Text(l10n.chatSearchMessages),
                subtitle: Text(l10n.chatSearchMessagesDescription),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatSearchMessagesScreen(
                        roomId: widget.chatRoom.id,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),

              // Leave Chat
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(
                  Symbols.exit_to_app,
                  color: colorScheme.error,
                ),
                title: Text(
                  l10n.chatLeaveRoom,
                  style: TextStyle(color: colorScheme.error),
                ),
                subtitle: Text(l10n.chatLeaveRoomDescription),
                onTap: () {
                  _showLeaveConfirmDialog();
                },
              ),
            ]),
          ),
        ],
      ),
    );
  }

  String _getNotifyLevelText() {
    final l10n = AppLocalizations.of(context)!;
    switch (_notifyLevel) {
      case 0:
        return l10n.chatNotifyLevelAll;
      case 1:
        return l10n.chatNotifyLevelMention;
      case 2:
        return l10n.chatNotifyLevelNone;
      default:
        return l10n.chatNotifyLevelAll;
    }
  }

  void _showNotifyLevelBottomSheet() {
    final l10n = AppLocalizations.of(context)!;
    
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chatNotifyLevel,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text(l10n.chatNotifyLevelAll),
              subtitle: Text(l10n.chatNotifyLevelAllDescription),
              leading: const Icon(Symbols.notifications_active),
              selected: _notifyLevel == 0,
              onTap: () {
                setState(() {
                  _notifyLevel = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.chatNotifyLevelMention),
              subtitle: Text(l10n.chatNotifyLevelMentionDescription),
              leading: const Icon(Symbols.alternate_email),
              selected: _notifyLevel == 1,
              onTap: () {
                setState(() {
                  _notifyLevel = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(l10n.chatNotifyLevelNone),
              subtitle: Text(l10n.chatNotifyLevelNoneDescription),
              leading: const Icon(Symbols.notifications_off),
              selected: _notifyLevel == 2,
              onTap: () {
                setState(() {
                  _notifyLevel = 2;
                });
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showMembersBottomSheet() {
    final l10n = AppLocalizations.of(context)!;
    
    // Demo data
    final demoMembers = [
      {'id': '1', 'name': 'XSFX', 'status': 'online'},
      {'id': '3', 'name': 'Piaoztsdy', 'status': 'offline'},
      {'id': '4', 'name': 'JohnChiao', 'status': 'online'},
      {'id': '2', 'name': 'L3', 'status': 'away'},
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            children: [
              Text(
                l10n.chatRoomMembers,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: demoMembers.length,
                  itemBuilder: (context, index) {
                    final member = demoMembers[index];
                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            child: Icon(
                              Icons.person,
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: member['status'] == 'online'
                                    ? Colors.green
                                    : member['status'] == 'away'
                                        ? Colors.orange
                                        : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(member['name']!),
                      subtitle: Text(member['status']!),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => UserProfileScreen(
                              userId: member['id']!,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditChatSheet() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: _chatName);
    final descController = TextEditingController(text: _chatDescription);
    String nameLabel;
    String nameHelp;
    if (_hasEditPermission) {
      nameLabel = _isGroupChat ? l10n.chatRoomName : l10n.chatRoomContactName;
      nameHelp = l10n.chatRoomNameHelp;
    } else {
      nameLabel = l10n.chatRoomAlias;
      nameHelp = l10n.chatRoomAliasHelp;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetScaffold(
        titleText: l10n.chatRoomEdit,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: nameLabel,
                  border: const OutlineInputBorder(),
                  helperText: nameHelp,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: l10n.chatRoomDescription,
                  border: const OutlineInputBorder(),
                  helperText: l10n.chatRoomDescriptionHelp,
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (nameController.text.isNotEmpty) {
                        _chatName = nameController.text;
                      }
                      _chatDescription = descController.text;
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l10n.chatRoomUpdated),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Symbols.save),
                  label: Text(l10n.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLeaveConfirmDialog() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: EdgeInsets.zero,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Symbols.help_rounded,
              size: 48,
              fill: 1,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.chatLeaveRoom,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(l10n.chatLeaveRoomConfirm),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
              // 没有退出逻辑
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.chatRoomLeft),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: colorScheme.error,
            ),
            child: Text(l10n.leave),
          ),
        ],
      ),
    );
  }
}
