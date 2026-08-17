import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/message_sync_service.dart';

void main() {
  group('MessageSyncService sequence gap detection', () {
    test('observing messages advances the latest sequence', () {
      final service = MessageSyncService.instance;
      service.clear();

      service.observeMessage(
        'U1',
        ChatMessage(
          id: '1',
          mid: 1,
          text: 'a',
          timestamp: DateTime.now(),
          isMe: false,
          roomSeq: 5,
        ),
      );
      expect(service.lastSeqOf('U1'), 5);

      service.observeMessage(
        'U1',
        ChatMessage(
          id: '2',
          mid: 2,
          text: 'b',
          timestamp: DateTime.now(),
          isMe: false,
          roomSeq: 6,
        ),
      );
      expect(service.lastSeqOf('U1'), 6);
    });

    test('out-of-order messages do not regress the sequence', () {
      final service = MessageSyncService.instance;
      service.clear();

      service.registerRoomSeq('G5', 10);
      service.observeMessage(
        'G5',
        ChatMessage(
          id: 'old',
          mid: 9,
          text: 'stale',
          timestamp: DateTime.now(),
          isMe: false,
          roomSeq: 8,
        ),
      );
      expect(service.lastSeqOf('G5'), 10);
    });

    test('registerRoomSeq only ever advances', () {
      final service = MessageSyncService.instance;
      service.clear();
      service.registerRoomSeq('U2', 3);
      service.registerRoomSeq('U2', 1);
      expect(service.lastSeqOf('U2'), 3);
    });
  });

  group('missing sequence range compression', () {
    test('compresses consecutive sequences into ranges', () {
      final result = MessageSyncService.compressMissingRanges([
        1,
        2,
        3,
        5,
        7,
        8,
      ]);
      expect(result.singles, [5]);
      expect(result.ranges, [
        {'start_seq': 1, 'end_seq': 3},
        {'start_seq': 7, 'end_seq': 8},
      ]);
    });

    test('all-single and all-range inputs', () {
      final singles = MessageSyncService.compressMissingRanges([4, 9]);
      expect(singles.singles, [4, 9]);
      expect(singles.ranges, isEmpty);

      final ranges = MessageSyncService.compressMissingRanges([1, 2, 3]);
      expect(ranges.singles, isEmpty);
      expect(ranges.ranges, [
        {'start_seq': 1, 'end_seq': 3},
      ]);
    });
  });

  group('message sync pagination and retry', () {
    test('uses the batch max roomSeq and consumes hasMore', () async {
      final cursors = <int>[];
      final processed = <int>[];
      int? savedSeq;
      var call = 0;
      final service = MessageSyncService.forTesting(
        fetchMessages: (request) async {
          cursors.add(request.lastSeq);
          call++;
          if (call == 1) {
            return (
              messages: [_messageWithSeq(11), _messageWithSeq(12)],
              currentSeq: 50,
              hasMore: true,
            );
          }
          return (
            messages: [_messageWithSeq(13)],
            currentSeq: 50,
            hasMore: false,
          );
        },
        processMessages: (_, messages) {
          processed.addAll(messages.map((message) => message.roomSeq!));
        },
        saveSyncPoint: (_, seq) async => savedSeq = seq,
      );
      service.registerRoomSeq('U1', 10);

      await service.syncRoomIncrementalForTesting('U1');

      expect(cursors, [10, 12]);
      expect(processed, [11, 12, 13]);
      expect(service.lastSeqOf('U1'), 13);
      expect(savedSeq, 13);
    });

    test('lastMid migration consumes every page', () async {
      final requests = <MessageSyncRequest>[];
      var call = 0;
      final service = MessageSyncService.forTesting(
        fetchMessages: (request) async {
          requests.add(request);
          call++;
          return call == 1
              ? (messages: [_messageWithSeq(21)], currentSeq: 30, hasMore: true)
              : (
                  messages: [_messageWithSeq(22)],
                  currentSeq: 30,
                  hasMore: false,
                );
        },
        processMessages: (_, __) {},
        saveSyncPoint: (_, __) async {},
      );

      await service.syncRoomFromMid('G2', 200);

      expect(requests, hasLength(2));
      expect(requests.first.lastMid, 200);
      expect(requests.first.lastSeq, 0);
      expect(requests.last.lastMid, isNull);
      expect(requests.last.lastSeq, 21);
      expect(service.lastSeqOf('G2'), 22);
    });

    test('failed gap sync keeps missing sequences for retry', () async {
      var shouldFail = true;
      final service = MessageSyncService.forTesting(
        fetchMessages: (_) async {
          if (shouldFail) throw StateError('network failed');
          return (
            messages: [_messageWithSeq(2), _messageWithSeq(3)],
            currentSeq: 3,
            hasMore: false,
          );
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.queueMissingForTesting('U3', [2, 3]);

      await service.syncMissingForTesting('U3');
      expect(service.queuedMissingForTesting('U3'), {2, 3});

      shouldFail = false;
      await service.syncMissingForTesting('U3');
      expect(service.queuedMissingForTesting('U3'), isEmpty);
    });

    test('large gaps are split into bounded requests', () async {
      final requestSizes = <int>[];
      final service = MessageSyncService.forTesting(
        fetchMessages: (request) async {
          final sequences = <int>[...request.missingSequences];
          for (final range in request.missingSequenceRanges) {
            sequences.addAll(
              List<int>.generate(
                range['end_seq']! - range['start_seq']! + 1,
                (index) => range['start_seq']! + index,
              ),
            );
          }
          requestSizes.add(sequences.length);
          return (
            messages: sequences.map(_messageWithSeq).toList(),
            currentSeq: 251,
            hasMore: false,
          );
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.queueMissingForTesting(
        'U4',
        List<int>.generate(250, (i) => i + 1),
      );

      await service.syncMissingForTesting('U4');

      expect(requestSizes, [100, 100, 50]);
      expect(service.queuedMissingForTesting('U4'), isEmpty);
    });
  });

  group('recalled message phantom seq handling', () {
    test('forgotten seqs are removed from the queue and never requested', () async {
      final requested = <int>[];
      final service = MessageSyncService.forTesting(
        fetchMessages: (request) async {
          requested.addAll(request.missingSequences);
          return (
            messages: request.missingSequences.map(_messageWithSeq).toList(),
            currentSeq: 3,
            hasMore: false,
          );
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.queueMissingForTesting('U7', [2, 3]);
      service.forgetMissingSeq('U7', 2);

      await service.syncMissingForTesting('U7');

      expect(requested, [3]);
      expect(service.queuedMissingForTesting('U7'), isEmpty);
    });

    test('observeMessage does not re-queue a forgotten seq', () async {
      final gate = Completer<void>();
      final requests = <MessageSyncRequest>[];
      final service = MessageSyncService.forTesting(
        fetchMessages: (request) async {
          requests.add(request);
          await gate.future;
          return (
            messages: [_messageWithSeq(3)],
            currentSeq: 3,
            hasMore: false,
          );
        },
        processMessages: (_, __) {},
      );
      addTearDown(() {
        gate.complete();
        service.clear();
      });
      service.registerRoomSeq('U5', 1);
      service.forgetMissingSeq('U5', 2);

      service.observeMessage('U5', _messageWithSeq(4));
      await Future<void>.delayed(Duration.zero);

      expect(requests.single.missingSequences, [3]);
      expect(requests.single.missingSequenceRanges, isEmpty);
    });

    test('forget during in-flight batch drops the seq instead of re-queueing',
        () async {
      final gate = Completer<void>();
      final service = MessageSyncService.forTesting(
        fetchMessages: (_) async {
          await gate.future;
          return (
            messages: [_messageWithSeq(3)],
            currentSeq: 3,
            hasMore: false,
          );
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.queueMissingForTesting('U6', [2, 3]);

      final syncFuture = service.syncMissingForTesting('U6');
      service.forgetMissingSeq('U6', 2);
      gate.complete();
      await syncFuture;

      expect(service.queuedMissingForTesting('U6'), isEmpty);
    });
  });

  group('current_seq permanent-gap drop rule', () {
    test('seqs below currentSeq that are not returned are dropped', () async {
      final service = MessageSyncService.forTesting(
        fetchMessages: (_) async {
          return (
            messages: [_messageWithSeq(3)],
            currentSeq: 9,
            hasMore: false,
          );
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.queueMissingForTesting('U8', [2, 3]);

      await service.syncMissingForTesting('U8');

      expect(service.queuedMissingForTesting('U8'), isEmpty);
    });

    test('empty response with higher currentSeq drops all queued seqs',
        () async {
      final service = MessageSyncService.forTesting(
        fetchMessages: (_) async {
          return (messages: <ChatMessage>[], currentSeq: 9, hasMore: false);
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.queueMissingForTesting('U9', [5]);

      await service.syncMissingForTesting('U9');

      expect(service.queuedMissingForTesting('U9'), isEmpty);
    });

    test('dropped seqs are not re-queued by later observeMessage', () async {
      var call = 0;
      final requests = <MessageSyncRequest>[];
      final gate = Completer<void>();
      final service = MessageSyncService.forTesting(
        fetchMessages: (request) async {
          call++;
          if (call == 1) {
            return (messages: <ChatMessage>[], currentSeq: 9, hasMore: false);
          }
          requests.add(request);
          await gate.future;
          return (messages: <ChatMessage>[], currentSeq: 12, hasMore: false);
        },
        processMessages: (_, __) {},
      );
      addTearDown(() {
        gate.complete();
        service.clear();
      });
      service.registerRoomSeq('U10', 4);
      service.queueMissingForTesting('U10', [5]);

      await service.syncMissingForTesting('U10');
      expect(service.queuedMissingForTesting('U10'), isEmpty);

      service.observeMessage('U10', _messageWithSeq(12));
      await Future<void>.delayed(Duration.zero);

      expect(requests, hasLength(1));
      expect(requests.single.missingSequences, isEmpty);
      expect(requests.single.missingSequenceRanges, [
        {'start_seq': 6, 'end_seq': 11},
      ]);
    });

    test('seqs at or above currentSeq are kept (fallback safety)', () async {
      final service = MessageSyncService.forTesting(
        fetchMessages: (_) async {
          return (messages: <ChatMessage>[], currentSeq: 1, hasMore: false);
        },
        processMessages: (_, __) {},
      );
      addTearDown(service.clear);
      service.registerRoomSeq('U11', 1);
      service.queueMissingForTesting('U11', [2]);

      await service.syncMissingForTesting('U11');

      expect(service.queuedMissingForTesting('U11'), {2});
    });
  });

  group('ChatMessage.fromServerMessage', () {
    test('parses a plain message with room_seq', () {
      final message = ChatMessage.fromServerMessage({
        'event': 'message.plain',
        'title': '1700000000.0',
        'content': 'hello',
        'sender': 'U42',
        'mid': 7,
        'client_mid': 'cm-1',
        'room_id': 'U42',
        'room_seq': 12,
        'mentioned_uids': [1],
        'mentions_me': true,
        'should_alert': true,
      }, myUid: 1);

      expect(message.mid, 7);
      expect(message.senderUid, 42);
      expect(message.isMe, isFalse);
      expect(message.text, 'hello');
      expect(message.roomSeq, 12);
      expect(message.mentionedUids, [1]);
      expect(message.mentionsMe, isTrue);
      expect(message.shouldAlert, isTrue);
      expect(message.type, MessageType.text);
    });

    test('parses a group file message', () {
      final message = ChatMessage.fromServerMessage({
        'event': 'message.file',
        'title': '1700000000.0',
        'content':
            'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
        'sender': 'G5U42',
        'mid': 8,
        'file_hash':
            'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2',
        'room_id': 'G5',
        'group_id': 5,
        'room_seq': 13,
        'file': {
          'file_name': 'photo.png',
          'size': 100,
          'mime_type': 'image/png',
        },
        'mentioned_uids': <int>[],
        'mentions_me': false,
        'should_alert': false,
      }, myUid: 1);

      expect(message.mid, 8);
      expect(message.senderUid, 42);
      expect(message.roomSeq, 13);
      expect(message.type, MessageType.image);
      expect(message.media?.fileName, 'photo.png');
    });

    test('parses a recalled tombstone', () {
      final message = ChatMessage.fromServerMessage({
        'event': 'message.plain',
        'title': '1700000000.0',
        'content': null,
        'sender': 'U42',
        'mid': 7,
        'room_id': 'U42',
        'room_seq': 14,
        'deleted': true,
        'deleted_at': 1700000100.0,
        'deleted_by': 42,
      }, myUid: 1);

      expect(message.isDeleted, isTrue);
      expect(message.roomSeq, 14);
      expect(message.deletedBy, 42);
    });

    test('detects own messages via myUid', () {
      final message = ChatMessage.fromServerMessage({
        'event': 'message.plain',
        'title': '1700000000.0',
        'content': 'self',
        'sender': 'U1',
        'mid': 9,
        'room_id': 'U1',
        'room_seq': 1,
      }, myUid: 1);
      expect(message.isMe, isTrue);
    });
  });

  group('ChatMessage.fromMessageRecord with room_seq', () {
    test('sync records carry room_seq', () {
      final message = ChatMessage.fromMessageRecord({
        'mid': 7,
        'sender_uid': 2,
        'content': 'synced',
        'content_type': 'plain',
        'send_time': 1700000000.0,
        'room_seq': 12,
        'deleted': 0,
      }, 1);

      expect(message.mid, 7);
      expect(message.senderUid, 2);
      expect(message.text, 'synced');
      expect(message.roomSeq, 12);
      expect(message.isMe, isFalse);
    });

    test('deleted tombstone keeps room_seq', () {
      final message = ChatMessage.fromMessageRecord({
        'mid': 7,
        'sender_uid': 2,
        'content': null,
        'content_type': 'plain',
        'send_time': 1700000000.0,
        'room_seq': 15,
        'deleted': 1,
        'deleted_at': 1700000100.0,
        'deleted_by': 2,
      }, 1);

      expect(message.isDeleted, isTrue);
      expect(message.roomSeq, 15);
      expect(message.deletedBy, 2);
    });
  });
}

ChatMessage _messageWithSeq(int seq) => ChatMessage(
  id: '$seq',
  mid: seq,
  text: 'message $seq',
  timestamp: DateTime.fromMillisecondsSinceEpoch(seq * 1000),
  isMe: false,
  roomSeq: seq,
);
