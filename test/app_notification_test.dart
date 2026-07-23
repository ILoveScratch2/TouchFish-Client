import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/app_notification.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/app_notification_service.dart';
import 'package:touchfish_client/widgets/notification_overlay.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  NotificationInfo notification({
    required String event,
    String? roomId,
    int? groupId,
    String? senderRaw,
    Map<String, dynamic> meta = const {},
  }) {
    return NotificationInfo(
      timeStamp: 1,
      event: event,
      title: 'Title',
      content: 'Body',
      roomId: roomId,
      groupId: groupId,
      senderRaw: senderRaw,
      meta: meta,
    );
  }

  group('AppNotification.routeFor', () {
    test('routes direct and group messages to their rooms', () {
      expect(
        AppNotification.routeFor(
          notification(event: 'message.plain', senderRaw: 'U12'),
        ),
        '/chat/U12',
      );
      expect(
        AppNotification.routeFor(
          notification(event: 'message.file', groupId: 8),
        ),
        '/chat/G8',
      );
    });

    test('routes forum notifications to the most specific destination', () {
      expect(
        AppNotification.routeFor(
          notification(
            event: 'forum.post.mentioned',
            meta: const {'fid': 3, 'pid': 9},
          ),
        ),
        '/forum/3/post/9',
      );
      expect(
        AppNotification.routeFor(
          notification(event: 'forum.post.deleted', meta: const {'fid': 3}),
        ),
        '/forum/3',
      );
    });

    test('uses explicit in-app action URI first', () {
      expect(
        AppNotification.routeFor(
          notification(
            event: 'announcement.created',
            meta: const {'action_uri': 'touchfish://forum/4'},
          ),
        ),
        '/forum/4',
      );
    });

    test('falls back by notification category', () {
      expect(
        AppNotification.routeFor(notification(event: 'announcement.created')),
        '/announcement',
      );
      expect(
        AppNotification.routeFor(notification(event: 'friend.request')),
        '/account',
      );
    });
  });

  testWidgets('in-app notification is rendered by the global overlay', (
    tester,
  ) async {
    AppNotificationService.instance.clear();
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const AppNotificationOverlay(),
          ],
        ),
        home: const SizedBox.expand(),
      ),
    );

    AppNotificationService.instance.showInAppTest(
      const AppNotification(
        id: 'overlay-test',
        title: 'Notification title',
        body: 'Notification body',
        route: '/account',
        topic: 'test',
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Notification title'), findsOneWidget);
    expect(find.text('Notification body'), findsOneWidget);
    expect(tester.takeException(), isNull);
    AppNotificationService.instance.clear();
    await tester.pump();
  });

  test('notification test actions honor global and chat settings', () async {
    const privateMessage = AppNotification(
      id: 'private-test',
      title: 'Private',
      body: 'Body',
      route: '/chat/U1',
      topic: 'message.private',
    );
    const groupMessage = AppNotification(
      id: 'group-test',
      title: 'Group',
      body: 'Body',
      route: '/chat/G1',
      topic: 'message.group',
    );

    await SettingsService.instance.setValue('inAppNotifications', false);
    expect(
      AppNotificationService.instance.canShowInApp(privateMessage),
      isFalse,
    );
    await SettingsService.instance.setValue('inAppNotifications', true);
    await SettingsService.instance.setValue('privateChat', false);
    expect(
      AppNotificationService.instance.canShowInApp(privateMessage),
      isFalse,
    );
    expect(AppNotificationService.instance.canShowInApp(groupMessage), isTrue);
    await SettingsService.instance.setValue('privateChat', true);
  });
}
