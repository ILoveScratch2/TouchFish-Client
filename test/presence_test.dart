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
