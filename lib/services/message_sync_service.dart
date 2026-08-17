import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/message_model.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'auth_state.dart';
import 'chat_data_service.dart';
import 'local_message_store.dart';

class MessageSyncRequest {
  final int uid;
  final String password;
  final String roomId;
  final int lastSeq;
  final int? lastMid;
  final List<int> missingSequences;
  final List<Map<String, int>> missingSequenceRanges;
  final int limit;

  const MessageSyncRequest({
    required this.uid,
    required this.password,
    required this.roomId,
    this.lastSeq = 0,
    this.lastMid,
    this.missingSequences = const [],
    this.missingSequenceRanges = const [],
    this.limit = 100,
  });
}

typedef MessageSyncFetcher =
    Future<MessageSyncResult> Function(MessageSyncRequest request);

/// 消息增量同步服务
///
/// 补拉的消息静默合并，不然就会把wyf消息轰炸死
class MessageSyncService {
  MessageSyncService._({
    MessageSyncFetcher? fetchMessages,
    int? Function()? uidProvider,
    String? Function()? passwordProvider,
    void Function(String, List<ChatMessage>)? processMessages,
    Future<void> Function(String, int)? saveSyncPoint,
    Duration pageDelay = _defaultBatchDelay,
    Duration retryDelay = const Duration(seconds: 3),
  }) : _fetchMessagesOverride = fetchMessages,
       _uidProvider = uidProvider ?? (() => AuthState.instance.uid),
       _passwordProvider =
           passwordProvider ?? (() => AuthState.instance.password),
       _processMessagesOverride = processMessages,
       _saveSyncPointOverride = saveSyncPoint,
       _pageDelay = pageDelay,
       _retryDelay = retryDelay;

  @visibleForTesting
  factory MessageSyncService.forTesting({
    required MessageSyncFetcher fetchMessages,
    int uid = 1,
    String password = 'password',
    void Function(String, List<ChatMessage>)? processMessages,
    Future<void> Function(String, int)? saveSyncPoint,
    Duration pageDelay = Duration.zero,
    Duration retryDelay = const Duration(hours: 1),
  }) => MessageSyncService._(
    fetchMessages: fetchMessages,
    uidProvider: () => uid,
    passwordProvider: () => password,
    processMessages: processMessages,
    saveSyncPoint: saveSyncPoint,
    pageDelay: pageDelay,
    retryDelay: retryDelay,
  );

  static MessageSyncService? _instance;
  static MessageSyncService get instance =>
      _instance ??= MessageSyncService._();

  static const int _syncBatchSize = 100;
  static const Duration _defaultBatchDelay = Duration(milliseconds: 300);

  final MessageSyncFetcher? _fetchMessagesOverride;
  final int? Function() _uidProvider;
  final String? Function() _passwordProvider;
  final void Function(String, List<ChatMessage>)? _processMessagesOverride;
  final Future<void> Function(String, int)? _saveSyncPointOverride;
  final Duration _pageDelay;
  final Duration _retryDelay;

  final Map<String, int> _latestSeq = {};
  final Set<String> _syncingRooms = {};
  final Map<String, Set<int>> _queuedMissing = {};
  final Map<String, Set<int>> _inFlightMissing = {};
  final Map<String, Set<int>> _forgottenMissing = {};
  final Map<String, Timer> _retryTimers = {};

  String? activeRoomId;

  void registerRoomSeq(String roomId, int? roomSeq) {
    if (roomSeq == null || roomSeq <= 0) return;
    final current = _latestSeq[roomId];
    if (current == null || roomSeq > current) {
      _latestSeq[roomId] = roomSeq;
    }
  }

  int? lastSeqOf(String roomId) => _latestSeq[roomId];

  /// 撤回消息到达时，把被撤回消息的原位 seq 从缺口队列移除。
  ///
  /// 撤回会把该行挪到序列末尾成为 MICROSOFT GRAVEYARD，原位号永远补不到，留在队列里
  /// 会无限重试（卡死wyf）。记录到 [_forgottenMissing] 以防
  /// [observeMessage] 再次检测到同一缺口或在途批次完成后把它回队。
  void forgetMissingSeq(String roomId, int seq) {
    if (seq <= 0) return;
    _queuedMissing[roomId]?.remove(seq);
    _inFlightMissing[roomId]?.remove(seq);
    _forgottenMissing.putIfAbsent(roomId, () => {}).add(seq);
  }

  void clear() {
    _latestSeq.clear();
    _queuedMissing.clear();
    _inFlightMissing.clear();
    _forgottenMissing.clear();
    _syncingRooms.clear();
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    _retryTimers.clear();
  }

  void observeMessage(String roomId, ChatMessage message) {
    final seq = message.roomSeq;
    if (seq == null || seq <= 0) return;

    final latest = _latestSeq[roomId];
    if (latest == null) {
      _latestSeq[roomId] = seq;
      return;
    }
    if (seq <= latest) return;

    if (seq > latest + 1) {
      final missing = _queuedMissing.putIfAbsent(roomId, () => {});
      final forgotten = _forgottenMissing[roomId];
      for (var value = latest + 1; value < seq; value++) {
        if (forgotten == null || !forgotten.contains(value)) {
          missing.add(value);
        }
      }
      unawaited(_syncMissing(roomId));
    }
    _latestSeq[roomId] = seq;
  }

  /// 按顺序恢复所有已知房间，并同时消费已记录的缺口。
  Future<void> resyncAfterReconnect([
    Iterable<String> knownRoomIds = const [],
  ]) async {
    final roomIds = <String>{
      ...knownRoomIds,
      if (activeRoomId != null) activeRoomId!,
      ..._queuedMissing.keys,
    };
    for (final roomId in roomIds) {
      await _syncMissing(roomId);
      if (_queuedMissing[roomId]?.isNotEmpty == true) continue;
      await _syncRoomIncremental(roomId);
    }
  }

  /// 旧数据只有 last_mid 时，从该消息之后完整分页迁移到 room_seq。
  Future<void> syncRoomFromMid(String roomId, int lastMid) =>
      _syncRoomIncremental(roomId, lastMid: lastMid);

  Future<void> _syncMissing(String roomId) async {
    final missing = _queuedMissing[roomId];
    if (missing == null || missing.isEmpty) return;
    if (_syncingRooms.contains(roomId)) return;

    final uid = _uidProvider();
    final password = _passwordProvider();
    if (uid == null || password == null) return;

    _syncingRooms.add(roomId);
    try {
      while (true) {
        final batch = _queuedMissing[roomId];
        if (batch == null || batch.isEmpty) break;
        final sorted = batch.toList()..sort();
        final requested = sorted.take(_syncBatchSize).toList();
        final remaining = requested.toSet();
        _queuedMissing[roomId] = sorted.skip(_syncBatchSize).toSet();
        _inFlightMissing.putIfAbsent(roomId, () => {}).addAll(requested);

        var retry = false;
        try {
          var hasMore = true;
          while (hasMore && remaining.isNotEmpty) {
            final ranges = _compressRanges(remaining.toList()..sort());
            final result = await _fetchMessages(
              MessageSyncRequest(
                uid: uid,
                password: password,
                roomId: roomId,
                lastSeq: _latestSeq[roomId] ?? 0,
                missingSequences: ranges.singles,
                missingSequenceRanges: ranges.ranges,
                limit: _syncBatchSize,
              ),
            );
            if (result.messages.isNotEmpty) {
              _processMessages(roomId, result.messages);
            }
            var madeProgress = false;
            for (final message in result.messages) {
              final seq = message.roomSeq;
              if (seq != null) {
                registerRoomSeq(roomId, seq);
                madeProgress = remaining.remove(seq) || madeProgress;
              }
            }
            // 服务端 seq 空间只增不减（u must follow it！），
            final gone = remaining
                .where((seq) => seq < result.currentSeq)
                .toSet();
            if (gone.isNotEmpty) {
              talker.info(
                'MessageSyncService: dropped permanently missing seqs '
                '$gone in $roomId',
              );
              remaining.removeAll(gone);
              _forgottenMissing.putIfAbsent(roomId, () => {}).addAll(gone);
            }
            hasMore = result.hasMore;
            if (remaining.isNotEmpty && !hasMore) {
              retry = true;
              break;
            }
            if (hasMore && !madeProgress && remaining.isNotEmpty) {
              throw StateError('Gap sync did not advance for $roomId');
            }
            if (hasMore) await Future<void>.delayed(_pageDelay);
          }
        } catch (e, stack) {
          talker.error(
            'MessageSyncService gap sync failed for $roomId',
            e,
            stack,
          );
          retry = true;
        } finally {
          _inFlightMissing.putIfAbsent(roomId, () => {}).removeAll(requested);
        }
        if (retry) {
          final forgotten = _forgottenMissing[roomId];
          if (forgotten != null && forgotten.isNotEmpty) {
            remaining.removeAll(forgotten);
          }
          _queuedMissing.putIfAbsent(roomId, () => {}).addAll(remaining);
          _scheduleRetry(roomId);
          break;
        }
      }
    } finally {
      _syncingRooms.remove(roomId);
      // bulk action processing complete!
      // ——GitHub Notifications
      //
      // 被吃了的不可能再入队，可安全清理，避免集合无界增长。
      _pruneForgotten(roomId);
    }
  }

  void _pruneForgotten(String roomId) {
    final forgotten = _forgottenMissing[roomId];
    if (forgotten == null || forgotten.isEmpty) return;
    final watermark = _latestSeq[roomId];
    if (watermark == null) return;
    forgotten.removeWhere((seq) => seq <= watermark);
    if (forgotten.isEmpty) _forgottenMissing.remove(roomId);
  }

  Future<void> _syncRoomIncremental(String roomId, {int? lastMid}) async {
    if (_syncingRooms.contains(roomId)) return;
    final uid = _uidProvider();
    final password = _passwordProvider();
    if (uid == null || password == null) return;

    final baseline = _latestSeq[roomId];
    if (baseline == null && lastMid == null) {
      talker.info(
        'MessageSyncService: skip incremental sync for $roomId (no baseline)',
      );
      return;
    }

    _syncingRooms.add(roomId);
    var cursor = baseline ?? 0;
    var requestLastMid = lastMid;
    try {
      var hasMore = true;
      while (hasMore) {
        final previousCursor = cursor;
        final result = await _fetchMessages(
          MessageSyncRequest(
            uid: uid,
            password: password,
            roomId: roomId,
            lastSeq: cursor,
            lastMid: requestLastMid,
            limit: _syncBatchSize,
          ),
        );
        requestLastMid = null;

        if (result.messages.isNotEmpty) {
          _processMessages(roomId, result.messages);
          for (final message in result.messages) {
            final seq = message.roomSeq;
            if (seq != null) cursor = max(cursor, seq);
          }
        } else if (lastMid != null && previousCursor == 0 && !result.hasMore) {
          // last_mid 后没有新消息时，current_seq 是该旧消息唯一可用的序号基线。
          cursor = result.currentSeq;
        }

        hasMore = result.hasMore;
        if (hasMore && cursor <= previousCursor) {
          throw StateError('Message sync did not advance for $roomId');
        }
        if (hasMore) await Future<void>.delayed(_pageDelay);
      }

      if (cursor > 0) {
        registerRoomSeq(roomId, cursor);
        await _saveSyncPoint(roomId, cursor);
      }
    } catch (e, stack) {
      talker.error(
        'MessageSyncService incremental sync failed for $roomId',
        e,
        stack,
      );
    } finally {
      _syncingRooms.remove(roomId);
    }
  }

  /// 没有任何本地同步点的新房间，以服务端当前序号建立空基线。
  Future<void> establishBaseline(String roomId) async {
    if (_latestSeq.containsKey(roomId)) return;
    final uid = _uidProvider();
    final password = _passwordProvider();
    if (uid == null || password == null) return;
    try {
      final result = await _fetchMessages(
        MessageSyncRequest(
          uid: uid,
          password: password,
          roomId: roomId,
          limit: 1,
        ),
      );
      registerRoomSeq(roomId, result.currentSeq);
      if (result.currentSeq > 0) {
        await _saveSyncPoint(roomId, result.currentSeq);
      }
    } catch (e, stack) {
      talker.error('MessageSyncService baseline failed for $roomId', e, stack);
    }
  }

  Future<MessageSyncResult> _fetchMessages(MessageSyncRequest request) {
    final override = _fetchMessagesOverride;
    if (override != null) return override(request);
    return TfApiClient.instance.syncMessages(
      request.uid,
      request.password,
      request.roomId,
      lastSeq: request.lastSeq,
      lastMid: request.lastMid,
      missingSequences: request.missingSequences,
      missingSequenceRanges: request.missingSequenceRanges,
      limit: request.limit,
      throwOnFailure: true,
    );
  }

  void _processMessages(String roomId, List<ChatMessage> messages) {
    final override = _processMessagesOverride;
    if (override != null) {
      override(roomId, messages);
    } else {
      ChatDataService.instance.processSyncedMessages(roomId, messages);
    }
  }

  Future<void> _saveSyncPoint(String roomId, int seq) {
    final override = _saveSyncPointOverride;
    if (override != null) return override(roomId, seq);
    return LocalMessageStore.instance.saveRoomSyncPoint(roomId, seq);
  }

  void _scheduleRetry(String roomId) {
    final existing = _retryTimers[roomId];
    if (existing?.isActive == true) return;
    _retryTimers[roomId] = Timer(_retryDelay, () {
      _retryTimers.remove(roomId);
      unawaited(_syncMissing(roomId));
    });
  }

  @visibleForTesting
  void queueMissingForTesting(String roomId, Iterable<int> sequences) {
    _queuedMissing.putIfAbsent(roomId, () => {}).addAll(sequences);
  }

  @visibleForTesting
  Set<int> queuedMissingForTesting(String roomId) =>
      Set.unmodifiable(_queuedMissing[roomId] ?? const {});

  @visibleForTesting
  Future<void> syncMissingForTesting(String roomId) => _syncMissing(roomId);

  @visibleForTesting
  Future<void> syncRoomIncrementalForTesting(String roomId) =>
      _syncRoomIncremental(roomId);

  static ({List<int> singles, List<Map<String, int>> ranges}) _compressRanges(
    List<int> sorted,
  ) => compressMissingRanges(sorted);

  static ({List<int> singles, List<Map<String, int>> ranges})
  compressMissingRanges(List<int> sorted) {
    final singles = <int>[];
    final ranges = <Map<String, int>>[];
    var i = 0;
    while (i < sorted.length) {
      var j = i;
      while (j + 1 < sorted.length && sorted[j + 1] == sorted[j] + 1) {
        j++;
      }
      if (i == j) {
        singles.add(sorted[i]);
      } else {
        ranges.add({'start_seq': sorted[i], 'end_seq': sorted[j]});
      }
      i = j + 1;
    }
    return (singles: singles, ranges: ranges);
  }
}
