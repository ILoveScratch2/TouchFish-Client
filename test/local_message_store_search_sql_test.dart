import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:touchfish_client/models/message_model.dart';
import 'package:touchfish_client/services/local_message_store_native.dart';

ChatMessage _message(int mid, String text, {String? fileName}) => ChatMessage(
  id: '$mid',
  mid: mid,
  text: text,
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
  isMe: false,
  media: fileName == null
      ? null
      : MessageMedia(path: 'local', fileName: fileName),
);

String _payload(ChatMessage message) => jsonEncode(message.toJson());

void main() {
  test('searchable text reads the key ChatMessage.toJson actually writes', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute(
      'CREATE TABLE messages (room_id TEXT, payload TEXT, timestamp INTEGER)',
    );
    // 真实落盘格式：ChatMessage.toJson() 的正文键是 text（camelCase）。
    db.execute('INSERT INTO messages VALUES (?, ?, ?)', [
      'U1',
      _payload(_message(1, '摸鱼', fileName: 'abc.pdf')),
      1,
    ]);
    db.execute('INSERT INTO messages VALUES (?, ?, ?)', [
      'U2',
      _payload(_message(2, 'abc 摸鱼')),
      2,
    ]);
    // 更早的导出快照里只带 content，仍要能搜到。
    db.execute('INSERT INTO messages VALUES (?, ?, ?)', [
      'U3',
      jsonEncode({'content': '旧快照 abc'}),
      3,
    ]);

    // FTS 回填和子串兜底共用这个表达式：必须真的取到正文。
    final texts = db.select(
      'SELECT room_id, ${LocalMessageStore.searchableTextSql} AS text '
      'FROM messages '
      'ORDER BY timestamp',
    );
    expect(texts.map((row) => row['text']), [
      '摸鱼',
      'abc 摸鱼',
      '旧快照 abc',
    ]);

    final fallback = db.select(
      'SELECT room_id FROM messages WHERE '
      '${LocalMessageStore.contentSubstringMatch} ORDER BY timestamp DESC',
      ['abc'],
    );
    // 子串兜底与 FTS 保持一致：只看正文，文件名不参与匹配。
    expect(fallback.map((row) => row['room_id']), ['U3', 'U2']);

    // 2 字中文低于 trigram 的下限，走的就是这条兜底，不能静默搜不到。
    final cjk = db.select(
      'SELECT room_id FROM messages WHERE '
      '${LocalMessageStore.contentSubstringMatch} ORDER BY timestamp DESC',
      ['鱼'],
    );
    expect(cjk.map((row) => row['room_id']), ['U2', 'U1']);

    // 旧实现扫整条 payload：文件名也会命中（这就是语义不一致的来源）。
    final wholePayload = db.select(
      'SELECT room_id FROM messages WHERE instr(lower(payload), ?) > 0',
      ['abc'],
    );
    expect(wholePayload, hasLength(3));
  });
}
