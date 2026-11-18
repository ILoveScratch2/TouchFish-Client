import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/app_notification.dart';
import 'package:touchfish_client/models/notification_level.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/app_notification_service.dart';
import 'package:touchfish_client/utils/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  AppNotificationService service() => AppNotificationService.instance;

  List<String> bodies() => service()
      .items
      .map((item) => item.notification.body)
      .toList(growable: false);

  AppNotification chat(String roomId, String body, int mid) => AppNotification(
    id: '$roomId:$mid',
    title: roomId,
    body: body,
    route: '/chat/$roomId',
    topic: 'message.private',
    senderKey: roomId,
    roomId: roomId,
  );

  setUp(() {
    service().clear();
    service().debugNotificationLevel = NotificationLevel.perSender;
  });

  tearDown(() {
    service().debugNotificationLevel = null;
    service().clear();
  });

  test('no old banners after dismissal', () async {
    await service().present(chat('U1', 'B', 1));
    expect(bodies(), ['B']);

    service().dismiss(service().items.first.notification.id);

    await service().present(chat('U2', 'C', 2));
    expect(bodies(), ['C'], reason: '旧会话 B 不应附在 C 上');

    await service().present(chat('U2', 'D', 3));
    expect(bodies(), ['D'], reason: '旧会话 B 不应附在 D 上');

    await service().present(chat('U2', 'E', 4));
    expect(bodies(), ['E'], reason: '旧会话 B 不应附在 E 上');
  });

  test('active conversations remain in the banner list', () async {
    await service().present(chat('U1', 'B', 1));
    await service().present(chat('U2', 'C', 2));
    expect(bodies(), ['B', 'C']);

    await service().present(chat('U1', 'B2', 3));
    expect(bodies(), ['B2', 'C']);
  });

  test('background accumulated conversations do not explode into banners upon resuming', () async {
    service().debugSetLifecycle(AppLifecycleState.paused);
    await service().present(chat('U1', 'B', 1));
    await service().present(chat('U2', 'C', 2));

    service().debugSetLifecycle(AppLifecycleState.resumed);
    await service().present(chat('U3', 'D', 3));

    expect(bodies(), ['D']);
  });

  test('summary banner resets count after dismissal', () async {
    service().debugNotificationLevel = NotificationLevel.minimal;
    await service().present(chat('U1', 'B', 1));
    expect(service().items.length, 1);

    service().dismiss(service().items.first.notification.id);
    await service().present(chat('U2', 'C', 2));

    final summary = service().items.single.notification;
    expect(summary.topic, 'message.summary');
    expect(
      summary.body,
      currentAppLocalizations().notificationLevelSummary(1, 1),
    );
  });

  test('aggregation state maintains the newest entry in arrival order', () {
    final state = NotificationLevelState();
    state.add(chat('U1', 'A', 1));
    state.add(chat('U2', 'B', 2));
    state.add(chat('U1', 'C', 3));

    expect(state.senderCount, 2);
    expect(state.newest?.body, 'C', reason: 'should reflect the newest entry in arrival order');

    state.removeSender('U1');
    expect(state.senderCount, 1);
    expect(state.newest?.body, 'B');
  });

  test('aggregation state prunes expired entries', () {
    final state = NotificationLevelState();
    final start = DateTime(2026, 1, 1);
    state.add(chat('U1', 'A', 1), now: start);
    state.add(chat('U2', 'B', 2), now: start.add(const Duration(seconds: 5)));

    state.prune(
      const Duration(seconds: 10),
      now: start.add(const Duration(seconds: 12)),
    );

    expect(state.senderCount, 1);
    expect(state.newest?.body, 'B');
  });

  test('senderKey for group chat notifications matches the real-time message path (roomId)', () {
    final app = AppNotification.fromNotificationInfo(
      NotificationInfo(
        timeStamp: 1,
        event: 'message.plain',
        title: 'Title',
        content: 'Body',
        groupId: 8,
        senderRaw: 'G8U12',
      ),
    );

    expect(app.roomId, 'G8');
    expect(
      app.senderKey,
      'G8',
      reason: 'senderRaw is G8U12, so the senderKey should match the roomId G8',
    );
  });
}
