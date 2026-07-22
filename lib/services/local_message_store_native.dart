import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../models/message_model.dart';
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
    _databases[_dbKey(server, uid)] = db;
    return db;
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

  Future<List<ChatMessage>> loadMessages(String roomId) async {
    final scope = _requireScope();
    final server = scope.server;
    final uid = scope.uid;
    try {
      final db = await _db(server, uid);
      final rows = db.select(
        'SELECT payload FROM messages WHERE server_key = ? AND uid = ? AND room_id = ? ORDER BY timestamp ASC',
        [server, uid, roomId],
      );
      return rows
          .map(
            (row) => ChatMessage.fromJson(
              jsonDecode(row['payload'] as String) as Map<String, dynamic>,
              activeUid: uid,
            ),
          )
          .toList();
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

  Future<void> clearDatabase() async {
    final scope = _requireScope();
    final db = await _db(scope.server, scope.uid);
    db.execute('DELETE FROM messages WHERE server_key = ? AND uid = ?', [
      scope.server,
      scope.uid,
    ]);
  }
}
