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

    expect(_userVersion(dbFile), 4);
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

    expect(_userVersion(dbFile), 4, reason: 'v3 必须迁移到 v4 并重建索引');

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
