import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/chat_model.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/screens/chat_detail/widgets/message_list_view.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';
import 'package:touchfish_client/services/chat_data_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  group('TfFeatureFlags.readReceipt', () {
    test('parses chat.read_receipt', () {
      final flags = TfFeatureFlags.fromJson({
        'chat': {'read_receipt': false},
      });
      expect(flags.readReceipt, isFalse);
    });

    test('defaults to true when missing', () {
      expect(const TfFeatureFlags().readReceipt, isTrue);
      expect(TfFeatureFlags.fromJson({'chat': {}}).readReceipt, isTrue);
    });

    test('round-trips through toJson', () {
      final json = const TfFeatureFlags(readReceipt: false).toJson();
      expect((json['chat'] as Map)['read_receipt'], isFalse);
    });
  });

  group('TfReadReceipt', () {
    test('parses private read state', () {
      final r = TfReadReceipt.fromJson({
        'success': true,
        'read': true,
        'reader_last_seq': 7,
      });
      expect(r.read, isTrue);
      expect(r.readerLastSeq, 7);
    });

    test('parses hidden and group count', () {
      expect(TfReadReceipt.fromJson({'hidden': true}).hidden, isTrue);
      expect(TfReadReceipt.fromJson({'read_count': 3}).readCount, 3);
    });
  });

  group('ChatDataService read receipt cache', () {
    test('reset drops cached receipts so accounts do not bleed into each other',
        () async {
      final cds = ChatDataService.instance;
      await cds.reset();
      cds.applyPeerReadReceipt('U2', 5);
      cds.setGroupReadCount(7, 3);
      expect(cds.peerReadSeq('U2'), 5);
      expect(cds.groupReadCount(7), 3);

      await cds.reset();
      expect(cds.peerReadSeq('U2'), isNull);
      expect(cds.groupReadCount(7), isNull);
    });

    test('receipt changes bump the revision so the bubble list can repaint',
        () async {
      final cds = ChatDataService.instance;
      await cds.reset();
      final before = cds.readReceiptRevision.value;

      cds.applyPeerReadReceipt('U2', 5);
      expect(cds.readReceiptRevision.value, greaterThan(before));

      // 值没变就不该再通知：否则每条 WS 事件都会重建整个气泡列表
      final afterFirst = cds.readReceiptRevision.value;
      cds.applyPeerReadReceipt('U2', 5);
      cds.applyPeerReadReceipt('U2', 3);
      expect(cds.readReceiptRevision.value, afterFirst);

      cds.setGroupReadCount(7, 3);
      expect(cds.readReceiptRevision.value, greaterThan(afterFirst));

      cds.clearPeerReadReceipt('U2');
      expect(cds.peerReadSeq('U2'), isNull);
      expect(cds.readReceiptRevision.value, greaterThan(afterFirst));

      await cds.reset();
    });

    test('a hidden read receipt drops the cached watermark', () async {
      final cds = ChatDataService.instance;
      await cds.reset();
      // 之前查到过对方的水位 → 自己的最后一条消息渲染成「已读」
      cds.applyReadReceiptResult('U2', 7, const TfReadReceipt(readerLastSeq: 9));
      expect(cds.peerReadSeq('U2'), 9);

      // 对方关闭「展示已读状态」：必须真的丢掉。只「不再更新」不够——服务端
      // 此刻已停止推送，没有任何后续事件会来纠正它，UI 会永远挂着「已读」。
      cds.applyReadReceiptResult('U2', 7, const TfReadReceipt(hidden: true));
      expect(cds.peerReadSeq('U2'), isNull);

      await cds.reset();
    });

    test('a visible read receipt keeps caching and never regresses', () async {
      final cds = ChatDataService.instance;
      await cds.reset();

      cds.applyReadReceiptResult('U2', 7, const TfReadReceipt(readerLastSeq: 9));
      expect(cds.peerReadSeq('U2'), 9);
      // 水位单调：迟到的旧回执不得把它顶回去
      cds.applyReadReceiptResult('U2', 7, const TfReadReceipt(readerLastSeq: 4));
      expect(cds.peerReadSeq('U2'), 9);

      await cds.reset();
    });

    test('group read counts are capped and exposed read-only', () async {
      final cds = ChatDataService.instance;
      await cds.reset();

      for (var i = 0; i < 520; i++) {
        cds.setGroupReadCount(900000 + i, i + 1);
      }
      // 超上限丢最老的条目，最新写入的留下（否则缓存会随会话一直长）。
      expect(cds.groupReadCounts.length, lessThanOrEqualTo(500));
      expect(cds.groupReadCount(900519), 520);
      expect(cds.groupReadCount(900000), isNull);

      // 只读视图：外部改不动内部缓存。
      expect(() => cds.groupReadCounts[1] = 1, throwsUnsupportedError);

      await cds.reset();
    });
  });

  ChatMessage ownMessage({required int mid, required int seq}) => ChatMessage(
    id: 'm$mid',
    mid: mid,
    roomSeq: seq,
    isMe: true,
    text: 'hi',
    timestamp: DateTime(2026, 1, 1),
  );

  Future<void> pumpList(
    WidgetTester tester, {
    required List<ChatMessage> messages,
    required ChatType type,
    bool enabled = true,
    int? peerReadSeq,
    Map<int, int> groupReadCounts = const {},
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageListView(
              messages: messages,
              scrollController: ScrollController(),
              galleryItems: const [],
              imageIndexById: const {},
              essenceMids: const [],
              pinnedMessages: const [],
              essenceEnabled: false,
              currentRoom: ChatRoom(id: 'x', name: 'X', type: type),
              canModerateGroup: false,
              onRefresh: () {},
              onReply: (_) {},
              onForward: (_) {},
              onRecall: (_) {},
              onQuoteTap: (_) {},
              onPinToggle: (_) {},
              onEssenceToggle: (_) {},
              canRecall: (_) => false,
              canDeleteLocally: (_) => false,
              noMessagesText: 'none',
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              readReceiptEnabled: enabled,
              peerReadSeq: peerReadSeq,
              groupReadCounts: groupReadCounts,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('private chat shows Read under own last message when read', (
    tester,
  ) async {
    await pumpList(
      tester,
      messages: [ownMessage(mid: 1, seq: 3)],
      type: ChatType.direct,
      peerReadSeq: 3,
    );
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('private chat hides Read when peer has not reached it', (
    tester,
  ) async {
    await pumpList(
      tester,
      messages: [ownMessage(mid: 1, seq: 3)],
      type: ChatType.direct,
      peerReadSeq: 2,
    );
    expect(find.text('Read'), findsNothing);
  });

  testWidgets('a partial read marks the newest own message that was read', (
    tester,
  ) async {
    // 对方读到 seq=5，自己最新的那条是 seq=7：标记必须落在 seq=5 那条上。
    // 挂在「最后一条自己的消息」上会让这种部分已读完全不可见（旧行为：0 个标记）。
    await pumpList(
      tester,
      messages: [
        ownMessage(mid: 1, seq: 3),
        ownMessage(mid: 2, seq: 5),
        ownMessage(mid: 3, seq: 7),
      ],
      type: ChatType.direct,
      peerReadSeq: 5,
    );
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('a full read still shows exactly one marker', (tester) async {
    await pumpList(
      tester,
      messages: [ownMessage(mid: 1, seq: 3), ownMessage(mid: 2, seq: 5)],
      type: ChatType.direct,
      peerReadSeq: 5,
    );
    expect(find.text('Read'), findsOneWidget);
  });

  testWidgets('group chat shows the read count', (tester) async {
    await pumpList(
      tester,
      messages: [ownMessage(mid: 1, seq: 3)],
      type: ChatType.group,
      groupReadCounts: const {1: 2},
    );
    expect(find.text('2 read'), findsOneWidget);
  });

  testWidgets('read receipts are hidden when the feature flag is off', (
    tester,
  ) async {
    await pumpList(
      tester,
      messages: [ownMessage(mid: 1, seq: 3)],
      type: ChatType.direct,
      enabled: false,
      peerReadSeq: 3,
    );
    expect(find.text('Read'), findsNothing);
  });
}
