import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../models/message_model.dart';

class ChatExportService {
  static Future<bool> exportJson(String roomId, List<ChatMessage> messages) async {
    if (kIsWeb) return false;
    final content = const JsonEncoder.withIndent('  ').convert(messages.map((m) => m.toJson()).toList());
    return await _save('touchfish_chat_$roomId.json', content);
  }

  static Future<bool> exportCsv(String roomId, List<ChatMessage> messages) async {
    if (kIsWeb) return false;
    final buffer = StringBuffer('id,timestamp,sender,text,type\n');
    for (final message in messages) {
      String quote(String value) => '"${value.replaceAll('"', '""')}"';
      buffer.writeln([quote(message.id), quote(message.timestamp.toIso8601String()), quote(message.senderName ?? ''), quote(message.text), quote(message.type.name)].join(','));
    }
    return await _save('touchfish_chat_$roomId.csv', buffer.toString());
  }

  static Future<bool> _save(String name, String content) async {
    final path = await FilePicker.platform.saveFile(fileName: name, bytes: Uint8List.fromList(utf8.encode(content)));
    return path != null;
  }
}
