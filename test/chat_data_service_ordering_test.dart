import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/services/local_message_store.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  setUp(() async {
    await ChatDataService.instance.reset();
    LocalMessageStore.instance.configureScope('https://example.test', 100);
    await SettingsService.instance.setValue('inAppNotifications', false);
  });

  tearDown(() {
    LocalMessageStore.instance.clearScope();
  });

  ChatMessage incoming(int mid, {String? clientMid}) => ChatMessage(
    id: mid > 0 ? '$mid' : (clientMid ?? 'local'),
    mid: mid > 0 ? mid : null,
    clientMid: clientMid,
    roomSeq: mid > 0 ? mid : null,
    timestamp: DateTime.utc(
      2026,
      1,
      1,
      12,
    ).add(Duration(seconds: mid > 0 ? mid : 0)),
    isMe: false,
    senderUid: 1,
    senderName: 'Alice',
    text: 'm$mid',
    status: MessageStatus.sent,
    shouldAlert: false,
  );

  List<int?> seqsOf(String roomId) =>
      ChatDataService.instance.getMessages(roomId).map((m) => m.roomSeq).toList();

  test('out-of-order realtime arrivals stay sorted', () {
    final chatData = ChatDataService.instance;
    for (final mid in [5, 1, 3, 2, 4]) {
      chatData.deliverIncomingMessage('U1', incoming(mid));
    }

    expect(seqsOf('U1'), [1, 2, 3, 4, 5]);
  });

  test('out-of-order batched sync stays sorted', () {
    final chatData = ChatDataService.instance;
    chatData.processSyncedMessages('U1', [
      incoming(4),
      incoming(1),
      incoming(3),
      incoming(2),
    ]);

    expect(seqsOf('U1'), [1, 2, 3, 4]);
  });

  test('server echo relocates a pending message instead of appending it', () {
    final chatData = ChatDataService.instance;
    chatData.deliverIncomingMessage('U1', incoming(3));
    chatData.deliverIncomingMessage('U1', incoming(5));
    chatData.deliverIncomingMessage('U1', incoming(-1, clientMid: 'c1'));
    // 待确认消息
    expect(
      chatData.getMessages('U1').where((m) => m.clientMid == 'c1').length,
      1,
    );

    chatData.deliverIncomingMessage('U1', incoming(4, clientMid: 'c1'));

    final messages = chatData.getMessages('U1');
    expect(messages.length, 3);
    expect(messages.map((m) => m.roomSeq).toList(), [3, 4, 5]);
    expect(messages[1].mid, 4);
    expect(messages[1].clientMid, 'c1');
  });

  test('pending message keeps its timeline slot instead of sinking to bottom', () {
    final chatData = ChatDataService.instance;
    final base = DateTime.utc(2026, 1, 1, 12);

    ChatMessage at(int seq, int seconds, {String? clientMid}) => ChatMessage(
      id: clientMid ?? '$seq',
      mid: clientMid == null ? seq : null,
      clientMid: clientMid,
      roomSeq: clientMid == null ? seq : null,
      timestamp: base.add(Duration(seconds: seconds)),
      isMe: clientMid != null,
      senderUid: clientMid != null ? 100 : 1,
      text: clientMid ?? 'seq$seq',
      status: clientMid == null ? MessageStatus.sent : MessageStatus.failed,
    );

    chatData.deliverIncomingMessage('U1', at(1, 10));
    chatData.deliverIncomingMessage('U1', at(2, 20));
    chatData.deliverIncomingMessage('U1', at(-1, 15, clientMid: 'fail'));

    final ordered = chatData.getMessages('U1').map((m) => m.text).toList();
    expect(ordered, ['seq1', 'fail', 'seq2']);
  });

  test('a message without clientMid is not folded into one that has it', () {
    final chatData = ChatDataService.instance;
    final withClientMid = incoming(-1, clientMid: 'c1');
    final bare = ChatMessage(
      id: withClientMid.id,
      timestamp: withClientMid.timestamp,
      isMe: false,
      senderUid: 1,
      senderName: 'Alice',
      text: 'm-local',
      status: MessageStatus.sent,
      shouldAlert: false,
    );

    chatData.deliverIncomingMessage('U1', withClientMid);
    chatData.deliverIncomingMessage('U1', bare);

    expect(chatData.getMessages('U1').length, 2);
  });

  test('same clientMid is still deduped', () {
    final chatData = ChatDataService.instance;
    chatData.deliverIncomingMessage('U1', incoming(-1, clientMid: 'c1'));
    chatData.deliverIncomingMessage('U1', incoming(-1, clientMid: 'c1'));

    expect(chatData.getMessages('U1').length, 1);
  });

  test('bulk recall handles every mid in one pass', () {
    final base = [incoming(1), incoming(2), incoming(3)];

    final recalled = ChatDataService.applyRecallsToMessages(base, {1, 3});

    expect(recalled.map((m) => m.isDeleted).toList(), [true, false, true]);
    expect(recalled[1].isDeleted, isFalse);
  });

  test('bulk recall matches recalling one by one', () {
    final quoted = incoming(2).copyWith(
      quotePreview: const QuotedMessagePreview(mid: 1, content: 'hello'),
    );
    final base = [incoming(1), quoted, incoming(3)];

    final bulk = ChatDataService.applyRecallsToMessages(base, {1});
    var oneByOne = base;
    oneByOne = ChatDataService.applyRecallToMessages(oneByOne, 1);

    expect(bulk.length, oneByOne.length);
    for (var i = 0; i < bulk.length; i++) {
      expect(bulk[i].isDeleted, oneByOne[i].isDeleted, reason: 'index $i');
      expect(
        bulk[i].quotePreview?.isDeleted,
        oneByOne[i].quotePreview?.isDeleted,
        reason: 'quote at $i',
      );
    }
    expect(bulk[1].quotePreview?.isDeleted, isTrue);
  });

  test('bulk recall on an empty set returns the same list', () {
    final base = [incoming(1)];
    expect(
      identical(ChatDataService.applyRecallsToMessages(base, {}), base),
      isTrue,
    );
  });

  group('attachOlderMessages', () {
    test('prepends an older page and keeps the cache sorted', () {
      final chatData = ChatDataService.instance;
      final merged = chatData.debugAttachOlderMessages(
        [incoming(3), incoming(4)],
        [incoming(1), incoming(2)],
        const [],
      );

      expect(merged.map((m) => m.mid).toList(), [1, 2, 3, 4]);
    });

    test('sorts an out-of-order page', () {
      final chatData = ChatDataService.instance;
      final merged = chatData.debugAttachOlderMessages(
        [incoming(4)],
        [incoming(2), incoming(1)],
        const [],
      );

      expect(merged.map((m) => m.mid).toList(), [1, 2, 4]);
    });

    test('drops messages already in the cache', () {
      final chatData = ChatDataService.instance;
      final merged = chatData.debugAttachOlderMessages(
        [incoming(3), incoming(4)],
        [incoming(2), incoming(3)],
        const [],
      );

      expect(merged.map((m) => m.mid).toList(), [2, 3, 4]);
    });

    test('dedupes the page against local rows even with an empty cache', () {
      final chatData = ChatDataService.instance;
      final merged = chatData.debugAttachOlderMessages(
        const [],
        [incoming(1), incoming(2)],
        [incoming(2), incoming(3)],
      );

      expect(merged.map((m) => m.mid).toList(), [1, 2, 3]);
    });

    test('returns the cache untouched when the page adds nothing', () {
      final chatData = ChatDataService.instance;
      final cache = [incoming(5)];
      final merged = chatData.debugAttachOlderMessages(cache, [incoming(5)], const []);

      expect(identical(merged, cache), isTrue);
    });

    test('merge result is growable, so later cache writes still work wyf dl tql', () {
      final chatData = ChatDataService.instance;
      final merged = chatData.debugAttachOlderMessages(
        [incoming(3)],
        [incoming(1), incoming(2)],
        const [],
      );
      expect(() => merged.insert(0, incoming(0)), returnsNormally);
      expect(() => merged.removeRange(0, 1), returnsNormally);
      expect(merged.map((m) => m.mid).toList(), [1, 2, 3]);
    });
  });

  group('cache mutability', () {
    test(
      'setMessages with a fixed-length list keeps realtime inserts working wyf buzhun P',
      () {
        final chatData = ChatDataService.instance;
        chatData.setMessages(
          'U1',
          List<ChatMessage>.of([incoming(1), incoming(2)], growable: false),
        );

        expect(
          () => chatData.deliverIncomingMessage('U1', incoming(3)),
          returnsNormally,
        );
        expect(seqsOf('U1'), [1, 2, 3]);
      },
    );

    test('older-page merge then realtime insert does not throw', () {
      final chatData = ChatDataService.instance;
      chatData.setMessages('U1', [incoming(4)]);

      final merged = chatData.debugAttachOlderMessages(
        chatData.getMessages('U1'),
        [incoming(1), incoming(2), incoming(3)],
        const [],
      );
      chatData.setMessages('U1', merged);

      expect(
        () => chatData.deliverIncomingMessage('U1', incoming(5)),
        returnsNormally,
      );
      expect(seqsOf('U1'), [1, 2, 3, 4, 5]);
    });

    test('addSentMessage survives an immutable (const) cache list', () {
      final chatData = ChatDataService.instance;
      chatData.debugSetRawCache('U1', const <ChatMessage>[]);

      ChatMessage pending(String clientMid, int seq) => ChatMessage(
        id: clientMid,
        clientMid: clientMid,
        senderUid: 100,
        timestamp: DateTime.utc(2026, 1, 2).add(Duration(seconds: seq)),
        isMe: true,
        text: clientMid,
        status: MessageStatus.pending,
        shouldAlert: false,
      );

      expect(
        () => chatData.addSentMessage('U1', pending('c1', 1)),
        returnsNormally,
      );
      expect(
        () => chatData.addSentMessage('U1', pending('c2', 2)),
        returnsNormally,
      );
      expect(
        chatData.getMessages('U1').map((m) => m.clientMid).toList(),
        ['c1', 'c2'],
      );
    });
  });
}
