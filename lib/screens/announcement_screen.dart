import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/announcement_model.dart';
import '../models/notification_model.dart';
import '../services/api/tf_api_client.dart';
import '../services/auth_state.dart';
import '../services/notification_service.dart';
import '../utils/talker.dart';

class AnnouncementScreen extends StatefulWidget {
  const AnnouncementScreen({super.key});

  @override
  State<AnnouncementScreen> createState() => _AnnouncementScreenState();
}

class _AnnouncementScreenState extends State<AnnouncementScreen> {
  List<Announcement>? _announcements;
  bool _isLoading = true;
  String? _error;
  final _notificationService = NotificationService.instance;

  @override
  void initState() {
    super.initState();
    _notificationService.addListener(_onNotificationsChanged);
    _load();
  }

  @override
  void dispose() {
    _notificationService.removeListener(_onNotificationsChanged);
    super.dispose();
  }

  void _onNotificationsChanged() {
    if (mounted) setState(() {});
  }

  int get _badgeCount => _notificationService.announcementUnreadCount;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await TfApiClient.instance.getAnnouncements();
      await _resolveSenderNames(list);
      if (mounted) {
        setState(() {
          _announcements = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      talker.error('AnnouncementScreen: load failed', e);
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resolveSenderNames(List<Announcement> list) async {
    final uids = list.map((a) => a.sender).toSet().toList();
    final futures = uids.map((uid) => TfApiClient.instance.getUserByUid(uid));
    final profiles = await Future.wait(futures);
    final nameMap = <int, String>{};
    for (final p in profiles) {
      if (p != null) nameMap[int.parse(p.uid)] = p.username;
    }
    for (final a in list) {
      final name = nameMap[a.sender];
      if (name != null) {
        final idx = list.indexOf(a);
        list[idx] = a.copyWith(senderName: name);
      }
    }
  }

  bool get _isAdmin =>
      AuthState.instance.currentUser?.hasAdminAccess ?? false;

  Future<void> _showCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.announcementCreate),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: l10n.announcementCreateHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final content = controller.text.trim();
    if (mounted) {
      if (content.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.announcementCreateEmpty)),
        );
        return;
      }
      final uid = AuthState.instance.uid;
      final password = AuthState.instance.password;
      if (uid == null || password == null) return;
      final success = await TfApiClient.instance.createAnnouncement(
        uid,
        password,
        content,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? l10n.announcementCreateSuccess
                : l10n.announcementCreateFailed),
          ),
        );
        if (success) _load();
      }
    }
  }

  Future<void> _confirmDelete(Announcement a) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.announcementDeleteConfirm),
        content: Text(
          a.content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(l10n.confirm),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final uid = AuthState.instance.uid;
    final password = AuthState.instance.password;
    if (uid == null || password == null) return;
    final success = await TfApiClient.instance.deleteAnnouncement(
      uid,
      password,
      a.timeStamp,
    );
    if (mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success
              ? l10n.announcementDeleteSuccess
              : l10n.announcementDeleteFailed),
        ),
      );
      if (success) _load();
    }
  }

  void _showNotificationList() {
    _notificationService.markAnnouncementRead();
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _AnnouncementNotificationSheet(l10n: l10n),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isNarrow = MediaQuery.of(context).size.width < 600;
    final badgeCount = _badgeCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.announcementTitle),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: l10n.notificationTabNotifications,
                onPressed: _showNotificationList,
              ),
              if (badgeCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 14),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? Padding(
              padding: EdgeInsets.only(bottom: isNarrow ? 80.0 : 0.0),
              child: FloatingActionButton(
                onPressed: _showCreateDialog,
                child: const Icon(Icons.add),
              ),
            )
          : null,
      body: _buildAnnouncementList(l10n),
    );
  }

  Widget _buildAnnouncementList(AppLocalizations l10n) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: _load,
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    final list = _announcements;
    if (list == null || list.isEmpty) {
      return Center(child: Text(l10n.announcementNoAnnouncements));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: list.length,
        itemBuilder: (context, index) => _AnnouncementCard(
          announcement: list[index],
          isAdmin: _isAdmin,
          onDelete: () => _confirmDelete(list[index]),
        ),
      ),
    );
  }
}

class _AnnouncementNotificationSheet extends StatelessWidget {
  final AppLocalizations l10n;

  const _AnnouncementNotificationSheet({required this.l10n});

  @override
  Widget build(BuildContext context) {
    final notifs = NotificationService.instance.announcementNotifications;
    final isLoading = NotificationService.instance.isLoading;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, left: 20, right: 16, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.notificationTabNotifications,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                  style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 64,
                              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              l10n.notificationEmpty,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          return _AnnouncementNotificationCard(
                            notification: notifs[index],
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final Announcement announcement;
  final bool isAdmin;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.isAdmin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final senderLabel = announcement.senderName ?? 'User ${announcement.sender}';
    final timeLabel = _formatTime(announcement.dateTime);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onLongPress: isAdmin ? onDelete : null,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.campaign_outlined,
                      size: 24, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    senderLabel,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                announcement.content,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _AnnouncementNotificationCard extends StatelessWidget {
  final NotificationInfo notification;

  const _AnnouncementNotificationCard({required this.notification});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timeLabel = _formatTime(notification.dateTime);
    final isEdited = notification.event == 'announcement.edited';
    final isDeleted = notification.event == 'announcement.deleted';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isDeleted
                      ? Icons.delete_outline
                      : isEdited
                          ? Icons.edit_notifications
                          : Icons.campaign,
                  size: 16,
                  color: isDeleted
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    notification.title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDeleted
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),
                Text(
                  timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.content,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
