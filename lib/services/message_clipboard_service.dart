import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../l10n/app_localizations.dart';
import '../models/message_model.dart';
import '../utils/clipboard_utils.dart';
import '../utils/file_type_detector.dart';
import '../utils/message_text.dart';
import '../utils/talker.dart';
import 'api/tf_api_client.dart';
import 'file_cache_service.dart';

enum MessageCopyResult {
  /// 没有可复制
  empty,

  /// 复制文本
  text,

  /// 复制文件
  files,

  /// 复制失败
  failed,
}

/// 把消息复制到系统剪贴板
class MessageClipboardService {
  MessageClipboardService._();

  static final MessageClipboardService instance = MessageClipboardService._();

  /// 单个文件允许写入剪贴板的上限
  static const int maxFileBytes = 256 * 1024 * 1024;

  /// 暂存文件保留时长
  static const Duration _stagingTtl = Duration(days: 2);
  static const int _maxStagedEntries = 40;

  static final RegExp _fileHashPattern = RegExp(r'^[0-9a-f]{64}$');
  static int _stagingSequence = 0;

  /// 文件名长度上限
  static const int _maxFileNameLength = 120;

  Future<MessageCopyResult> copyMessage(
    ChatMessage message, {
    required AppLocalizations l10n,
  }) => copyMessages([message], l10n: l10n);


  Future<MessageCopyResult> copyMessages(
    List<ChatMessage> messages, {
    required AppLocalizations l10n,
  }) async {
    final alive = messages.where((m) => !m.isDeleted).toList(growable: false);
    if (alive.isEmpty) return MessageCopyResult.empty;

    final mediaMessages =
        alive.where((m) => m.media != null).toList(growable: false);
    if (mediaMessages.isNotEmpty && mediaMessages.length == alive.length) {
      final filesResult = await _copyMediaAsFiles(mediaMessages);
      if (filesResult != null) return filesResult;
      // 取不到文件
    }

    final text = alive
        .map((m) => messagePlainText(m, l10n))
        .where((t) => t.trim().isNotEmpty)
        .join('\n');
    if (text.trim().isEmpty) return MessageCopyResult.empty;
    final copied = await copyTextToClipboard(text);
    return copied ? MessageCopyResult.text : MessageCopyResult.failed;
  }

  Future<MessageCopyResult?> _copyMediaAsFiles(
    List<ChatMessage> messages,
  ) async {
    final clipboard = SystemClipboard.instance;
    if (clipboard == null) return null;

    final payloads = <_ClipboardPayload>[];
    for (final message in messages) {
      final payload = await _preparePayload(message);
      if (payload != null) payloads.add(payload);
    }
    if (payloads.length != messages.length) return null;

    final items = <DataWriterItem>[];
    for (final payload in payloads) {
      final item = _buildWriterItem(payload);
      if (item != null) items.add(item);
    }
    if (items.length != payloads.length) return null;

    try {
      await clipboard.write(items);
      return MessageCopyResult.files;
    } catch (e, stack) {
      talker.error('MessageClipboardService: clipboard write failed', e, stack);
      return null;
    }
  }

  DataWriterItem? _buildWriterItem(_ClipboardPayload payload) {
    final item = DataWriterItem(suggestedName: payload.name);
    var hasRendition = false;

    final path = payload.path;
    if (!kIsWeb && path != null) {
      // 文件数据
      item.add(Formats.fileUri(Uri.file(path)));
      hasRendition = true;
    }

    // 图片数据
    final imageFormat = _imageFormatFor(payload.mimeType);
    final bytes = payload.bytes;
    if (kIsWeb &&
        imageFormat != null &&
        bytes != null &&
        bytes.isNotEmpty) {
      item.add(imageFormat(bytes));
      hasRendition = true;
    }

    return hasRendition ? item : null;
  }

  Future<_ClipboardPayload?> _preparePayload(ChatMessage message) async {
    final media = message.media;
    if (media == null) return null;

    final localBytes = media.bytes;
    final bytes = localBytes == null ? null : Uint8List.fromList(localBytes);
    final mimeType = _effectiveMimeType(media, bytes);
    final name = _clipboardFileName(message, media, mimeType);
    if (bytes != null && bytes.isNotEmpty) {
      if (bytes.length > maxFileBytes) return null;
      if (kIsWeb) {
        return _ClipboardPayload(name: name, bytes: bytes, mimeType: mimeType);
      }
      final path = await _stageBytes(name, bytes);
      if (path == null) return null;
      return _ClipboardPayload(name: name, path: path, mimeType: mimeType);
    }

    final source = await _resolveMediaSource(media);
    if (source == null) return null;
    if (!kIsWeb && source.localFile != null) {
      final path = await _stageFile(source.localFile!, name);
      if (path == null) return null;
      return _ClipboardPayload(name: name, path: path, mimeType: mimeType);
    }
    final url = source.url;
    if (url == null) return null;

    if (kIsWeb) {
      final downloaded = await _downloadBytes(url);
      if (downloaded == null ||
          downloaded.isEmpty ||
          downloaded.length > maxFileBytes) {
        return null;
      }
      return _ClipboardPayload(
        name: name,
        bytes: downloaded,
        mimeType: _effectiveMimeType(media, downloaded),
      );
    }

    final cached = await _cachedFile(url);
    if (cached == null) return null;
    final path = await _stageFile(cached, name);
    if (path == null) return null;
    return _ClipboardPayload(name: name, path: path, mimeType: mimeType);
  }

  Future<_MediaSource?> _resolveMediaSource(MessageMedia media) async {
    final path = media.path;
    if (!kIsWeb && !_isRemotePath(path) && !_fileHashPattern.hasMatch(path)) {
      final file = File(path);
      if (await file.exists()) return _MediaSource(localFile: file);
    }
    if (_isRemotePath(path)) return _MediaSource(url: path);
    final hash = media.fileHash ??
        (_fileHashPattern.hasMatch(path) ? path : null);
    if (hash != null && hash.isNotEmpty) {
      try {
        final url = await TfApiClient.instance.getFileUrl(hash);
        if (url.isNotEmpty) return _MediaSource(url: url);
      } catch (e, stack) {
        talker.error('MessageClipboardService: resolve file url failed', e, stack);
      }
    }
    return null;
  }

  Future<File?> _cachedFile(String url) async {
    try {
      final file = await FileCacheService.instance.getFile(url);
      if (file == null) return null;
      final length = await file.length();
      if (length <= 0 || length > maxFileBytes) return null;
      return file;
    } catch (e, stack) {
      talker.error('MessageClipboardService: cache file failed', e, stack);
      return null;
    }
  }

  Future<Uint8List?> _downloadBytes(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      return response.bodyBytes;
    } catch (e, stack) {
      talker.error('MessageClipboardService: download failed', e, stack);
      return null;
    }
  }

  Future<String?> _stageBytes(String name, Uint8List bytes) async {
    try {
      final dir = await _stagingRoot();
      await _pruneStaging(dir);
      final target = await _freshStagingPath(dir, name);
      await File(target).writeAsBytes(bytes, flush: true);
      return target;
    } catch (e, stack) {
      talker.error('MessageClipboardService: stage bytes failed', e, stack);
      return null;
    }
  }

  Future<String?> _stageFile(File source, String name) async {
    try {
      final length = await source.length();
      if (length <= 0 || length > maxFileBytes) return null;
      final dir = await _stagingRoot();
      await _pruneStaging(dir);
      final resolvedName = p.extension(name).isEmpty
          ? _withSourceExtension(name, source.path)
          : name;
      final target = await _freshStagingPath(dir, resolvedName);
      await source.copy(target);
      return target;
    } catch (e, stack) {
      talker.error('MessageClipboardService: stage file failed', e, stack);
      return null;
    }
  }

  Future<Directory> _stagingRoot() async {
    final temp = await getTemporaryDirectory();
    final dir = Directory(p.join(temp.path, 'touchfish_clipboard'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> _freshStagingPath(Directory root, String name) async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final dir = Directory(p.join(root.path, '${stamp}_${_stagingSequence++}'));
    await dir.create(recursive: true);
    return p.join(dir.path, name);
  }

  Future<void> _pruneStaging(Directory root) async {
    try {
      final now = DateTime.now();
      final dirs = <Directory>[];
      await for (final entity in root.list()) {
        if (entity is! Directory) continue;
        final modified = (await entity.stat()).modified;
        if (now.difference(modified) > _stagingTtl) {
          await entity.delete(recursive: true);
          continue;
        }
        dirs.add(entity);
      }
      if (dirs.length <= _maxStagedEntries) return;
      final stats = <MapEntry<Directory, DateTime>>[];
      for (final dir in dirs) {
        stats.add(MapEntry(dir, (await dir.stat()).modified));
      }
      stats.sort((a, b) => a.value.compareTo(b.value));
      final overflow = stats.length - _maxStagedEntries;
      for (final entry in stats.take(overflow)) {
        await entry.key.delete(recursive: true);
      }
    } catch (e) {
      talker.warning('MessageClipboardService: prune staging failed', e);
    }
  }

  String _clipboardFileName(
    ChatMessage message,
    MessageMedia media,
    String? mimeType,
  ) {
    final raw = media.fileName?.trim();
    if (raw != null && raw.isNotEmpty && !_fileHashPattern.hasMatch(raw)) {
      final sanitized = _sanitizeFileName(raw);
      if (sanitized.isNotEmpty) {
        final extension = _extensionForMime(mimeType);
        if (p.extension(sanitized).isEmpty && extension != null) {
          return '$sanitized.$extension';
        }
        return sanitized;
      }
    }

    final stamp = message.mid ?? message.timestamp.millisecondsSinceEpoch;
    final stem = _stemForType(message.type);
    final extension = _extensionForMime(mimeType);
    return extension == null ? '${stem}_$stamp' : '${stem}_$stamp.$extension';
  }

  String _sanitizeFileName(String raw) {
    final sanitized = raw
        .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
        .trim();
    if (sanitized.isEmpty || RegExp(r'^\.+$').hasMatch(sanitized)) return '';
    if (sanitized.length <= _maxFileNameLength) return sanitized;

    final extension = p.extension(sanitized);
    final base = p.basenameWithoutExtension(sanitized);
    final keep = _maxFileNameLength - extension.length;
    if (keep <= 0) return sanitized.substring(0, _maxFileNameLength);
    var cut = base.substring(0, base.length > keep ? keep : base.length);
    // 不要在代理对中间截断
    final last = cut.codeUnitAt(cut.length - 1);
    if (last >= 0xD800 && last <= 0xDBFF) {
      cut = cut.substring(0, cut.length - 1);
    }
    return '$cut$extension';
  }

  String _stemForType(MessageType type) {
    return switch (type) {
      MessageType.image => 'image',
      MessageType.video => 'video',
      MessageType.audio => 'audio',
      _ => 'file',
    };
  }

  String? _effectiveMimeType(MessageMedia media, Uint8List? bytes) {
    final declared = media.mimeType?.trim();
    if (declared != null && declared.isNotEmpty) return declared.toLowerCase();
    if (bytes == null) return null;
    return switch (detectFileType(bytes)) {
      DetectedFileType.png => 'image/png',
      DetectedFileType.jpg => 'image/jpeg',
      DetectedFileType.gif => 'image/gif',
      DetectedFileType.webp => 'image/webp',
      DetectedFileType.bmp => 'image/bmp',
      DetectedFileType.svg => 'image/svg+xml',
      DetectedFileType.unknown || DetectedFileType.tgs => null,
    };
  }

  String? _extensionForMime(String? mimeType) {
    final mime = (mimeType ?? '').trim().toLowerCase();
    if (mime.isEmpty) return null;
    return const {
      'image/png': 'png',
      'image/jpeg': 'jpg',
      'image/jpg': 'jpg',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'image/bmp': 'bmp',
      'image/svg+xml': 'svg',
      'video/mp4': 'mp4',
      'video/quicktime': 'mov',
      'video/webm': 'webm',
      'audio/mpeg': 'mp3',
      'audio/mp4': 'm4a',
      'audio/aac': 'aac',
      'audio/ogg': 'ogg',
      'audio/wav': 'wav',
      'audio/x-wav': 'wav',
      'application/pdf': 'pdf',
      'application/zip': 'zip',
      'text/plain': 'txt',
    }[mime];
  }

  DataFormat<Uint8List>? _imageFormatFor(String? mimeType) {
    return switch ((mimeType ?? '').trim().toLowerCase()) {
      'image/png' => Formats.png,
      'image/jpeg' || 'image/jpg' => Formats.jpeg,
      'image/gif' => Formats.gif,
      _ => null,
    };
  }

  bool _isRemotePath(String path) =>
      path.startsWith('http://') || path.startsWith('https://');
}

/// 从现有路径补全扩展名
String _withSourceExtension(String name, String sourcePath) {
  final sourceExtension = p.extension(sourcePath);
  if (sourceExtension.isEmpty || sourceExtension == '.') return name;
  return '$name$sourceExtension';
}

class _ClipboardPayload {
  const _ClipboardPayload({
    required this.name,
    this.path,
    this.bytes,
    this.mimeType,
  });

  final String name;
  final String? path;
  final Uint8List? bytes;
  final String? mimeType;
}

class _MediaSource {
  const _MediaSource({this.localFile, this.url});

  final File? localFile;
  final String? url;
}
