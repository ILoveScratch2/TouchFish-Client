import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'local_message_store.dart';

class DatabaseBackupService {
  static final instance = DatabaseBackupService._();
  DatabaseBackupService._();

  Future<bool> exportMessages({required String server, required int uid}) async {
    if (kIsWeb) return false;
    final snapshot = await LocalMessageStore.instance.exportSnapshot();
    final envelope = {
      'format': 'touchfish-message-backup',
      'version': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'serverConfig': {'server': server, 'uid': uid},
      ...snapshot,
    };
    final path = await FilePicker.platform.saveFile(
      fileName: 'touchfish_messages_${DateTime.now().millisecondsSinceEpoch}.json',
      bytes: Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope))),
    );
    return path != null;
  }

  Future<int?> importMessages({String? server, int? uid}) async {
    if (kIsWeb) return null;
    final result = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['json']);
    if (result == null || result.files.single.bytes == null) return null;
    final decoded = jsonDecode(utf8.decode(result.files.single.bytes!));
    if (decoded is! Map || decoded['format'] != 'touchfish-message-backup') {
      throw const FormatException('Invalid TouchFish message backup');
    }
    if (server != null && uid != null) {
      LocalMessageStore.instance.configureScope(server, uid);
    }
    return LocalMessageStore.instance.importSnapshot(Map<String, dynamic>.from(decoded));
  }
}
