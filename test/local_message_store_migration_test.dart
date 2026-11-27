import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/local_message_store_native.dart';

/// flutter test 会注册桌面端的 path_provider 实现（FFI），
/// 只 mock 方法通道拿不到目录，这里直接换掉平台实例。
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.rootPath);

  final String rootPath;

  @override
  Future<String?> getApplicationSupportPath() async => rootPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => rootPath;
}

const String _messagesTable = '''
  CREATE TABLE messages (
    server_key TEXT NOT NULL,
    uid INTEGER NOT NULL,
    room_id TEXT NOT NULL,
    message_key TEXT NOT NULL,
    timestamp INTEGER NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY (server_key, uid, room_id, message_key)
  )
''';

String _payload(String text) => jsonEncode(
  ChatMessage(
    id: 'm1',
    mid: 1,
    text: text,
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
    isMe: false,
  ).toJson(),
);

String _dbFile(Directory root, String server, int uid) {
  final dir = Directory(p.join(root.path, 'touchfish'))
    ..createSync(recursive: true);
  final encoded = base64Url.encode(utf8.encode(server)).replaceAll('=', '');
  return p.join(dir.path, 'messages_${encoded}_$uid.sqlite3');
}

int _userVersion(String path) {
  final db = sqlite3.open(path);
  try {
    return db.select('PRAGMA user_version').first.values.first as int;
  } finally {
    db.dispose();
  }
}

/// 本地库的升级路径：
/// - 已发布的老版本从没写过 user_version（0），首次打开要建全文索引；
/// - 中途的 v3 把正文取成了 payload.content（实际落盘是 payload.text），
///   索引里全是空串，打开时要重建一次，否则历史消息整库搜不到。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late PathProviderPlatform previousProvider;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('tf-lms-migrate-');
    previousProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(root.path);
  });

  tearDown(() async {
    LocalMessageStore.instance.closeAllForTesting();
    PathProviderPlatform.instance = previousProvider;
    await root.delete(recursive: true);
  });

  test('v4 scoped keys preserve group senders, search rows, imports and self echoes', () async {
    const server = 'https://sender-keys.test';
    const uid = 9;
    const room = 'G15';
    final store = LocalMessageStore.instance;
    store.configureScope(server, uid);
    final path = (await store.databasePath())!;
    store.closeAllForTesting();
    ChatMessage msg(int? mid, int? sender, bool self) => ChatMessage(
      id: mid?.toString() ?? 'shared', mid: mid, clientMid: 'shared', senderUid: sender,
      timestamp: DateTime.utc(2026), text: 'sender body $mid', isMe: self,
      status: mid == null ? MessageStatus.pending : MessageStatus.sent);
    final old = msg(11, 0, false);
    final seed = sqlite3.open(path);
    seed.execute('PRAGMA user_version = 4');
    seed.execute('INSERT INTO messages VALUES (?, ?, ?, ?, ?, ?)',
        [server, uid, room, 'client:shared', 1, jsonEncode(old.toJson())]);
    seed.execute('INSERT INTO message_search VALUES (?, ?, ?, ?, ?)',
        [server, uid, room, 'client:shared', old.text]);
    seed.dispose();

    store.configureScope(server, uid);
    expect((await store.findMessageByMid(room, 11))?.senderUid, 0);
    expect((await store.searchAllRooms('sender body')).length, 1);
    await Future.wait([store.saveMessage(room, msg(null, 0, true)), store.saveMessage(room, msg(12, 7, false))]);
    await store.saveMessage(room, msg(13, uid, true));
    final backup = {
      'messages': [
        {'roomId': room, 'messageKey': 'client:shared', 'timestamp': 2, 'payload': msg(14, 8, false).toJson()},
        {'roomId': room, 'messageKey': 'client:shared', 'timestamp': 3, 'payload': msg(15, null, false).toJson()},
      ],
    };
    await store.importSnapshot(backup);
    await store.saveMessage(room, msg(15, 17, false));
    store.closeAllForTesting();
    store.configureScope(server, uid);
    final saved = await store.loadMessages(room);
    expect(saved.map((m) => m.mid).toSet(), {11, 12, 13, 14, 15});
    expect(saved.length, 5);
    expect((await store.searchAllRooms('sender body')).length, 5);
    await store.deleteMessage(room, old);
    expect((await store.loadMessages(room)).length, 4);
    expect(await store.findMessageByMid(room, 11), isNull);
  });

  test('a v0 database from the previous release gets indexed on open', () async {
    const server = 'https://v0.test';
    const uid = 9;
    final store = LocalMessageStore.instance;
    final dbFile = _dbFile(root, server, uid);

    final seed = sqlite3.open(dbFile);
    seed.execute(_messagesTable);
    seed.execute('INSERT INTO messages VALUES (?, ?, ?, ?, ?, ?)', [
      server,
      uid,
      'U1',
      'm1',
      1000,
      _payload('摸鱼真开心'),
    ]);
    seed.dispose();

    store.configureScope(server, uid);

    final long = await store.searchAllRooms('摸鱼真');
    expect(long, hasLength(1));
    expect(long.single.message.text, '摸鱼真开心');

    final short = await store.searchAllRooms('摸鱼');
    expect(short, hasLength(1));

    expect(_userVersion(dbFile), 5);
  });

  test('a v3 database re-indexes history from the payload text field', () async {
    const server = 'https://v3.test';
    const uid = 7;
    final store = LocalMessageStore.instance;
    final dbFile = _dbFile(root, server, uid);

    final seed = sqlite3.open(dbFile);
    seed.execute(_messagesTable);
    seed.execute('''
      CREATE TABLE message_search (
        server_key TEXT NOT NULL,
        uid INTEGER NOT NULL,
        room_id TEXT NOT NULL,
        message_key TEXT NOT NULL,
        text TEXT NOT NULL,
        PRIMARY KEY (server_key, uid, room_id, message_key)
      )
    ''');
    seed.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    seed.execute('INSERT INTO messages VALUES (?, ?, ?, ?, ?, ?)', [
      server,
      uid,
      'U1',
      'm1',
      1000,
      _payload('摸鱼真开心'),
    ]);
    // v3 的 bug 现场：索引行存在，但正文是空串。
    seed.execute('INSERT INTO message_search VALUES (?, ?, ?, ?, ?)', [
      server,
      uid,
      'U1',
      'm1',
      '',
    ]);
    seed.execute('PRAGMA user_version = 3');
    seed.dispose();

    store.configureScope(server, uid);

    final long = await store.searchAllRooms('摸鱼真');
    expect(long, hasLength(1));
    expect(long.single.message.text, '摸鱼真开心');

    final short = await store.searchAllRooms('摸鱼');
    expect(short, hasLength(1));

    expect(_userVersion(dbFile), 5, reason: '升级旧库时须重建搜索索引');

    final check = sqlite3.open(dbFile);
    try {
      final hasFts = check
          .select(
            "SELECT 1 FROM sqlite_master WHERE type='table' "
            "AND name='message_search_fts'",
          )
          .isNotEmpty;
      if (hasFts) {
        final indexed = check.select(
          'SELECT text FROM message_search WHERE message_key = ?',
          ['m1'],
        );
        expect(indexed.single['text'], '摸鱼真开心');
      }
    } finally {
      check.dispose();
    }
  });
}
