import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
import 'package:touchfish_client/services/feature_flags.dart';
import 'package:touchfish_client/services/presence_service.dart';
import 'package:touchfish_client/widgets/account/online_avatar_badge.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

Widget _avatar() => const CircleAvatar(radius: 20, child: Icon(Icons.person));

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('TfFeatureFlags.presence', () {
    test('parses top-level presence', () {
      expect(TfFeatureFlags.fromJson({'presence': false}).presence, isFalse);
    });

    test('defaults to true when missing', () {
      expect(const TfFeatureFlags().presence, isTrue);
      expect(TfFeatureFlags.fromJson({}).presence, isTrue);
    });

    test('round-trips through toJson', () {
      final json = const TfFeatureFlags(presence: false).toJson();
      expect(json['presence'], isFalse);
    });
  });

  group('PresenceService', () {
    test('tracks online / offline / unknown and clears', () {
      final p = PresenceService.instance;
      p.clear();
      expect(p.isKnown(1), isFalse);
      expect(p.isOnline(1), isFalse);

      p.debugSet(1, true);
      expect(p.isOnline(1), isTrue);
      expect(p.isKnown(1), isTrue);

      p.debugSet(1, false);
      expect(p.isOnline(1), isFalse);
      expect(p.isKnown(1), isTrue);

      p.debugSet(1, null);
      expect(p.isKnown(1), isFalse);

      p.debugSet(2, true);
      p.clear();
      expect(p.isKnown(2), isFalse);
    });

    test('an omitted uid falls back to unknown (hidden status)', () {
      final p = PresenceService.instance;
      p.clear();
      p.debugSet(1, true);
      p.debugSet(2, false);

      p.applyPresenceSnapshot({2: 'online'});

      expect(p.isKnown(1), isFalse);
      expect(p.isOnline(1), isFalse);
      expect(p.isOnline(2), isTrue);
    });

    test('a scoped snapshot only reconciles the requested uids', () {
      final p = PresenceService.instance;
      p.clear();
      p.debugSet(1, true);
      p.debugSet(2, true);

      p.applyPresenceSnapshot({2: 'offline'}, scope: [2]);

      expect(p.isOnline(1), isTrue);
      expect(p.isKnown(2), isTrue);
      expect(p.isOnline(2), isFalse);
    });

    test('a stale snapshot cannot resurrect a newer offline pushing wxh into zyh', () {
      final p = PresenceService.instance;
      p.clear();

      // 离线推送
      p.debugApplyPush(7, 'offline', ts: 2000);
      expect(p.isOnline(7), isFalse);

      // 在推送之前就算好
      p.applyPresenceSnapshot({7: 'online'}, scope: [7], ts: 1000);
      expect(p.isOnline(7), isFalse);
    });

    test('a newer snapshot overrides an older push', () {
      final p = PresenceService.instance;
      p.clear();

      p.debugApplyPush(8, 'online', ts: 1000);
      expect(p.isOnline(8), isTrue);

      p.applyPresenceSnapshot({8: 'offline'}, scope: [8], ts: 2000);
      expect(p.isOnline(8), isFalse);
    });

    test('a stale snapshot cannot revive a hidden friend', () {
      final p = PresenceService.instance;
      p.clear();

      p.debugApplyPush(9, 'online', ts: 1000);
      p.debugApplyPush(9, 'hidden', ts: 2000);
      expect(p.isKnown(9), isFalse);

      p.applyPresenceSnapshot({9: 'online'}, scope: [9], ts: 1500);
      expect(p.isKnown(9), isFalse);
      expect(p.isOnline(9), isFalse);
    });

    test('snapshots without ts keep the legacy overwrite behaviour', () {
      final p = PresenceService.instance;
      p.clear();

      p.debugApplyPush(10, 'offline', ts: 2000);
      p.applyPresenceSnapshot({10: 'online'}, scope: [10]);
      expect(p.isOnline(10), isTrue);
    });
  });

  testWidgets('dot shows when online and hides when offline', (tester) async {
    final p = PresenceService.instance;
    p.clear();
    await FeatureFlags.instance.apply(const TfFeatureFlags());

    await tester.pumpWidget(
      _wrap(const OnlineAvatarBadge(uid: 5, child: CircleAvatar())),
    );
    expect(find.byKey(onlineBadgeDotKey), findsNothing);

    p.debugSet(5, true);
    await tester.pump();
    expect(find.byKey(onlineBadgeDotKey), findsOneWidget);

    p.debugSet(5, false);
    await tester.pump();
    expect(find.byKey(onlineBadgeDotKey), findsNothing);
  });

  testWidgets('dot hidden when the global feature is off', (tester) async {
    final p = PresenceService.instance;
    p.clear();
    p.debugSet(5, true);
    await FeatureFlags.instance.apply(const TfFeatureFlags(presence: false));

    await tester.pumpWidget(
      _wrap(const OnlineAvatarBadge(uid: 5, child: CircleAvatar())),
    );
    expect(find.byKey(onlineBadgeDotKey), findsNothing);

    await FeatureFlags.instance.apply(const TfFeatureFlags());
  });

  testWidgets('null uid never shows a dot', (tester) async {
    final p = PresenceService.instance;
    p.clear();
    await FeatureFlags.instance.apply(const TfFeatureFlags());

    await tester.pumpWidget(_wrap(OnlineAvatarBadge(uid: null, child: _avatar())));
    expect(find.byKey(onlineBadgeDotKey), findsNothing);
  });
}
