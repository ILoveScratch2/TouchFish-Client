import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/app_notification.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/app_notification_service.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  setUp(() => AppNotificationService.instance.clear());

  NotificationInfo punishment({int id = 1, double? readAt}) => NotificationInfo(
    id: id,
    timeStamp: 1,
    readAt: readAt,
    event: 'punishment.created',
    title: '你收到一条处罚',
    content: '处罚类型：警告。理由：刷屏',
    meta: const {'kind': 'warn', 'kind_label': '警告', 'reason': '刷屏'},
  );

  test('punishment event classification', () {
    expect(punishment().isPunishmentEvent, isTrue);
    expect(punishment().isAnnouncementEvent, isFalse);
    expect(punishment().isMessageEvent, isFalse);
  });

  test('punishment notification navigates to account page (from notification center)', () {
    expect(AppNotification.routeFor(punishment()), '/account');
  });

  test('locked flag from server is parsed correctly (unexpired punishment cannot be deleted)', () {
    final locked = NotificationInfo.fromServerJson({
      'id': 9,
      'time_stamp': 1.0,
      'read_at': null,
      'locked': true,
      'info': {
        'event': 'punishment.created',
        'title': '你收到一条警告',
        'content': '处罚类型：警告。理由：刷屏',
        'meta': {'punishment_id': 1, 'kind': 'warn'},
      },
    });
    expect(locked.locked, isTrue);
    expect(locked.isPunishmentEvent, isTrue);

    final unlocked = NotificationInfo.fromServerJson({
      'id': 10,
      'time_stamp': 1.0,
      'read_at': null,
      'info': {
        'event': 'punishment.expired',
        'title': '处罚已到期',
        'content': '账号已恢复',
        'meta': {'punishment_id': 1},
      },
    });
    expect(unlocked.locked, isFalse, reason: '缺省即可删除');
  });

  test('during in-app banner suppression: normal channel is silent, punishment channel still delivered', () async {
    final service = AppNotificationService.instance;
    service.suppressInAppBanners(const Duration(seconds: 10));

    await service.present(
      AppNotification.fromNotificationInfo(punishment(id: 1)),
    );
    expect(service.items, isEmpty, reason: '普通通知应被登录抑制吞掉');

    await service.presentUrgent(
      AppNotification.fromNotificationInfo(punishment(id: 2)),
    );
    expect(service.items, isNotEmpty, reason: '处罚通知不能被抑制');
  });
}
