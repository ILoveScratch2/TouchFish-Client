import 'dart:convert';
import 'dart:typed_data';
import '../models/message_model.dart';
import 'save_text_file.dart';

class ChatExportService {
  static Future<bool> exportJson(String roomId, List<ChatMessage> messages) async {
    final content = const JsonEncoder.withIndent('  ').convert(messages.map((m) => m.toJson()).toList());
    return _save('touchfish_chat_$roomId.json', content);
  }

  static Future<bool> exportCsv(String roomId, List<ChatMessage> messages) async {
    final buffer = StringBuffer('id,timestamp,sender,text,type\n');
    for (final message in messages) {
      String quote(String value) => '"${value.replaceAll('"', '""')}"';
      buffer.writeln([quote(message.id), quote(message.timestamp.toIso8601String()), quote(message.senderName ?? ''), quote(message.text), quote(message.type.name)].join(','));
    }
    return _save('touchfish_chat_$roomId.csv', buffer.toString());
  }

  static Future<bool> _save(String name, String content) async {
    final path = await saveTextFile(
      name,
      Uint8List.fromList(utf8.encode(content)),
    );
    return path != null;
  }
}
