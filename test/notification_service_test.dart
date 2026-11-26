import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/services/notification_service.dart';

void main() {
  test('category unread count checks each readAt independently', () {
    final notifications = [
      _notification(id: 1, timeStamp: 10, readAt: null),
      _notification(id: 2, timeStamp: 20, readAt: 30),
      _notification(id: 3, timeStamp: 5, readAt: null),
    ];

    expect(NotificationService.categoryUnreadCount(notifications), 2);
  });

  test('mark read helpers select and update only unread IDs', () {
    final notifications = [
      _notification(id: 1, timeStamp: 10, readAt: null),
      _notification(id: 2, timeStamp: 20, readAt: 25),
      _notification(id: 3, timeStamp: 30, readAt: null),
      _notification(id: -1, timeStamp: 40, readAt: null),
    ];

    final ids = NotificationService.unreadNotificationIds([
      notifications[0],
      notifications[1],
    ]);
    expect(ids, [1]);

    final updated = NotificationService.applyReadAtByIds(
      notifications,
      ids,
      100,
    );
    expect(updated, 1);
    expect(notifications[0].readAt, 100);
    expect(notifications[1].readAt, 25);
    expect(notifications[2].readAt, isNull);
    expect(notifications[3].readAt, isNull);
  });

  test('logout resets the session so re-login performs a full reload', () {
    final service = NotificationService.instance;
    service.debugSeedSession(
      uid: 7,
      baseUrl: 'https://example.test',
      fetchTime: 1234,
    );
    service.debugReplaceNotifications([
      _notification(id: 1, timeStamp: 1, readAt: null),
    ], unreadCount: 5);
    expect(service.debugNeedsFullReload, isFalse);
    expect(service.unreadCount, 5);

    service.stopPolling();

    expect(service.debugActiveUid, isNull);
    expect(service.debugLastFetchTime, 0);
    expect(service.debugNeedsFullReload, isTrue);
    expect(service.unreadCount, 0);

    service.debugReplaceNotifications(const []);
  });

  test('group notifications are correctly categorized', () {
    final service = NotificationService.instance;
    service.debugReplaceNotifications([
      _groupNotification(id: 11, event: 'group.admin.added', title: '你已成为群管理员'),
      _groupNotification(id: 12, event: 'group.left', title: '已退出群聊'),
      _groupNotification(id: 13, event: 'group.member.removed', title: '你已被移出群聊'),
      _notification(id: 14, timeStamp: 5, readAt: null),
    ]);

    expect(
      service.groupNotifications.map((n) => n.id),
      containsAll([11, 12, 13]),
    );
    expect(service.groupUnreadCount, 3);
    expect(service.systemNotifications.map((n) => n.id), isNot(contains(11)));
    expect(service.systemNotifications.map((n) => n.id), contains(14));

    service.debugReplaceNotifications(const []);
  });

  test('group invitations still belong to the group category', () {
    final service = NotificationService.instance;
    service.debugReplaceNotifications([
      _groupNotification(id: 21, event: 'group.invited', title: '邀请你加入群聊'),
      _groupNotification(id: 22, event: 'group.join.request', title: '入群申请'),
    ]);

    expect(service.groupNotifications.length, 2);
    expect(service.inviteNotifications.length, 2);

    service.debugReplaceNotifications(const []);
  });

  test('ephemeral essence/pinned notifications do not appear in the notification center and are not counted as unread', () {
    final service = NotificationService.instance;
    service.debugReplaceNotifications([
      _groupNotification(id: 31, event: 'group.essence.add', title: '消息被设定精华'),
      _groupNotification(id: 32, event: 'group.essence.remove', title: '消息被移除精华'),
      _groupNotification(id: 34, event: 'messages.pinned', title: '消息已置顶'),
      _groupNotification(id: 35, event: 'messages.unpinned', title: '消息置顶已取消'),
      _notification(id: 33, timeStamp: 9, readAt: null),
    ]);

    expect(service.allNotifications.map((n) => n.id), [33]);
    expect(service.groupNotifications, isEmpty);
    expect(service.groupUnreadCount, 0);
    for (final category in [
      service.systemNotifications,
      service.friendNotifications,
      service.announcementNotifications,
      service.inviteNotifications,
      service.forumNotifications,
      service.groupNotifications,
    ]) {
      expect(category.where((n) => n.isTransientEvent), isEmpty);
    }

    service.debugReplaceNotifications(const []);
  });
}

NotificationInfo _notification({
  required int id,
  required double timeStamp,
  required double? readAt,
}) => NotificationInfo(
  id: id,
  timeStamp: timeStamp,
  readAt: readAt,
  event: 'announcement.created',
  title: 'title',
  content: 'content',
);

NotificationInfo _groupNotification({
  required int id,
  required String event,
  required String title,
}) => NotificationInfo(
  id: id,
  timeStamp: id.toDouble(),
  event: event,
  title: title,
  content: 'content',
  meta: const {'gid': 9},
);
