import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:go_router/go_router.dart';
import '../l10n/app_localizations.dart';
import '../models/chat_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/chat_data_service.dart';
import '../services/chat_ws_service.dart';
import '../services/auth_state.dart';
import '../widgets/chat_list_widget.dart';
import '../widgets/contact_list_widget.dart';
import '../widgets/invite_sheet.dart';
import '../widgets/text_entry_dialog.dart';
import '../services/notification_service.dart';
import 'chat_detail_screen.dart';
import 'group_create_screen.dart';

class ChatShellScreen extends StatefulWidget {
  final Widget child;

  const ChatShellScreen({super.key, required this.child});

  @override
  State<ChatShellScreen> createState() => _ChatShellScreenState();
}

class _ChatShellScreenState extends State<ChatShellScreen> {
  static const String _dividerPositionKey = 'chat_divider_position';
  static const String _collapsedStateKey = 'chat_list_collapsed';
  static const double _collapsedWidth = 64.0;
  static const double _minSidebarWidth = 260.0;
  static const double _maxSidebarWidth = 520.0;
  static const double _collapseThreshold = 210.0;

  double _leftFlex = 2.0;
  double _rightFlex = 4.0;
  bool _isHovering = false;
  bool _isCollapsed = false;
  double _sidebarWidth = 320.0;

  @override
  void initState() {
    super.initState();
    _loadDividerPosition();
  }

  Future<void> _loadDividerPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRatio = prefs.getDouble(_dividerPositionKey);
    final savedCollapsed = prefs.getBool(_collapsedStateKey) ?? false;
    final savedWidth = prefs.getDouble('chat_sidebar_width') ?? 320.0;

    if (mounted) {
      setState(() {
        _isCollapsed = savedCollapsed;
        _sidebarWidth = savedWidth;
        if (savedRatio != null) {
          _leftFlex = savedRatio;
          _rightFlex = 1.0 - savedRatio;
        }
      });
    }
  }

  Future<void> _saveDividerPosition() async {
    final prefs = await SharedPreferences.getInstance();
    final ratio = _leftFlex / (_leftFlex + _rightFlex);
    await prefs.setDouble(_dividerPositionKey, ratio);
    await prefs.setBool(_collapsedStateKey, _isCollapsed);
    await prefs.setDouble('chat_sidebar_width', _sidebarWidth);
  }

  void _updateDividerPosition(double dx, double totalWidth) {
    if (_isCollapsed) {
      setState(() {
        _isCollapsed = false;
        _sidebarWidth = _minSidebarWidth;
      });
    }

    final next = (_sidebarWidth + dx).clamp(
      _collapseThreshold,
      _maxSidebarWidth,
    );
    setState(() {
      _sidebarWidth = next;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      final currentWidth = _isCollapsed ? _collapsedWidth : _sidebarWidth;

      return Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: currentWidth,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 0, 16),
                child: MouseRegion(
                  onEnter: (_) {
                    setState(() {
                      _isHovering = true;
                    });
                  },
                  onExit: (_) {
                    setState(() {
                      _isHovering = false;
                    });
                  },
                  child: ChatListScreen(
                    isAside: true,
                    isCollapsed: _isCollapsed,
                    isHovering: _isHovering,
                    onToggleCollapse: () {
                      setState(() {
                        _isCollapsed = !_isCollapsed;
                      });
                      _saveDividerPosition();
                    },
                    onDragUpdate: (dx) {
                      _updateDividerPosition(
                        dx,
                        MediaQuery.of(context).size.width,
                      );
                    },
                    onDragEnd: () {
                      if (_sidebarWidth <= _collapseThreshold) {
                        setState(() {
                          _isCollapsed = true;
                          _sidebarWidth = _minSidebarWidth;
                        });
                      }
                      _saveDividerPosition();
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return widget.child is ChatDetailScreen
        ? widget.child
        : const ChatListScreen(
            isAside: false,
            isCollapsed: false,
            isHovering: false,
          );
  }
}

class ChatListScreen extends StatefulWidget {
  final bool isAside;
  final bool isCollapsed;
  final bool isHovering;
  final VoidCallback? onToggleCollapse;
  final Function(double)? onDragUpdate;
  final VoidCallback? onDragEnd;

  const ChatListScreen({
    super.key,
    this.isAside = false,
    this.isCollapsed = false,
    this.isHovering = false,
    this.onToggleCollapse,
    this.onDragUpdate,
    this.onDragEnd,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  static int _lastSelectedTab = 0;

  late TabController _tabController;
  final ChatDataService _chatData = ChatDataService.instance;
  final NotificationService _notificationService = NotificationService.instance;

  List<ChatRoom> get _chatRooms => _chatData.rooms;
  List<Contact> get _contacts => _chatData.contacts;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _lastSelectedTab,
    );
    _tabController.addListener(() {
      _lastSelectedTab = _tabController.index;
      setState(() {});
    });
    _chatData.addListener(_onDataChanged);
    _notificationService.addListener(_onDataChanged);
    AuthState.instance.addListener(_onAuthChanged);
    _initRealData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatData.removeListener(_onDataChanged);
    _notificationService.removeListener(_onDataChanged);
    AuthState.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
    if (AuthState.instance.isLoggedIn) {
      _initRealData();
    } else {
      _chatData.reset();
      ChatWsService.instance.disconnect();
    }
  }

  Future<void> _initRealData() async {
    if (AuthState.instance.isLoggedIn) {
      try {
        await TfApiClient.instance.getBaseUrl();
      } catch (_) {
        return;
      }
      if (!AuthState.instance.isLoggedIn) return;
      _chatData.init();
      ChatWsService.instance.connect();
    }
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

    if (widget.isCollapsed) {
      return Card(
        margin: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Stack(
            children: [
              Column(children: [Expanded(child: _buildCollapsedView(context))]),
              // 拖动区
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      widget.onDragUpdate?.call(details.delta.dx);
                    },
                    onHorizontalDragEnd: (_) {
                      widget.onDragEnd?.call();
                    },
                    child: const SizedBox(width: 10),
                  ),
                ),
              ),
              // 展折
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  ignoring: !widget.isHovering,
                  child: AnimatedOpacity(
                    opacity: widget.isHovering ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: AnimatedSlide(
                      offset: widget.isHovering
                          ? Offset.zero
                          : const Offset(0.25, 0),
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: Center(
                        child: Material(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          child: InkWell(
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(10),
                            ),
                            onTap: widget.onToggleCollapse,
                            child: Tooltip(
                              message: widget.isCollapsed
                                  ? l10n.chatListExpand
                                  : l10n.chatListCollapse,
                              child: SizedBox(
                                width: 36,
                                height: 36,
                                child: Icon(
                                  widget.isCollapsed
                                      ? Symbols.left_panel_open
                                      : Symbols.left_panel_close,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Stack(
          children: [
            Column(
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
                      child: _buildInviteButton(context, l10n),
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
            // FAB
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.small(
                heroTag: 'chat-fab',
                onPressed: () => _showAddMenu(context),
                child: const Icon(Icons.add),
              ),
            ),
            // 拖动区
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    widget.onDragUpdate?.call(details.delta.dx);
                  },
                  onHorizontalDragEnd: (_) {
                    widget.onDragEnd?.call();
                  },
                  child: const SizedBox(width: 10),
                ),
              ),
            ),
            // 展折
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !widget.isHovering,
                child: AnimatedOpacity(
                  opacity: widget.isHovering ? 1 : 0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  child: AnimatedSlide(
                    offset: widget.isHovering
                        ? Offset.zero
                        : const Offset(0.25, 0),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Center(
                      child: Material(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(10),
                        ),
                        child: InkWell(
                          borderRadius: const BorderRadius.horizontal(
                            left: Radius.circular(10),
                          ),
                          onTap: widget.onToggleCollapse,
                          child: Tooltip(
                            message: widget.isCollapsed
                                ? l10n.chatListExpand
                                : l10n.chatListCollapse,
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                widget.isCollapsed
                                    ? Symbols.left_panel_open
                                    : Symbols.left_panel_close,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsedView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = _tabController.index == 0 ? _chatRooms : [];
    final contactItems = _tabController.index == 1 ? _contacts : [];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        for (final room in items.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: IconButton(
              tooltip: room.name,
              onPressed: () {
                context.go('/chat/${room.id}');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              splashRadius: 24,
              icon: Stack(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: colorScheme.primaryContainer,
                    backgroundImage: room.avatar != null
                        ? NetworkImage(room.avatar!)
                        : null,
                    child: room.avatar == null
                        ? Icon(
                            room.type == ChatType.direct
                                ? Icons.person
                                : Icons.group,
                            color: colorScheme.onPrimaryContainer,
                            size: 18,
                          )
                        : null,
                  ),
                  if (room.unreadCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Center(
                          child: Text(
                            room.unreadCount > 99
                                ? '99+'
                                : room.unreadCount.toString(),
                            style: TextStyle(
                              color: colorScheme.onError,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        for (final contact in contactItems.take(10))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: IconButton(
              tooltip: contact.name,
              onPressed: () {
                final userId = contact.id.startsWith('U')
                    ? contact.id.substring(1)
                    : contact.id;
                context.go('/user/$userId');
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              splashRadius: 24,
              icon: CircleAvatar(
                radius: 18,
                backgroundColor: colorScheme.primaryContainer,
                backgroundImage: contact.avatar != null
                    ? NetworkImage(contact.avatar!)
                    : null,
                child: contact.avatar == null
                    ? Icon(
                        Icons.person,
                        color: colorScheme.onPrimaryContainer,
                        size: 18,
                      )
                    : null,
              ),
            ),
          ),
      ],
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
                IconTheme(
                  data: IconThemeData(color: appbarFeColor),
                  child: _buildInviteButton(context, l10n),
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

  Widget _buildInviteButton(BuildContext context, AppLocalizations l10n) {
    final unread = _notificationService.inviteUnreadCount;
    return IconButton(
      icon: unread > 0
          ? Badge(
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.mail_outline),
            )
          : const Icon(Icons.mail_outline),
      onPressed: () => _showInviteSheet(context),
      tooltip: l10n.chatInvites,
    );
  }

  Future<void> _createGroup() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const GroupCreateScreen()),
    );
    if (result == true) {
      _chatData.loadContactsAndRooms();
    }
  }

  void _showAddMenu(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(l10n.chatAddFriend),
              onTap: () {
                Navigator.pop(ctx);
                _showAddFriendDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add),
              title: Text(l10n.chatCreateGroup),
              onTap: () {
                Navigator.pop(ctx);
                _createGroup();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddFriendDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => TextEntryDialog(
        title: l10n.chatAddFriend,
        hintText: l10n.chatAddFriendHint,
        cancelLabel: l10n.cancel,
        confirmLabel: l10n.confirm,
        icon: Icons.search,
      ),
    );
    if (input == null || !mounted) return;

    final parsedUid = int.tryParse(input);
    final profile = parsedUid != null
        ? await TfApiClient.instance.getUserByUid(parsedUid)
        : await TfApiClient.instance.getUserByUsername(input);
    if (!mounted) return;
    final targetUid = profile == null ? null : int.tryParse(profile.uid);
    if (targetUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.commonUserNotFound),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    context.push('/user/$targetUid');
  }
}
