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
    expect(flags.forum, isTrue);
    expect(flags.sticker, isTrue);
    expect(flags.announcement, isTrue);
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
}
