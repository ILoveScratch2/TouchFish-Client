import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/message_sync_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.init();
  });

  setUp(() async {
    await SettingsService.instance.setValue('syncMode', 'browsing');
  });

  ChatMessage msgWithSeq(int seq) => ChatMessage(
    id: '$seq',
    mid: seq,
    text: 'm$seq',
    timestamp: DateTime.fromMillisecondsSinceEpoch(seq * 1000),
    isMe: false,
    roomSeq: seq,
  );

  test('browsing mode: gaps advance the cursor without fetching', () async {
    final requests = <MessageSyncRequest>[];
    final service = MessageSyncService.forTesting(
      fetchMessages: (request) async {
        requests.add(request);
        return (
          messages: const <ChatMessage>[],
          currentSeq: 0,
          hasMore: false,
        );
      },
      processMessages: (_, _) {},
    );
    addTearDown(service.clear);
    service.registerRoomSeq('U1', 1);

    service.observeMessage('U1', msgWithSeq(5));
    await Future<void>.delayed(Duration.zero);

    expect(service.lastSeqOf('U1'), 5);
    expect(service.queuedMissingForTesting('U1'), isEmpty);
    expect(requests, isEmpty);
  });

  test('browsing mode: upgrading a room resumes gap sync', () async {
    final requests = <MessageSyncRequest>[];
    final service = MessageSyncService.forTesting(
      fetchMessages: (request) async {
        requests.add(request);
        return (
          messages: const <ChatMessage>[],
          currentSeq: 8,
          hasMore: false,
        );
      },
      processMessages: (_, _) {},
      saveSyncPoint: (_, _) async {},
    );
    addTearDown(service.clear);
    service.registerRoomSeq('U1', 5);

    // 升级前：只推进游标
    service.observeMessage('U1', msgWithSeq(8));
    await Future<void>.delayed(Duration.zero);
    expect(requests, isEmpty);

    // 升级为完整同步后再出现缺口 → 排队并补拉
    await service.markRoomFullySynced('U1');
    expect(service.isFullSyncRoom('U1'), isTrue);
    service.observeMessage('U1', msgWithSeq(12));
    await Future<void>.delayed(Duration.zero);

    expect(requests, isNotEmpty);
    expect(service.lastSeqOf('U1'), 12);
  });

  test('full mode: gaps always queue and fetch', () async {
    await SettingsService.instance.setValue('syncMode', 'full');
    final requests = <MessageSyncRequest>[];
    final service = MessageSyncService.forTesting(
      fetchMessages: (request) async {
        requests.add(request);
        return (
          messages: const <ChatMessage>[],
          currentSeq: 5,
          hasMore: false,
        );
      },
      processMessages: (_, _) {},
    );
    addTearDown(service.clear);
    service.registerRoomSeq('U1', 1);

    expect(service.isFullSyncRoom('U1'), isTrue);
    service.observeMessage('U1', msgWithSeq(5));
    await Future<void>.delayed(Duration.zero);

    expect(requests, isNotEmpty);
  });
}
