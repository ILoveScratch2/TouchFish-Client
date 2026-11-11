import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
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
    // 带版本号的有序迁移：以后加列/改索引就在这里追加一步，
    // 不用再猜“老用户的库里到底有没有这个表”。
    var version = (db.select('PRAGMA user_version').first.values.first as int?) ?? 0;
    final initialVersion = version;
    if (version < 1) {
      _createBaseSchema(db);
      db.execute('PRAGMA user_version = 1');
      version = 1;
    }
    if (version < 2) {
      // 先把表/触发器建好（这样导入历史数据时写入也算数），回填放在导入之后
      _createSearchSchema(db);
    }
    final uri = Uri.parse(server);
    final legacyServer = '${uri.host}_${uri.port}';
    await _importSharedDatabase(db, dir, server, legacyServer);
    await _importLegacyFiles(db, server, legacyServer);
    await _migrateSyncPoints(db);
    if (version < 2) {
      _backfillSearch(db);
      db.execute('PRAGMA user_version = 2');
      version = 2;
    }
    if (initialVersion == 2) {
      // v2 的 unicode61 只做「前缀」匹配：中文里搜「鱼」找不到「摸鱼」，
      // 与旧 LIKE / Web 端的子串语义不一致。v3 换成 trigram 并重建一次索引。
      _rebuildSearchIndex(db);
      version = 3;
    } else if (version == 2) {
      // 本次刚按当前（trigram）定义建好，不需要重建
      version = 3;
    }
    if (initialVersion == 3) {
      // v3 索引的正文取错了键（payload.content，实际落盘是 payload.text），
      // 索引里全是空串；重建一次，升级前的历史消息才能重新搜到。
      _rebuildSearchIndex(db);
      version = 4;
    } else if (version == 3) {
      version = 4;
    }
    if (version != initialVersion) {
      db.execute('PRAGMA user_version = $version');
    }
    _databases[_dbKey(server, uid)] = db;
    return db;
  }

  void _createBaseSchema(Database db) {
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
  }

  /// trigram 索引比查询串更短时无法命中（见 [_ftsMinQueryLength]）。
  static const int _ftsMinQueryLength = 3;

  /// 本地消息的可搜索正文。
  ///
  /// 落盘的是 `ChatMessage.toJson()`，正文键是 `text`（camelCase）；
  /// 更早的导出快照里还见过 `content`，这里都认，避免老数据整库搜不到。
  /// 只取正文：直接扫整条 payload 会把 hash / 文件名 / 时间戳也当命中，
  /// 于是 2 字关键词和 3 字关键词的结果集对不上。
  @visibleForTesting
  static const String searchableTextSql =
      "COALESCE(json_extract(payload, '\$.text'), "
      "json_extract(payload, '\$.content'), '')";

  /// 子串兜底与 FTS 必须搜同一段文本（见 [searchableTextSql]）。
  @visibleForTesting
  static const String contentSubstringMatch =
      'instr(lower($searchableTextSql), ?) > 0';

  /// FTS5 全文索引：搜索不再对整条 payload 做 `LIKE '%q%'` 全表扫描。
  ///
  /// 用一张普通表 `message_search` 承载可搜索文本，FTS 通过 external content
  /// 与触发器同步；这样更新/删除能精确按主键命中，不会在 FTS 里留重复行。
  ///
  /// tokenizer 必须是 trigram：unicode61 只按词/前缀匹配，中文里「摸鱼」会被
  /// 当成一个 token，搜「鱼」直接搜不到——那是比全表扫描更糟的回归。
  void _createSearchSchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS message_search (
        server_key TEXT NOT NULL,
        uid INTEGER NOT NULL,
        room_id TEXT NOT NULL,
        message_key TEXT NOT NULL,
        text TEXT NOT NULL,
        PRIMARY KEY (server_key, uid, room_id, message_key)
      )
    ''');
    try {
      db.execute('''
        CREATE VIRTUAL TABLE IF NOT EXISTS message_search_fts USING fts5(
          text,
          content='message_search',
          content_rowid='rowid',
          tokenize='trigram'
        )
      ''');
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS message_search_ai
        AFTER INSERT ON message_search BEGIN
          INSERT INTO message_search_fts(rowid, text) VALUES (new.rowid, new.text);
        END
      ''');
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS message_search_ad
        AFTER DELETE ON message_search BEGIN
          INSERT INTO message_search_fts(message_search_fts, rowid, text)
          VALUES ('delete', old.rowid, old.text);
        END
      ''');
      db.execute('''
        CREATE TRIGGER IF NOT EXISTS message_search_au
        AFTER UPDATE ON message_search BEGIN
          INSERT INTO message_search_fts(message_search_fts, rowid, text)
          VALUES ('delete', old.rowid, old.text);
          INSERT INTO message_search_fts(rowid, text) VALUES (new.rowid, new.text);
        END
      ''');
    } catch (e) {
      // 某些平台没有 FTS5：退回 LIKE 搜索，不影响启动
      talker.warning('LocalMessageStore: FTS5 unavailable, falling back: $e');
    }
  }

  /// 把旧版 unicode61 索引换成 trigram（v2 → v3）。只跑一次。
  void _rebuildSearchIndex(Database db) {
    try {
      db.execute('DROP TRIGGER IF EXISTS message_search_ai');
      db.execute('DROP TRIGGER IF EXISTS message_search_ad');
      db.execute('DROP TRIGGER IF EXISTS message_search_au');
      db.execute('DROP TABLE IF EXISTS message_search_fts');
    } catch (e) {
      talker.warning('LocalMessageStore: drop old search index failed: $e');
    }
    _createSearchSchema(db);
    _backfillSearch(db);
  }

  void _backfillSearch(Database db) {
    final exists = db.select(
      "SELECT 1 FROM sqlite_master WHERE type='table' AND name='message_search_fts'",
    );
    if (exists.isEmpty) return;
    try {
      db.execute('''
        INSERT OR REPLACE INTO message_search
          (server_key, uid, room_id, message_key, text)
        SELECT server_key, uid, room_id, message_key, $searchableTextSql
        FROM messages
      ''');
    } catch (e) {
      talker.warning('LocalMessageStore: search backfill failed: $e');
    }
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

  /// 房间是否被标记为"完整同步"（仅浏览模式用，已打开的会话升级后持久化）。
  Future<Set<String>> loadSyncEnabledRooms() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final rows = db.select(
      "SELECT key FROM metadata WHERE key LIKE 'sync_enabled:%'",
    );
    const prefix = 'sync_enabled:';
    return {
      for (final row in rows) (row['key'] as String).substring(prefix.length),
    };
  }

  Future<void> setRoomSyncEnabled(String roomId, bool enabled) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    if (enabled) {
      db.execute('INSERT OR REPLACE INTO metadata(key, value) VALUES (?, ?)', [
        'sync_enabled:$roomId',
        '1',
      ]);
    } else {
      db.execute('DELETE FROM metadata WHERE key = ?', ['sync_enabled:$roomId']);
    }
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
    final key = _key(message);
    db.execute(
      '''
      INSERT INTO messages(server_key, uid, room_id, message_key, timestamp, payload)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(server_key, uid, room_id, message_key) DO UPDATE SET
        timestamp = excluded.timestamp, payload = excluded.payload
      WHERE messages.timestamp IS NOT excluded.timestamp
         OR messages.payload IS NOT excluded.payload
    ''',
      [
        server,
        uid,
        room,
        key,
        message.timestamp.millisecondsSinceEpoch,
        jsonEncode(message.toJson()),
      ],
    );
    // 全文索引文本（表在 v2 迁移时创建；触发器会同步到 FTS）
    try {
      db.execute(
        '''
        INSERT INTO message_search(server_key, uid, room_id, message_key, text)
        VALUES (?, ?, ?, ?, ?)
        ON CONFLICT(server_key, uid, room_id, message_key)
        DO UPDATE SET text = excluded.text
        WHERE message_search.text IS NOT excluded.text
      ''',
        [server, uid, room, key, message.text],
      );
    } catch (_) {
      // 迁移尚未完成（v1 老库首次打开时的导入路径）：回填会补上
    }
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

  /// 单条 upsert（含已存在消息的字段升级，如 ack 回填/撤回）。
  Future<void> saveMessage(String roomId, ChatMessage message) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    try {
      final db = await _db(server, uid);
      _upsert(db, server, uid, roomId, message);
    } catch (e) {
      talker.error('LocalMessageStore saveMessage error', e);
    }
  }

  /// 事务批量 upsert，用于同步补拉等成批写入。
  Future<void> appendMessages(
    String roomId,
    List<ChatMessage> messages,
  ) async {
    if (messages.isEmpty) return;
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
      talker.error('LocalMessageStore appendMessages error', e);
    }
  }

  Future<void> deleteMessage(String roomId, ChatMessage message) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    final db = await _db(server, uid);
    final key = _key(message);
    db.execute(
      'DELETE FROM messages WHERE server_key = ? AND uid = ? AND room_id = ? AND message_key = ?',
      [server, uid, roomId, key],
    );
    _deleteSearchRows(db,
        'server_key = ? AND uid = ? AND room_id = ? AND message_key = ?',
        [server, uid, roomId, key]);
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
    _deleteSearchRows(
      db,
      'server_key = ? AND uid = ? AND room_id = ?',
      [server, uid, roomId],
    );
  }

  void _deleteSearchRows(Database db, String where, List<Object?> params) {
    try {
      db.execute('DELETE FROM message_search WHERE $where', params);
    } catch (_) {
      // 老库尚未完成 v2 迁移
    }
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
        try {
          db.execute(
            '''INSERT INTO message_search
                 (server_key, uid, room_id, message_key, text)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(server_key, uid, room_id, message_key)
               DO UPDATE SET text = excluded.text''',
            [scope.server, scope.uid, roomId, messageKey,
             payload['text']?.toString() ??
                 payload['content']?.toString() ??
                 ''],
          );
        } catch (_) {}
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

  /// 关闭所有已打开的连接（测试用：Windows 上文件句柄不释放就删不掉临时库）。
  @visibleForTesting
  void closeAllForTesting() {
    for (final db in _databases.values) {
      db.dispose();
    }
    _databases.clear();
    _openingDatabases.clear();
    _scope = null;
  }

  Future<void> clearDatabase() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    db.execute('DELETE FROM messages WHERE server_key = ? AND uid = ?', [
      scope.server,
      scope.uid,
    ]);
    _deleteSearchRows(
      db,
      'server_key = ? AND uid = ?',
      [scope.server, scope.uid],
    );
  }

  /// web 端 localStorage 配额是 hyw
  Future<void> emergencyTrimForQuota() async {}

  Future<List<ChatMessage>> loadAllMessages(String roomId) async {
    return loadMessages(roomId);
  }

  /// 按服务端消息 id（mid）定位单条消息。
  ///
  /// 服务端消息的 message_key 固定为 "id:$mid"（见 [_key]），可直接走主键索引。
  Future<ChatMessage?> findMessageByMid(String roomId, int mid) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    try {
      final rows = db.select(
        'SELECT payload FROM messages '
        'WHERE server_key = ? AND uid = ? AND room_id = ? AND message_key = ?',
        [scope.server, scope.uid, roomId, 'id:$mid'],
      );
      if (rows.isEmpty) return null;
      return ChatMessage.fromJson(
        jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>,
        activeUid: scope.uid,
      );
    } catch (e) {
      talker.error('LocalMessageStore findMessageByMid error', e);
      return null;
    }
  }

  Future<List<LocalMessageSearchResult>> searchAllRooms(
    String query, {
    int limit = 200,
  }) async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    // trigram 只索引 ≥3 字符的子串。更短的查询（中文里很常见，比如「鱼」）
    // 必须走子串扫描，否则会静默搜不到东西。
    ResultSet rows;
    if (trimmed.runes.length >= _ftsMinQueryLength) {
      try {
        rows = db.select(
          '''SELECT m.room_id, m.payload FROM message_search_fts f
             JOIN message_search s ON s.rowid = f.rowid
             JOIN messages m
               ON m.server_key = s.server_key AND m.uid = s.uid
              AND m.room_id = s.room_id AND m.message_key = s.message_key
             WHERE message_search_fts MATCH ?
               AND s.server_key = ? AND s.uid = ?
             ORDER BY m.timestamp DESC LIMIT ?''',
          [_ftsPhrase(trimmed), scope.server, scope.uid, limit],
        );
      } catch (e) {
        // FTS5 不可用 / 索引还没建好：退回子串扫描（慢，但保证能搜到）
        talker.warning('LocalMessageStore: FTS search failed, falling back: $e');
        rows = _substringSearch(db, scope.server, scope.uid, trimmed, limit);
      }
    } else {
      rows = _substringSearch(db, scope.server, scope.uid, trimmed, limit);
    }
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

  /// 子串扫描兜底：用 instr 而不是 LIKE，查询里的 % / _ 不需要转义。
  /// 只看 payload 里的正文（与 FTS、Web 端、聊天内搜索的子串语义一致）。
  ResultSet _substringSearch(
    Database db,
    String server,
    int uid,
    String query,
    int limit,
  ) {
    return db.select(
      '''SELECT room_id, payload FROM messages
         WHERE server_key = ? AND uid = ?
           AND $contentSubstringMatch
         ORDER BY timestamp DESC LIMIT ?''',
      [server, uid, query.toLowerCase(), limit],
    );
  }

  /// trigram FTS 的子串查询：整段加引号当 phrase，
  /// 避免 -、*、OR 之类的字符被当成查询语法。
  String _ftsPhrase(String query) =>
      '"${query.replaceAll('"', '""')}"';
}
