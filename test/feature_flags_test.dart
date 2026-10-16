import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
import 'package:touchfish_client/services/feature_flags.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FeatureFlags.instance.resetForTest();
  });

  test('defaults to all features enabled', () {
    final flags = FeatureFlags.instance;
    expect(flags.privateChat, isTrue);
    expect(flags.groupChat, isTrue);
    expect(flags.groupCreate, isTrue);
    expect(flags.friendRequest, isTrue);
    expect(flags.readReceipt, isTrue);
    expect(flags.forum, isTrue);
    expect(flags.sticker, isTrue);
    expect(flags.announcement, isTrue);
    expect(flags.presence, isTrue);
  });

  test('apply updates getters and notifies listeners', () async {
    final flags = FeatureFlags.instance;
    var notifications = 0;
    flags.addListener(() => notifications++);

    await flags.apply(
      const TfFeatureFlags(
        privateChat: false,
        groupChat: false,
        groupCreate: true,
        friendRequest: false,
        forum: false,
        sticker: true,
        announcement: false,
      ),
    );

    expect(flags.privateChat, isFalse);
    expect(flags.groupChat, isFalse);
    expect(flags.groupCreate, isTrue);
    expect(flags.friendRequest, isFalse);
    expect(flags.forum, isFalse);
    expect(flags.sticker, isTrue);
    expect(flags.announcement, isFalse);
    expect(notifications, 1);
  });

  test('apply with identical values does not notify', () async {
    final flags = FeatureFlags.instance;
    var notifications = 0;
    flags.addListener(() => notifications++);

    await flags.apply(const TfFeatureFlags());
    expect(notifications, 0, reason: '与默认一致时不应通知');
  });

  test('init loads cached flags from preferences', () async {
    SharedPreferences.setMockInitialValues({
      'cached_feature_flags':
          '{"chat":{"private_chat":false,"group_chat":true,"group_create":true,'
          '"friend_request":true},"forum":false,"sticker":true,'
          '"announcement":true}',
    });
    FeatureFlags.instance.resetForTest();

    await FeatureFlags.instance.init();

    expect(FeatureFlags.instance.privateChat, isFalse);
    expect(FeatureFlags.instance.forum, isFalse);
    expect(FeatureFlags.instance.sticker, isTrue);
  });

  group('TfFeatureFlags.copyWith', () {
    /// 把 toJson 的嵌套结构摊平成 "chat.read_receipt" / "presence" 这样的键，
    /// 用于逐字段比对。
    Map<String, bool> flatten(TfFeatureFlags flags) {
      final out = <String, bool>{};
      flags.toJson().forEach((key, value) {
        if (value is Map) {
          value.forEach((leaf, leafValue) {
            out['$key.$leaf'] = leafValue as bool;
          });
        } else {
          out[key] = value as bool;
        }
      });
      return out;
    }

    /// 摊平键 -> 只翻转该字段的副本。**新增开关必须在这里加一条 case**：
    /// 少了就会抛 StateError，从而逼着新增的开关接进 copyWith。
    TfFeatureFlags flip(TfFeatureFlags base, String key, bool value) {
      switch (key) {
        case 'chat.private_chat':
          return base.copyWith(privateChat: value);
        case 'chat.group_chat':
          return base.copyWith(groupChat: value);
        case 'chat.group_create':
          return base.copyWith(groupCreate: value);
        case 'chat.friend_request':
          return base.copyWith(friendRequest: value);
        case 'chat.read_receipt':
          return base.copyWith(readReceipt: value);
        case 'forum':
          return base.copyWith(forum: value);
        case 'sticker':
          return base.copyWith(sticker: value);
        case 'announcement':
          return base.copyWith(announcement: value);
        case 'presence':
          return base.copyWith(presence: value);
        default:
          throw StateError('新增了功能开关「$key」，请接进 TfFeatureFlags.copyWith 与本测试');
      }
    }

    test('every switch is covered by toJson', () {
      // 全 false 的基线：任何一处漏拷都会让该字段从 false 变回默认 true。
      const base = TfFeatureFlags(
        privateChat: false,
        groupChat: false,
        groupCreate: false,
        friendRequest: false,
        readReceipt: false,
        forum: false,
        sticker: false,
        announcement: false,
        presence: false,
      );
      expect(flatten(base).values.every((v) => !v), isTrue);
      expect(flatten(base).keys.toSet(), {
        'chat.private_chat',
        'chat.group_chat',
        'chat.group_create',
        'chat.friend_request',
        'chat.read_receipt',
        'forum',
        'sticker',
        'announcement',
        'presence',
      });
    });

    test('flipping one switch never resets the others', () {
      const base = TfFeatureFlags(
        privateChat: false,
        groupChat: false,
        groupCreate: false,
        friendRequest: false,
        readReceipt: false,
        forum: false,
        sticker: false,
        announcement: false,
        presence: false,
      );
      final before = flatten(base);
      for (final key in before.keys) {
        final after = flatten(flip(base, key, true));
        final changed = [
          for (final k in after.keys)
            if (after[k] != before[k]) k,
        ];
        expect(
          changed,
          [key],
          reason: 'copyWith($key) 改动了别的开关 —— 管理端保存时会把它静默重置',
        );
      }
    });

    test('copyWith keeps read_receipt and presence when untouched', () {
      // 回归：管理端曾漏拷这两个字段，改任何一个开关都会把服务端已关闭的
      // 已读回执 / 在线状态写回 true。
      const base = TfFeatureFlags(readReceipt: false, presence: false);
      final js = base.copyWith(forum: false).toJson();
      expect((js['chat'] as Map)['read_receipt'], isFalse);
      expect(js['presence'], isFalse);
    });
  });
}
