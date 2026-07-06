import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../services/chat_data_service.dart';
import '../widgets/sheet_scaffold.dart';
import 'chat_search_messages_screen.dart';

class ChatRoomSettingsScreen extends StatefulWidget {
  final ChatRoom chatRoom;

  const ChatRoomSettingsScreen({super.key, required this.chatRoom});

  @override
  State<ChatRoomSettingsScreen> createState() => _ChatRoomSettingsScreenState();
}

class _ChatRoomSettingsScreenState extends State<ChatRoomSettingsScreen> {
  final ChatDataService _chatData = ChatDataService.instance;
  late bool _isPinned;
  late int _notifyLevel;
  late String _chatName;
  late String _chatDescription;

  int? get _targetUid => widget.chatRoom.id.startsWith('U')
      ? int.tryParse(widget.chatRoom.id.substring(1))
      : null;

  @override
  void initState() {
    super.initState();
    final prefs = _chatData.getRoomPreference(widget.chatRoom.id);
    _isPinned = prefs.isPinned || widget.chatRoom.isPinned;
    _notifyLevel = prefs.notifyLevel;
    _chatName = prefs.alias.trim().isNotEmpty ? prefs.alias : widget.chatRoom.name;
    _chatDescription = prefs.description;
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
              background: Container(color: colorScheme.surfaceContainerHighest),
              title: Text(_chatName),
            ),
            actions: [
              if (_targetUid != null)
                IconButton(
                  icon: const Icon(Symbols.person),
                  onPressed: _openUserProfile,
                  tooltip: _chatName,
                ),
              IconButton(
                icon: const Icon(Symbols.edit),
                onPressed: _showEditChatSheet,
                tooltip: l10n.chatRoomEdit,
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: _showEditChatSheet,
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
                  _chatData.updateRoomPreference(widget.chatRoom.id, isPinned: value);
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
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: const Icon(Symbols.notifications),
                trailing: const Icon(Symbols.chevron_right),
                title: Text(l10n.chatNotifyLevel),
                subtitle: Text(_getNotifyLevelText()),
                onTap: _showNotifyLevelBottomSheet,
              ),
              const Divider(height: 1),
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
                      builder: (context) =>
                          ChatSearchMessagesScreen(roomId: widget.chatRoom.id),
                    ),
                  );
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
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                _chatData.updateRoomPreference(widget.chatRoom.id, notifyLevel: 0);
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
                _chatData.updateRoomPreference(widget.chatRoom.id, notifyLevel: 1);
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
                _chatData.updateRoomPreference(widget.chatRoom.id, notifyLevel: 2);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _openUserProfile() {
    final targetUid = _targetUid;
    if (targetUid == null) return;
    context.push('/user/$targetUid');
  }

  void _showEditChatSheet() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: _chatName);
    final descController = TextEditingController(text: _chatDescription);

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
                  labelText: l10n.chatRoomAlias,
                  border: const OutlineInputBorder(),
                  helperText: l10n.chatRoomAliasHelp,
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
                  onPressed: () async {
                    final navigator = Navigator.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final alias = nameController.text.trim();
                    final description = descController.text.trim();
                    await _chatData.updateRoomPreference(
                      widget.chatRoom.id,
                      alias: alias,
                      description: description,
                    );
                    if (!mounted) return;
                    setState(() {
                      _chatName = _chatData.displayNameForRoom(
                        widget.chatRoom.id,
                        widget.chatRoom.name,
                      );
                      _chatDescription = description;
                    });
                    navigator.pop();
                    messenger.showSnackBar(
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
    ).whenComplete(() {
      nameController.dispose();
      descController.dispose();
    });
  }
}
