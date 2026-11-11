import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/notification_model.dart';
import 'package:touchfish_client/services/notification_local_store.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  NotificationInfo sample() => NotificationInfo(
        id: 42,
        timeStamp: 1736000000.5,
        readAt: 1736000100,
        event: 'punishment.created',
        title: '你收到一条警告',
        content: '处罚类型：警告。理由：刷屏',
        senderRaw: 'U9',
        meta: const {'punishment_id': 7, 'kind': 'warn'},
        locked: true,
        groupId: 3,
        mentionedUids: const [1, 2],
      );

  test('xlh ok', () {
    final original = sample();
    final restored = NotificationInfo.fromLocalJson(original.toJson());

    expect(restored.id, original.id);
    expect(restored.timeStamp, original.timeStamp);
    expect(restored.readAt, original.readAt);
    expect(restored.event, original.event);
    expect(restored.title, original.title);
    expect(restored.content, original.content);
    expect(restored.senderRaw, original.senderRaw);
    expect(restored.meta['punishment_id'], 7);
    expect(restored.locked, isTrue, reason: '锁定标记必须保留');
    expect(restored.groupId, 3);
    expect(restored.mentionedUids, [1, 2]);
  });

  test('RWIO local cache notification', () async {
    final store = NotificationLocalStore.instance;
    await store.save('http://127.0.0.1:1515', 1, [sample()]);

    final loaded = await store.load('http://127.0.0.1:1515', 1);
    expect(loaded.length, 1);
    expect(loaded.first.event, 'punishment.created');
    expect(loaded.first.locked, isTrue);
  });

  test('hubulishu(bushi) notifications ok', () async {
    final store = NotificationLocalStore.instance;
    await store.save('http://a.example:1515', 1, [sample()]);

    expect(await store.load('http://b.example:1515', 1), isEmpty);
    expect(await store.load('http://a.example:1515', 2), isEmpty);
    expect((await store.load('http://a.example:1515', 1)).length, 1);
  });

  test('no error if error if error', () async {
    final store = NotificationLocalStore.instance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'touchfish_notification_cache/http://x.example:1515/1',
      '[{"broken": true}, "not-a-map"]',
    );

    final loaded = await store.load('http://x.example:1515', 1);
    expect(loaded, isEmpty);
  });
}
