import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/message_model.dart';
import '../utils/talker.dart';

/// Lightweight local message persistence using JSON files.
/// One file per room per user per server: `app_dir/touchfish_messages/server/uid/roomId.json`
/// Messages are pruned to [_maxMessagesPerRoom] per room (oldest first).
class LocalMessageStore {
  static const _maxMessagesPerRoom = 500;

  static LocalMessageStore? _instance;
  static LocalMessageStore get instance => _instance ??= LocalMessageStore._();
  LocalMessageStore._();

  String? _basePath;
  int? _currentUid;
  String _serverKey = 'default';
  final Map<String, Future<void>> _pendingRoomWrites = {};

  /// Set the server identifier so storage is scoped per server.
  void setServerKey(String host, int port) {
    _serverKey = '${host}_$port';
    _basePath = null;
  }

  /// Set the current user UID so storage is scoped per account.
  void setUid(int uid) {
    if (_currentUid != uid) {
      _currentUid = uid;
      _basePath = null;
    }
  }

  Future<String> get _dir async {
    if (_basePath != null) return _basePath!;
    final uid = _currentUid ?? 0;
    if (kIsWeb) {
      _basePath = 'touchfish_messages/$_serverKey/$uid';
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      _basePath = p.join(appDir.path, 'touchfish_messages', _serverKey, uid.toString());
    }
    final dir = Directory(_basePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _basePath!;
  }

  String _roomPath(String base, String roomId) => p.join(base, '$roomId.json');

  Future<void> _waitForPendingWrite(String roomId) async {
    final pending = _pendingRoomWrites[roomId];
    if (pending != null) {
      try {
        await pending;
      } catch (_) {}
    }
  }

  Future<void> _enqueueRoomWrite(String roomId, Future<void> Function() action) {
    final previous = _pendingRoomWrites[roomId] ?? Future.value();
    final next = previous.catchError((_) {}).then((_) => action());
    _pendingRoomWrites[roomId] = next.whenComplete(() {
      if (identical(_pendingRoomWrites[roomId], next)) {
        _pendingRoomWrites.remove(roomId);
      }
    });
    return next;
  }

  bool _matchesMessage(ChatMessage existing, ChatMessage candidate) {
    if (existing.id == candidate.id) return true;
    final existingClientMid = existing.clientMid;
    final candidateClientMid = candidate.clientMid;
    return existingClientMid != null &&
        candidateClientMid != null &&
        existingClientMid == candidateClientMid;
  }

  Future<List<ChatMessage>> loadMessages(String roomId) async {
    try {
      await _waitForPendingWrite(roomId);
      final base = await _dir;
      final file = File(_roomPath(base, roomId));
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      talker.error('LocalMessageStore loadMessages error', e);
      return [];
    }
  }

  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    await _enqueueRoomWrite(roomId, () async {
      try {
        final base = await _dir;
        final file = File(_roomPath(base, roomId));
        var pruned = messages;
        if (pruned.length > _maxMessagesPerRoom) {
          pruned = pruned.sublist(pruned.length - _maxMessagesPerRoom);
        }
        final list = pruned.map((m) => m.toJson()).toList();
        await file.writeAsString(jsonEncode(list));
      } catch (e) {
        talker.error('LocalMessageStore saveMessages error', e);
      }
    });
  }

  Future<void> appendMessage(String roomId, ChatMessage msg) async {
    await _enqueueRoomWrite(roomId, () async {
      final base = await _dir;
      final file = File(_roomPath(base, roomId));
      List<ChatMessage> existing = [];
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final list = jsonDecode(content) as List<dynamic>;
          existing = list
              .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (e) {
          talker.error('LocalMessageStore appendMessage read error', e);
        }
      }
      final exists = existing.any((m) => _matchesMessage(m, msg));
      if (!exists) {
        existing.add(msg);
        if (existing.length > _maxMessagesPerRoom) {
          existing.removeAt(0);
        }
        final list = existing.map((m) => m.toJson()).toList();
        await file.writeAsString(jsonEncode(list));
      }
    });
  }

  Future<void> deleteRoom(String roomId) async {
    await _enqueueRoomWrite(roomId, () async {
      try {
        final base = await _dir;
        final file = File(_roomPath(base, roomId));
        if (await file.exists()) await file.delete();
      } catch (e) {
        talker.error('LocalMessageStore deleteRoom error', e);
      }
    });
  }
}
