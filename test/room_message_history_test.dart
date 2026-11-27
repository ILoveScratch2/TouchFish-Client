import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/room_message_history.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/providers/chat/message_provider.dart';
import 'package:touchfish_client/services/chat_data_service.dart';
import 'package:touchfish_client/services/local_message_store.dart';

ChatMessage msg(int n, {String? client, String? id, MessageMedia? media}) =>
    ChatMessage(
      id: id ?? 'm$n',
      mid: n,
      clientMid: client,
      roomSeq: n,
      isMe: true,
      timestamp: DateTime.utc(2026).add(Duration(seconds: n)),
      text: 'message $n',
      media: media,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'snapshots retain fixed contents across appends, edits, trim and external writes',
    () {
      final history = RoomMessageHistory([
        msg(1),
        msg(2, media: const MessageMedia(path: 'a')),
      ]);
      final a = history.snapshot;
      expect(history.snapshot, same(a));
      history.add(msg(3));
      final b = history.snapshot;
      expect(b.extendsSnapshot(a), isTrue);
      expect(b.mediaMessages, same(a.mediaMessages));
      expect(a.map((m) => m.mid), [1, 2]);
      expect(() => a[2], throwsRangeError);
      history.add(msg(4, media: const MessageMedia(path: 'b')));
      final c = history.snapshot;
      expect(a.mediaMessages.length, 1);
      expect(c.mediaMessages.length, 2);
      history[1] = msg(9);
      expect(history.snapshot.extendsSnapshot(c), isFalse);
      history.insert(0, msg(0));
      history.removeRange(1, 4);
      expect(history.snapshot.map((m) => m.mid), [0, 4]);
      expect(c.map((m) => m.mid), [1, 2, 3, 4]);
      expect(a[1].media!.path, 'a');
      expect(() => a.add(msg(0)), throwsUnsupportedError);
    },
  );

  test(
    'native growable-list operations preserve previously published snapshots',
    () {
      final history = RoomMessageHistory([msg(1), msg(5)]);
      final first = history.snapshot;
      history.insertAll(1, [msg(2), msg(3), msg(4)]);
      final second = history.snapshot;
      expect(second.map((m) => m.mid), [1, 2, 3, 4, 5]);
      history.replaceRange(1, 2, [msg(8), msg(7), msg(6)]);
      final third = history.snapshot;
      expect(third.map((m) => m.mid), [1, 8, 7, 6, 3, 4, 5]);
      history.setAll(1, [msg(9), msg(7)]);
      history.sort((a, b) => a.mid!.compareTo(b.mid!));
      expect(history.snapshot.map((m) => m.mid), [1, 3, 4, 5, 6, 7, 9]);
      expect(first.map((m) => m.mid), [1, 5]);
      expect(second.map((m) => m.mid), [1, 2, 3, 4, 5]);
      expect(third.skip(1).first.mid, 8);
      final sorted = history.snapshot;
      expect(
        () => history.addAll(history),
        throwsA(isA<ConcurrentModificationError>()),
      );
      history.addAll(sorted);
      expect(history.length, 14);
      expect(sorted.length, 7);
      expect(history.snapshot.hasDuplicateMids, isTrue);
      history.removeAt(0);
      expect(history.indexOfMessage(msg(1)), 6);
    },
  );

  test(
    'read markers use only eligible outgoing rows from the published prefix',
    () {
      final history = RoomMessageHistory([
        msg(1),
        msg(2).copyWith(isMe: false),
        msg(3).copyWith(isDeleted: true),
        msg(4),
      ]);
      final early = history.snapshot;
      expect(early.peerReadMarker(0), -1);
      expect(early.peerReadMarker(3), 0);
      history.add(msg(5));
      final late = history.snapshot;
      expect(late.peerReadMarker(99), 4);
      expect(early.peerReadMarker(99), 3);
      expect(early.groupReadMarker({2: 1, 3: 1, 4: 2, 5: 10}), 3);
      expect(late.groupReadMarker({5: 10}), 4);
      history.insert(0, msg(8));
      final unsorted = history.snapshot;
      expect(unsorted.peerReadMarker(5), 5);
      expect(unsorted.peerReadMarker(0), -1);
      expect(early.groupReadMarker({4: 1}), 3);
    },
  );

  test(
    'matches the first alias in list order, including duplicates and bare IDs',
    () {
      final history = RoomMessageHistory([
        msg(11, client: 'first'),
        msg(12, client: 'second', id: 'only-id'),
        msg(12, id: 'bare'),
      ]);
      expect(history.snapshot.hasDuplicateMids, isTrue);
      expect(history.indexOfMessage(msg(12, client: 'first')), 0);
      expect(history.indexOfMessage(msg(11, client: 'second')), 0);
      expect(history.indexOfMessage(msg(90, id: 'only-id')), null);
      expect(history.indexOfMessage(msg(90, id: 'bare')), 2);
      history.removeAt(1);
      expect(history.snapshot.hasDuplicateMids, isFalse);
      expect(history.indexOfMessage(msg(12)), 1);
    },
  );

  test(
    'first-page refresh merges a concurrent push and preserves edits, recalls and removals',
    () async {
      final data = ChatDataService.instance;
      final store = LocalMessageStore.instance;
      await data.reset();
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      final directory = await Directory.systemTemp.createTemp();
      const channel = MethodChannel('plugins.flutter.io/path_provider');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      addTearDown(() => directory.delete(recursive: true));
      store.configureScope('https://history.test', 3);
      addTearDown(store.closeAllForTesting);
      addTearDown(store.clearScope);

      const room = 'U23';
      await store.getRoomSyncMid(room);
      Future<MessageHistoryPage> racing(
        List<ChatMessage> remote,
        FutureOr<void> Function() write, {
        bool Function()? sameAccount,
      }) async {
        final loadingLocal = Completer<void>();
        final release = Completer<List<ChatMessage>>();
        final page = data.refreshFirstPage(
          room,
          loadServer: () async => remote,
          loadLocal: () {
            loadingLocal.complete();
            return release.future;
          },
          sameAccount: sameAccount ?? () => true,
        );
        await loadingLocal.future;
        await write();
        release.complete([]);
        return page;
      }

      data.setMessages(room, [msg(2)]);
      var page = await racing([
        msg(1),
        msg(2),
      ], () => data.deliverIncomingMessage(room, msg(3)));
      expect(page.messages.map((m) => m.mid), [1, 2, 3]);
      expect(data.getMessages(room).map((m) => m.mid), [1, 2, 3]);

      final pending = ChatMessage(
        id: 'pending',
        clientMid: 'c9',
        senderUid: 3,
        text: 'pending',
        isMe: true,
        timestamp: DateTime.utc(2026),
      );
      data.addSentMessage(room, pending);
      final ack = msg(9, client: 'c9').copyWith(senderUid: 3);
      page = await racing([
        msg(2),
        pending,
      ], () => data.deliverIncomingMessage(room, ack));
      expect(page.messages.last.mid, 9);
      expect(data.getMessages(room).last.mid, 9);
      page = await racing([
        msg(2),
      ], () => data.markMessageRecalled(2, roomId: room));
      expect(page.messages.firstWhere((m) => m.mid == 2).isDeleted, isTrue);
      expect(
        (await store.loadMessages(
          room,
        )).firstWhere((m) => m.mid == 2).isDeleted,
        isTrue,
      );

      // A cancel may involve a target absent from this room's current visible cache.
      page = await racing([
        msg(88),
      ], () => data.markMessageRecalled(88, roomId: room));
      expect(page.messages.any((m) => m.mid == 88), isFalse);
      page = await racing([ack], () => data.deleteLocalMessage(room, ack));
      expect(page.messages.any((m) => m.mid == 9), isFalse);
      page = await racing([msg(2)], () => data.clearRoomLocalData(room));
      expect(page.messages, isEmpty);
      expect(await store.loadMessages(room), isEmpty);
      var same = true;
      page = await racing(
        [msg(2)],
        () => same = false,
        sameAccount: () => same,
      );
      expect(page.messages, isEmpty);
    },
  );

  test(
    'room subscribers follow edits and reset when switching accounts',
    () async {
      final data = ChatDataService.instance;
      await data.reset();
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      LocalMessageStore.instance.configureScope('https://example.test', 99);
      addTearDown(LocalMessageStore.instance.clearScope);
      const room = 'U799';
      final container = ProviderContainer();
      addTearDown(container.dispose);
      data.setMessages(room, [msg(0)]);
      final sub = container.listen(roomMessagesProvider(room), (_, _) {});
      final before = sub.read();
      data.getMessages(room)[0] = msg(5000);
      container.read(roomMessagesProvider(room).notifier).refresh();
      expect(sub.read().first.mid, 5000);
      expect(before.first.mid, 0);
      await data.reset();
      expect(sub.read(), isEmpty);
      LocalMessageStore.instance.configureScope('https://example.test', 100);
      data.addSentMessage(room, msg(1));
      expect(sub.read().single.mid, 1);
    },
  );
}
