import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../widgets/chat_list_widget.dart';
import '../widgets/contact_list_widget.dart';
import '../widgets/invite_sheet.dart';

class ChatShellScreen extends StatelessWidget {
  final Widget child;
  
  const ChatShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            Flexible(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: const ChatListScreen(
                  isAside: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return const ChatListScreen(
      isAside: false,
    );
  }
}

class ChatListScreen extends StatefulWidget {
  final bool isAside;
  
  const ChatListScreen({
    super.key,
    this.isAside = false,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  static int _lastSelectedTab = 0;
  
  late TabController _tabController;
  final List<ChatRoom> _chatRooms = ChatDemoData.getDemoChatRooms();
  final List<Contact> _contacts = ChatDemoData.getDemoContacts();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: _lastSelectedTab);
    _tabController.addListener(() {
      _lastSelectedTab = _tabController.index;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAside) {
      return _buildAsideView(context);
    }
    
    return _buildFullScreenView(context);
  }

  Widget _buildAsideView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Card(
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    dividerColor: Colors.transparent,
                    controller: _tabController,
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    tabs: [
                      Tab(icon: Icon(Icons.chat)),
                      Tab(icon: Icon(Icons.contacts)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    icon: const Icon(Icons.mail_outline),
                    onPressed: () => _showInviteSheet(context),
                    tooltip: l10n.chatInvites,
                  ),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  ChatListWidget(chatRooms: _chatRooms),
                  ContactListWidget(contacts: _contacts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullScreenView(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final appbarFeColor = colorScheme.onSurface;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          height: 48,
          margin: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 4 + MediaQuery.of(context).padding.top,
            bottom: 4,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.chat,
                          fill: _tabController.index == 0 ? 1 : 0,
                        ),
                        color: appbarFeColor,
                        onPressed: () => _tabController.animateTo(0),
                        tooltip: l10n.chatTabMessages,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(
                          Icons.contacts,
                          fill: _tabController.index == 1 ? 1 : 0,
                        ),
                        color: appbarFeColor,
                        onPressed: () => _tabController.animateTo(1),
                        tooltip: l10n.chatTabContacts,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mail_outline),
                  color: appbarFeColor,
                  onPressed: () => _showInviteSheet(context),
                  tooltip: l10n.chatInvites,
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          ChatListWidget(chatRooms: _chatRooms),
          ContactListWidget(contacts: _contacts),
        ],
      ),
    );
  }

  void _showInviteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const InviteSheet(),
    );
  }
}

class ChatDetailScreen extends StatelessWidget {
  const ChatDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
    );
  }
}
