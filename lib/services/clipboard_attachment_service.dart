import 'dart:async';
import 'dart:io' show File, Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:super_clipboard/super_clipboard.dart';

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

  /// Returns `true` when the clipboard currently holds at least one file
  /// reference (a file URI, as opposed to plain text or an image blob).
  Future<bool> hasFiles() async {
    final reader = await _readClipboard();
    if (reader == null) return false;
    return reader.canProvide(Formats.fileUri);
  }


  /// Reads every file currently available in the clipboard and returns their
  /// byte content together with metadata.
  Future<List<ClipboardFileData>> readClipboardFiles() async {
    final reader = await _readClipboard();
    if (reader == null) return [];

    final results = <ClipboardFileData>[];

    if (reader.canProvide(Formats.fileUri)) {
      if (!kIsWeb && (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS)) {
        final uri = await reader.readValue(Formats.fileUri);
        if (uri != null) {
          try {
            final file = File.fromUri(uri);
            if (await file.exists()) {
              final bytes = await file.readAsBytes();
              final stat = await file.stat();
              results.add(ClipboardFileData(
                fileName: uri.pathSegments.isNotEmpty
                    ? uri.pathSegments.last
                    : 'clipboard_file',
                fileSize: stat.size,
                bytes: bytes,
              ));
            }
          } catch (e) {
            talker.warning(
              'ClipboardAttachmentService: failed to read file $uri', e);
          }
        }
      } else {
        await _readViaGetFile(reader, results);
        return results;
      }
    }

    if (results.isEmpty) {
      await _readViaGetFile(reader, results);
    }
    return results;
  }

  Future<void> _readViaGetFile(
    ClipboardReader reader, List<ClipboardFileData> results,
  ) async {
    final fileFormats = reader
        .getFormats(Formats.standardFormats)
        .whereType<FileFormat>()
        .toList();
    if (fileFormats.isEmpty) return;

    for (final format in fileFormats) {
      try {
        final completer = Completer<void>();
        reader.getFile(format, (file) async {
          try {
            final bytes = await file.readAll();
            if (bytes.isNotEmpty) {
              results.add(ClipboardFileData(
                fileName: file.fileName ??
                    'clipboard_file',
                fileSize: file.fileSize ?? bytes.length,
                bytes: bytes,
              ));
            }
          } catch (e) {
            talker.warning('ClipboardAttachmentService: readAll failed', e);
          } finally {
            if (!completer.isCompleted) completer.complete();
          }
        }, onError: (e) {
          if (!completer.isCompleted) completer.complete();
        });
        await completer.future;
        if (results.isNotEmpty) break;
      } catch (e) {
        talker.warning('ClipboardAttachmentService: getFile failed', e);
      }
    }
  }

  Future<List<ClipboardFileData>> checkAndReadFiles() async {
    if (!isAvailable) return [];
    if (!(await hasFiles())) return [];
    return readClipboardFiles();
  }
}
