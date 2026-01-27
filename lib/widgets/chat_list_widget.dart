import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/chat_model.dart';
import '../l10n/app_localizations.dart';

class ChatListWidget extends StatelessWidget {
  final List<ChatRoom> chatRooms;

  const ChatListWidget({
    super.key,
    required this.chatRooms,
  });

  @override
  Widget build(BuildContext context) {
    final pinnedRooms = chatRooms.where((room) => room.isPinned).toList();
    final unpinnedRooms = chatRooms.where((room) => !room.isPinned).toList();

    return ListView(
      children: [
        if (pinnedRooms.isNotEmpty) ...[
          _buildPinnedSection(context, pinnedRooms),
          const Divider(height: 1),
        ],
        ...unpinnedRooms.map((room) => _buildChatRoomTile(context, room)),
      ],
    );
  }

  Widget _buildPinnedSection(BuildContext context, List<ChatRoom> rooms) {
    final l10n = AppLocalizations.of(context)!;
    
    return ExpansionTile(
      title: Text(l10n.chatPinned),
      leading: const Icon(Icons.push_pin),
      initiallyExpanded: true,
      children: rooms.map((room) => _buildChatRoomTile(context, room)).toList(),
    );
  }

  Widget _buildChatRoomTile(BuildContext context, ChatRoom room) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return ListTile(
      leading: _buildAvatar(context, room),
      title: Text(
        room.name,
        style: TextStyle(
          fontWeight: room.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: room.lastMessage != null
          ? Text(
              room.lastMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: room.unreadCount > 0
                    ? colorScheme.onSurface
                    : colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (room.lastMessageTime != null)
            Text(
              _formatTime(room.lastMessageTime!, context),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          if (room.unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 20),
              child: Text(
                room.unreadCount > 99 ? '99+' : room.unreadCount.toString(),
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
      onTap: () {
        context.go('/chat/${room.id}');
      },
    );
  }

  Widget _buildAvatar(BuildContext context, ChatRoom room) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return CircleAvatar(
      backgroundColor: colorScheme.primaryContainer,
      child: room.avatar != null
          ? null
          : Icon(
              room.type == ChatType.direct ? Icons.person : Icons.group,
              color: colorScheme.onPrimaryContainer,
            ),
    );
  }

  String _formatTime(DateTime time, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays == 0) {
      // 今天显示时间
      return DateFormat('HH:mm').format(time);
    } else if (difference.inDays == 1) {
      // 昨天就是昨天
      return l10n.chatYesterday;
    } else if (difference.inDays < 7) {
      // 一周内显示星期
      return DateFormat.E(Localizations.localeOf(context).toString()).format(time);
    } else {
      // 超过一周显示日期
      return DateFormat('MM/dd').format(time);
    }
  }
}
