import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

/// Saves [bytes] to a user-chosen location and returns the destination path,
/// or null when the user cancels the picker.
///
/// On desktop the plugin only returns a path without writing anything, so the
/// bytes are written explicitly. On mobile the plugin writes the bytes itself.
Future<String?> saveTextFile(String fileName, Uint8List bytes) async {
  final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  if (!desktop) {
    return FilePicker.platform.saveFile(fileName: fileName, bytes: bytes);
  }
  final path = await FilePicker.platform.saveFile(fileName: fileName);
  if (path == null) return null;
  await File(path).writeAsBytes(bytes, flush: true);
  return path;
}
