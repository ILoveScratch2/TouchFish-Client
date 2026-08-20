import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/message_model.dart';
import '../models/local_message_search_result.dart';
import '../utils/talker.dart';

class LocalMessageStore {
  static LocalMessageStore? _instance;
  static LocalMessageStore get instance => _instance ??= LocalMessageStore._();
  LocalMessageStore._();

  // Key format: "$server\x00$uid"
  final Map<String, Database> _databases = {};
  final Map<String, Future<Database>> _openingDatabases = {};
  ({String server, int uid})? _scope;

  void configureScope(String serverAddress, int uid) {
    final uri = Uri.parse(serverAddress);
    final key = uri
        .replace(
          scheme: uri.scheme.toLowerCase(),
          host: uri.host.toLowerCase(),
          path: uri.path.replaceFirst(RegExp(r'/$'), ''),
        )
        .toString();
    _scope = (server: key, uid: uid);
  }

  void clearScope() => _scope = null;

  ({String server, int uid})? get currentScope => _scope;

  ({String server, int uid}) _requireScope() {
    final scope = _scope;
    if (scope == null) {
      throw StateError('LocalMessageStore scope is not configured');
    }
    return scope;
  }

  String _dbKey(String server, int uid) => '$server\x00$uid';

  Future<Database> _db(String server, int uid) async {
    final key = _dbKey(server, uid);
    final existing = _databases[key];
    if (existing != null) return existing;
    final opening = _openingDatabases[key] ??= _open(server, uid);
    try {
      return await opening;
    } finally {
      _openingDatabases.remove(key);
    }
  }

  Future<Database> _open(String server, int uid) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'touchfish'));
    await dir.create(recursive: true);
    final encodedServer = base64Url
        .encode(utf8.encode(server))
        .replaceAll('=', '');
    final file = p.join(dir.path, 'messages_${encodedServer}_$uid.sqlite3');
    final db = sqlite3.open(file);
    db.execute('PRAGMA busy_timeout = 10000');
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        server_key TEXT NOT NULL,
        uid INTEGER NOT NULL,
        room_id TEXT NOT NULL,
        message_key TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (server_key, uid, room_id, message_key)
      )
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS messages_room_time ON messages(server_key, uid, room_id, timestamp)',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    final uri = Uri.parse(server);
    final legacyServer = '${uri.host}_${uri.port}';
    await _importSharedDatabase(db, dir, server, legacyServer);
    await _importLegacyFiles(db, server, legacyServer);
    await _migrateSyncPoints(db);
    _databases[_dbKey(server, uid)] = db;
    return db;
  }

  /// 迁移!
  /// 旧版本 payload 没有 room_seq，无法直接得知服务端序号。为每个房间计算
  /// 本地最大 mid，作为 last_mid 同步点（服务端 mid 与 room_seq 同序），
  /// 升级后只补拉升级期间的新消息，避免全量重拉。
  Future<void> _migrateSyncPoints(Database db) async {
    final migrated = db.select('SELECT value FROM metadata WHERE key = ?', [
      'sync_points_migrated',
    ]);
    if (migrated.isNotEmpty) return;
    db.execute('BEGIN IMMEDIATE');
    try {
      final rows = db.select(
        'SELECT room_id, payload FROM messages '
        'WHERE server_key = ? AND uid = ?',
        [_requireScope().server, _requireScope().uid],
      );
      final maxMidByRoom = <String, int>{};
      for (final row in rows) {
        try {
          final json =
              jsonDecode(row['payload'] as String) as Map<String, dynamic>;
          final mid = (json['mid'] as num?)?.toInt();
          if (mid == null || mid <= 0) continue;
          final room = row['room_id'] as String;
          final current = maxMidByRoom[room];
          if (current == null || mid > current) maxMidByRoom[room] = mid;
        } catch (_) {}
      }
      for (final entry in maxMidByRoom.entries) {
        db.execute(
          'INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)',
          ['sync_mid:${entry.key}', '${entry.value}'],
        );
      }
      db.execute('INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)', [
        'sync_points_migrated',
        '1',
      ]);
      db.execute('COMMIT');
      talker.info(
        'LocalMessageStore: migrated ${maxMidByRoom.length} room sync points',
      );
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<int?> getRoomSyncMid(String roomId) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select('SELECT value FROM metadata WHERE key = ?', [
      'sync_mid:$roomId',
    ]);
    if (rows.isEmpty) return null;
    return int.tryParse(rows.first['value'] as String? ?? '');
  }

  Future<int?> getRoomSyncSeq(String roomId) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select('SELECT value FROM metadata WHERE key = ?', [
      'sync_seq:$roomId',
    ]);
    if (rows.isEmpty) return null;
    return int.tryParse(rows.first['value'] as String? ?? '');
  }

  Future<void> saveRoomSyncPoint(String roomId, int seq) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    db.execute('INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)', [
      'sync_seq:$roomId',
      '$seq',
    ]);
  }

  Future<void> _importSharedDatabase(
    Database db,
    Directory dir,
    String server,
    String legacyServer,
  ) async {
    final migrated = db.select('SELECT value FROM metadata WHERE key = ?', [
      'shared_database_imported',
    ]);
    if (migrated.isNotEmpty) return;
    final sharedFile = File(p.join(dir.path, 'messages.sqlite3'));
    if (await sharedFile.exists()) {
      try {
        final shared = sqlite3.open(sharedFile.path, mode: OpenMode.readOnly);
        try {
          final rows = shared.select(
            'SELECT uid, room_id, message_key, timestamp, payload FROM messages WHERE server_key IN (?, ?)',
            [server, legacyServer],
          );
          db.execute('BEGIN IMMEDIATE');
          try {
            for (final row in rows) {
              db.execute(
                '''
                INSERT OR REPLACE INTO messages(
                  server_key, uid, room_id, message_key, timestamp, payload
                ) VALUES (?, ?, ?, ?, ?, ?)
              ''',
                [
                  server,
                  row['uid'],
                  row['room_id'],
                  row['message_key'],
                  row['timestamp'],
                  row['payload'],
                ],
              );
            }
            db.execute('COMMIT');
          } catch (_) {
            db.execute('ROLLBACK');
            rethrow;
          }
        } finally {
          shared.dispose();
        }
      } catch (e) {
        talker.error('LocalMessageStore shared database import failed', e);
        return;
      }
    }
    db.execute('INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)', [
      'shared_database_imported',
      '1',
    ]);
  }

  Future<void> _importLegacyFiles(
    Database db,
    String server,
    String legacyServer,
  ) async {
    final migrated = db.select('SELECT value FROM metadata WHERE key = ?', [
      'legacy_json_imported',
    ]);
    if (migrated.isNotEmpty) return;
    final legacy = Directory(
      p.join(
        (await getApplicationDocumentsDirectory()).path,
        'touchfish_messages',
      ),
    );
    if (!await legacy.exists()) {
      db.execute('INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)', [
        'legacy_json_imported',
        '1',
      ]);
      return;
    }
    try {
      await for (final entity in legacy.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        final relative = p
            .relative(entity.path, from: legacy.path)
            .split(p.separator);
        if (relative.length < 3) continue;
        if (relative[0] != legacyServer) continue;
        final uid = int.tryParse(relative[1]);
        final room = p.basenameWithoutExtension(relative.last);
        if (uid == null) continue;
        final values = jsonDecode(await entity.readAsString()) as List<dynamic>;
        for (final raw in values) {
          final message = ChatMessage.fromJson(
            Map<String, dynamic>.from(raw as Map),
            activeUid: uid,
          );
          _upsert(db, server, uid, room, message);
        }
      }
      db.execute('INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)', [
        'legacy_json_imported',
        '1',
      ]);
      talker.info('Imported legacy JSON messages into SQLite');
    } catch (e) {
      talker.error('LocalMessageStore legacy import failed', e);
    }
  }

  String _key(ChatMessage message) => message.clientMid?.isNotEmpty == true
      ? 'client:${message.clientMid}'
      : 'id:${message.id}';

  void _upsert(
    Database db,
    String server,
    int uid,
    String room,
    ChatMessage message,
  ) {
    db.execute(
      '''
      INSERT INTO messages(server_key, uid, room_id, message_key, timestamp, payload)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(server_key, uid, room_id, message_key) DO UPDATE SET
        timestamp = excluded.timestamp, payload = excluded.payload
    ''',
      [
        server,
        uid,
        room,
        _key(message),
        message.timestamp.millisecondsSinceEpoch,
        jsonEncode(message.toJson()),
      ],
    );
  }

  Future<List<ChatMessage>> loadMessages(
    String roomId, {
    int? limit,
    ChatMessage? before,
  }) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    try {
      final db = await _db(server, uid);
      final beforeClause = before == null
          ? ''
          : ' AND (timestamp < ? OR (timestamp = ? AND message_key < ?))';
      final limitClause = limit == null ? '' : ' LIMIT ?';
      final parameters = <Object?>[server, uid, roomId];
      if (before != null) {
        parameters.addAll([
          before.timestamp.millisecondsSinceEpoch,
          before.timestamp.millisecondsSinceEpoch,
          _key(before),
        ]);
      }
      if (limit != null) parameters.add(limit);
      final rows = db.select('''
        SELECT payload FROM messages
        WHERE server_key = ? AND uid = ? AND room_id = ?$beforeClause
        ORDER BY timestamp DESC, message_key DESC$limitClause
        ''', parameters);
      final messages = <ChatMessage>[];
      for (final row in rows.reversed) {
        try {
          messages.add(
            ChatMessage.fromJson(
              jsonDecode(row['payload'] as String) as Map<String, dynamic>,
              activeUid: uid,
            ),
          );
        } catch (error) {
          talker.error(
            'LocalMessageStore loadMessages: skip malformed message',
            error,
          );
        }
      }
      return messages;
    } catch (e) {
      talker.error('LocalMessageStore loadMessages error', e);
      return [];
    }
  }

  Future<void> saveMessages(String roomId, List<ChatMessage> messages) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    try {
      final db = await _db(server, uid);
      db.execute('BEGIN IMMEDIATE');
      var inTransaction = true;
      try {
        for (final message in messages) {
          _upsert(db, server, uid, roomId, message);
        }
        db.execute('COMMIT');
        inTransaction = false;
      } finally {
        if (inTransaction) db.execute('ROLLBACK');
      }
    } catch (e) {
      talker.error('LocalMessageStore saveMessages error', e);
    }
  }

  Future<void> appendMessage(String roomId, ChatMessage message) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    try {
      final db = await _db(server, uid);
      _upsert(db, server, uid, roomId, message);
    } catch (e) {
      talker.error('LocalMessageStore appendMessage error', e);
    }
  }

  Future<void> deleteRoom(String roomId) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    final db = await _db(server, uid);
    db.execute(
      'DELETE FROM messages WHERE server_key = ? AND uid = ? AND room_id = ?',
      [server, uid, roomId],
    );
  }

  Future<Map<String, ({int messages, int bytes})>> roomStats() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select(
      '''
      SELECT room_id, COUNT(*) AS message_count,
             COALESCE(SUM(LENGTH(payload)), 0) AS payload_bytes
      FROM messages
      WHERE server_key = ? AND uid = ?
      GROUP BY room_id
      ORDER BY payload_bytes DESC
      ''',
      [scope.server, scope.uid],
    );
    return {
      for (final row in rows)
        row['room_id'] as String: (
          messages: row['message_count'] as int,
          bytes: row['payload_bytes'] as int,
        ),
    };
  }

  Future<int> databaseSize() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select('PRAGMA database_list');
    if (rows.isEmpty) return 0;
    final file = File(rows.first['file'] as String);
    return await file.exists() ? file.length() : 0;
  }

  Future<Map<String, dynamic>> exportSnapshot() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select(
      'SELECT room_id, message_key, timestamp, payload FROM messages WHERE server_key = ? AND uid = ? ORDER BY timestamp ASC',
      [scope.server, scope.uid],
    );
    final exported = <Map<String, dynamic>>[];
    for (final row in rows) {
      try {
        exported.add({
          'roomId': row['room_id'],
          'messageKey': row['message_key'],
          'timestamp': row['timestamp'],
          'payload': jsonDecode(row['payload'] as String),
        });
      } catch (error) {
        talker.error(
          'LocalMessageStore exportSnapshot: skip malformed message',
          error,
        );
      }
    }
    return {
      'server': scope.server,
      'uid': scope.uid,
      'messages': exported,
    };
  }

  Future<int> importSnapshot(Map<String, dynamic> snapshot) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final messages = snapshot['messages'];
    if (messages is! List) return 0;
    var count = 0;
    db.execute('BEGIN IMMEDIATE');
    try {
      for (final raw in messages.whereType<Map>()) {
        final roomId = raw['roomId']?.toString();
        final messageKey = raw['messageKey']?.toString();
        final payload = raw['payload'];
        if (roomId == null || messageKey == null || payload is! Map) continue;
        final timestamp = raw['timestamp'] is num
            ? (raw['timestamp'] as num).toInt()
            : int.tryParse(raw['timestamp']?.toString() ?? '') ?? 0;
        db.execute('''INSERT OR REPLACE INTO messages
          (server_key, uid, room_id, message_key, timestamp, payload)
          VALUES (?, ?, ?, ?, ?, ?)''', [
          scope.server, scope.uid, roomId, messageKey,
          timestamp, jsonEncode(payload),
        ]);
        count++;
      }
      db.execute('COMMIT');
    } catch (_) {
      db.execute('ROLLBACK');
      rethrow;
    }
    return count;
  }

  Future<String?> databasePath() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select('PRAGMA database_list');
    return rows.isEmpty ? null : rows.first['file'] as String;
  }

  Future<void> clearDatabase() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    db.execute('DELETE FROM messages WHERE server_key = ? AND uid = ?', [
      scope.server,
      scope.uid,
    ]);
  }

  Future<List<ChatMessage>> loadAllMessages(String roomId) async {
    return loadMessages(roomId);
  }

  Future<List<LocalMessageSearchResult>> searchAllRooms(
    String query, {
    int limit = 200,
  }) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final needle = '%${query.trim().toLowerCase()}%';
    final rows = db.select(
      '''SELECT room_id, payload FROM messages
         WHERE server_key = ? AND uid = ? AND lower(payload) LIKE ?
         ORDER BY timestamp DESC LIMIT ?''',
      [scope.server, scope.uid, needle, limit],
    );
    final results = <LocalMessageSearchResult>[];
    for (final row in rows) {
      try {
        results.add(LocalMessageSearchResult(
          roomId: row['room_id'] as String,
          message: ChatMessage.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,
            activeUid: scope.uid,
          ),
        ));
      } catch (_) {}
    }
    return results;
  }
}
