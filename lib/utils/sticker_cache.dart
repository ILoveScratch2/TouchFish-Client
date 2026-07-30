import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

class StickerCache {
  static StickerCache? _instance;
  Directory? _cacheDir;

  StickerCache._();

  static StickerCache get instance => _instance ??= StickerCache._();

  Future<Directory> get _directory async {
    if (_cacheDir != null) return _cacheDir!;
    final base = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${base.path}${Platform.pathSeparator}sticker_cache');
    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
    return _cacheDir!;
  }

  Future<String?> get(String hash) async {
    try {
      final dir = await _directory;
      final file = File('${dir.path}${Platform.pathSeparator}$hash.sticker');
      if (await file.exists()) return file.path;
    } catch (_) {}
    return null;
  }

  Future<void> put(String hash, Uint8List bytes) async {
    try {
      final dir = await _directory;
      final file = File('${dir.path}${Platform.pathSeparator}$hash.sticker');
      await file.writeAsBytes(bytes, flush: true);
    } catch (_) {}
  }

  Future<int> get sizeBytes async {
    try {
      final dir = await _directory;
      if (!await dir.exists()) return 0;
      int total = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _directory;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        _cacheDir = null;
      }
    } catch (_) {}
  }
}
