import 'notification_model.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? subtitle;
  final String? avatarUrl;
  final String route;
  final String topic;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.topic,
    this.subtitle,
    this.avatarUrl,
  });

  factory AppNotification.fromNotificationInfo(NotificationInfo notification) {
    return AppNotification(
      id: notification.identityKey,
      title: notification.title,
      body: notification.content,
      subtitle: notification.meta['subtitle'] as String?,
      avatarUrl:
          notification.meta['avatar_url'] as String? ??
          notification.meta['avatar'] as String?,
      route: routeFor(notification),
      topic: notification.event,
    );
  }

  static String routeFor(NotificationInfo notification) {
    final actionUri = notification.meta['action_uri'];
    if (actionUri is String) {
      if (actionUri.startsWith('touchfish://')) {
        final route = actionUri.substring('touchfish://'.length);
        return route.startsWith('/') ? route : '/$route';
      }
      if (actionUri.startsWith('/')) return actionUri;
    }

    if (notification.isMessageEvent) {
      final roomId = notification.roomId?.isNotEmpty == true
          ? notification.roomId!
          : notification.groupId != null
          ? 'G${notification.groupId}'
          : notification.senderUid != null
          ? 'U${notification.senderUid}'
          : null;
      if (roomId != null) return '/chat/$roomId';
    }
    if (notification.isAnnouncementEvent) return '/announcement';
    if (notification.isForumEvent) {
      if (notification.event == 'forum.review.pending') {
        return '/admin/pending-forums';
      }
      final fid = (notification.meta['fid'] as num?)?.toInt();
      final pid = (notification.meta['pid'] as num?)?.toInt();
      if (notification.event == 'forum.post.deleted' && fid != null) {
        return '/forum/$fid';
      }
      if (fid != null && pid != null) return '/forum/$fid/post/$pid';
      if (fid != null) return '/forum/$fid';
      return '/forum';
    }
    return '/account';
  }
}
