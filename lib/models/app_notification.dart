import 'dart:convert';

import 'notification_model.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? subtitle;
  final String? avatarUrl;
  final String route;
  final String topic;
  final String? senderKey;
  final String? roomId;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.route,
    required this.topic,
    this.subtitle,
    this.avatarUrl,
    this.senderKey,
    this.roomId,
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
      senderKey: notification.senderRaw,
      roomId: roomIdFor(notification),
    );
  }

  bool get canReply =>
      roomId != null && topic.startsWith('message.') && topic != 'message.summary';

  String get payload => jsonEncode({
    'route': route,
    if (roomId != null) 'room_id': roomId,
  });

  AppNotification copyWith({String? avatarUrl}) => AppNotification(
    id: id,
    title: title,
    body: body,
    route: route,
    topic: topic,
    subtitle: subtitle,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    senderKey: senderKey,
    roomId: roomId,
  );

  static ({String route, String? roomId}) parsePayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final route = decoded['route'];
        final roomId = decoded['room_id'];
        if (route is String) {
          return (
            route: route,
            roomId: roomId is String && roomId.isNotEmpty ? roomId : null,
          );
        }
      }
    } catch (_) {}
    return (route: payload, roomId: null);
  }

  static String? roomIdFor(NotificationInfo notification) {
    if (!notification.isMessageEvent) return null;
    if (notification.roomId?.isNotEmpty == true) return notification.roomId;
    if (notification.groupId != null) return 'G${notification.groupId}';
    if (notification.senderUid != null) return 'U${notification.senderUid}';
    return null;
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
      final roomId = roomIdFor(notification);
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
