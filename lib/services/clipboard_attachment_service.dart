import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:super_clipboard/super_clipboard.dart';

import '../utils/file_type_detector.dart';
import '../utils/talker.dart';

/// Represents a file read from the clipboard ready for upload.
class ClipboardFileData {
  final String fileName;
  final int fileSize;
  final Uint8List bytes;

  const ClipboardFileData({
    required this.fileName,
    required this.fileSize,
    required this.bytes,
  });
}

/// Service that reads file attachments from the system clipboard using the
/// [super_clipboard] package.  Supports desktop (Windows / macOS / Linux) and
/// web, falling back gracefully when the clipboard API is unavailable.
class ClipboardAttachmentService {
  ClipboardAttachmentService._();

  static final ClipboardAttachmentService instance =
      ClipboardAttachmentService._();

  /// Whether the underlying clipboard API is available on this platform.
  bool get isAvailable => !kIsWeb || SystemClipboard.instance != null;

  /// Returns the clipboard reader if available, or `null` otherwise.
  Future<ClipboardReader?> _readClipboard() async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;
    try {
      return await clipboard.read();
    } catch (e) {
      talker.warning('ClipboardAttachmentService: failed to read clipboard', e);
      return null;
    }
  }

  /// Returns `true` when at least one clipboard item contains file data.
  Future<bool> hasFiles() async {
    final reader = await _readClipboard();
    if (reader == null) return false;
    return reader.items.any(
      (item) =>
          item.canProvide(Formats.fileUri) ||
          item
              .getFormats(Formats.standardFormats)
              .whereType<FileFormat>()
              .isNotEmpty,
    );
  }

  /// Reads every file currently available in the clipboard and returns their
  /// byte content together with metadata.
  Future<List<ClipboardFileData>> readClipboardFiles() async {
    final reader = await _readClipboard();
    if (reader == null) return [];

    final results = <ClipboardFileData>[];

    for (final item in reader.items) {
      // 某些平台（尤其是 macOS）在复制纯文本时也会把文本作为临时文件
      // 暴露给 `Formats.fileUri` / `getFile`。此时应当按文本粘贴，
      // 而不是当作文件上传。
      final text = await _readPlainText(item);

      final candidates = <ClipboardFileData>[];
      var foundViaFileUri = false;
      if (!kIsWeb &&
          (Platform.isWindows || Platform.isLinux || Platform.isMacOS) &&
          item.canProvide(Formats.fileUri)) {
        final uri = await item.readValue(Formats.fileUri);
        if (uri != null) {
          try {
            final file = File.fromUri(uri);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final stat = await file.stat();
              final rawName = uri.pathSegments.isNotEmpty
                  ? uri.pathSegments.last
                  : 'clipboard_file';
              candidates.add(
                ClipboardFileData(
                  fileName: ensureFileExtension(rawName, bytes),
                  fileSize: stat.size,
                  bytes: bytes,
                ),
              );
              foundViaFileUri = true;
            }
          } catch (e) {
            talker.warning(
              'ClipboardAttachmentService: failed to read file $uri',
              e,
            );
          }
        }
      }
      if (!foundViaFileUri) {
        await _readViaGetFile(item, candidates);
      }
      results.addAll(_filterTextSynthesizedFiles(candidates, text));
    }
    return results;
  }

  Future<String?> _readPlainText(ClipboardDataReader item) async {
    if (!item.canProvide(Formats.plainText)) return null;
    try {
      return await item.readValue(Formats.plainText);
    } catch (e) {
      talker.warning('ClipboardAttachmentService: failed to read text', e);
      return null;
    }
  }

  /// macOS FUCK YOU!
  /// sm Tim Cook why TM you use this SB clipboard API?
  List<ClipboardFileData> _filterTextSynthesizedFiles(
    List<ClipboardFileData> candidates,
    String? text,
  ) {
    if (candidates.isEmpty || text == null || text.trim().isEmpty) {
      return candidates;
    }
    return candidates
        .where((file) => detectFileType(file.bytes) != DetectedFileType.unknown)
        .toList();
  }

  Future<void> _readViaGetFile(
    DataReader reader,
    List<ClipboardFileData> results,
  ) async {
    final fileFormats = reader
        .getFormats(Formats.standardFormats)
        .whereType<FileFormat>()
        .toList();
    if (fileFormats.isEmpty) return;

    for (final format in fileFormats) {
      try {
        final completer = Completer<void>();
        reader.getFile(
          format,
          (file) async {
            try {
              final bytes = await file.readAll();
              if (bytes.isNotEmpty) {
                final rawName = file.fileName ?? 'clipboard_file';
                results.add(
                  ClipboardFileData(
                    fileName: ensureFileExtension(rawName, bytes),
                    fileSize: file.fileSize ?? bytes.length,
                    bytes: bytes,
                  ),
                );
              }
            } catch (e) {
              talker.warning('ClipboardAttachmentService: readAll failed', e);
            } finally {
              if (!completer.isCompleted) completer.complete();
            }
          },
          onError: (e) {
            if (!completer.isCompleted) completer.complete();
          },
        );
        await completer.future;
      } catch (e) {
        talker.warning('ClipboardAttachmentService: getFile failed', e);
      }
    }
  }

  Future<List<ClipboardFileData>> checkAndReadFiles() async {
    if (!isAvailable) return [];
    return readClipboardFiles();
  }
}
