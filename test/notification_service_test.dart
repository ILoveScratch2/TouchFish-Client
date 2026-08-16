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
