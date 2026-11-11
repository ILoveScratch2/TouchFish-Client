import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/chat_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/services/presence_service.dart';
import 'package:touchfish_client/widgets/account/account_friends_section.dart';

/// `/friend/relationship` 的解析（资料页靠它决定显示「拉黑」还是「解除拉黑」）
/// 与账户页好友/拉黑两张卡片的空态渲染。
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  group('TfRelationship', () {
    test('parses a block started by me', () {
      final rel = TfRelationship.fromJson({
        'success': true,
        'relationship': 'blocked',
        'is_friend': false,
        'blocked_by_me': true,
        'blocked_by_peer': false,
      });

      expect(rel.relationship, 'blocked');
      expect(rel.isFriend, isFalse);
      expect(rel.blockedByMe, isTrue);
      expect(rel.blockedByPeer, isFalse);
      expect(rel.hasBlock, isTrue);
    });

    test('parses a block started by the peer', () {
      final rel = TfRelationship.fromJson({'blocked_by_peer': true});

      expect(rel.relationship, 'none');
      expect(rel.blockedByMe, isFalse);
      expect(rel.blockedByPeer, isTrue);
      expect(rel.hasBlock, isTrue);
    });

    test('parses a plain friendship', () {
      final rel = TfRelationship.fromJson({
        'relationship': 'friend',
        'is_friend': true,
      });

      expect(rel.isFriend, isTrue);
      expect(rel.hasBlock, isFalse);
    });
  });

  group('decodeBlockedUsersResponse', () {
    test('404 / 405 mean the server does not have this endpoint', () {
      expect(decodeBlockedUsersResponse(404, null), isNull);
      expect(decodeBlockedUsersResponse(405, null), isNull);
    });

    test('a transport failure is not mistaken for an empty blocked list', () {
      // 回归：过去这里返回 null，调用方就把网络故障渲染成「Nobody is blocked」
      expect(
        () => decodeBlockedUsersResponse(0, null),
        throwsA(isA<StateError>()),
      );
    });

    test('a server-side rejection throws instead of pretending empty', () {
      expect(
        () => decodeBlockedUsersResponse(
          200,
          '{"success": false, "error": "AUTH_FAILED"}',
        ),
        throwsA(isA<StateError>()),
      );
      expect(
        () => decodeBlockedUsersResponse(200, '1699999999.1False'),
        throwsA(isA<StateError>()),
      );
    });

    test('parses the blocked uid list, and a missing list means empty', () {
      expect(
        decodeBlockedUsersResponse(200, '{"success": true, "blocked": [3, 5]}'),
        [3, 5],
      );
      expect(
        decodeBlockedUsersResponse(200, '{"success": true}'),
        isEmpty,
      );
    });
  });

  testWidgets('the friends card keeps offline friends next to online ones', (
    tester,
  ) async {
    final contacts = ChatDataService.instance.contacts;
    contacts
      ..clear()
      ..addAll([
        Contact(id: 'U1', name: 'Offline One'),
        Contact(id: 'U2', name: 'Online Two'),
      ]);
    final presence = PresenceService.instance;
    presence.clear();
    presence.debugSet(2, true);
    addTearDown(() {
      presence.clear();
      contacts.clear();
    });

    await tester.pumpWidget(_accountSectionApp());
    await tester.pumpAndSettle();

    expect(find.text('Online Two'), findsOneWidget);
    // 回归：只显示在线好友的写法会让离线好友整批从头像条里消失
    expect(find.text('Offline One'), findsOneWidget);
  });

  testWidgets('account section renders the friends and blocked cards', (
    tester,
  ) async {
    final contacts = ChatDataService.instance.contacts;
    contacts.clear();
    addTearDown(contacts.clear);

    await tester.pumpWidget(_accountSectionApp());
    await tester.pumpAndSettle();

    expect(find.text('Friends'), findsOneWidget);
    expect(find.text('Blocked'), findsOneWidget);
    expect(find.text('No friends yet'), findsOneWidget);
    // 未登录（测试里 uid 为 null）时 [_loadBlocked] 根本不会发请求，所以这里是
    // 「空」而不是「加载失败」。「拉黑列表拉取失败」与「没有拉黑任何人」的分流
    // 由 decodeBlockedUsersResponse 的用例覆盖（见上）。
    expect(find.text('Nobody is blocked'), findsOneWidget);
  });
}

Widget _accountSectionApp() => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: const Scaffold(
    body: SingleChildScrollView(child: AccountFriendsSection()),
  ),
);
