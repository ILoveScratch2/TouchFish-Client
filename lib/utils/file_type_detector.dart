import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

enum DetectedFileType {
  png,
  jpg,
  gif,
  bmp,
  svg,
  tgs,
  webp,
  unknown;

  /// Canonical file extension (without the leading dot) for this type.
  /// Returns an empty string for [DetectedFileType.unknown].
  String get fileExtension => switch (this) {
    DetectedFileType.png => 'png',
    DetectedFileType.jpg => 'jpg',
    DetectedFileType.gif => 'gif',
    DetectedFileType.bmp => 'bmp',
    DetectedFileType.svg => 'svg',
    DetectedFileType.tgs => 'tgs',
    DetectedFileType.webp => 'webp',
    DetectedFileType.unknown => '',
  };
}

DetectedFileType detectFileType(Uint8List bytes, {String fallbackName = ''}) {
  bool starts(List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (int i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }
  if (starts(const [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])) return DetectedFileType.png;
  if (starts(const [0xff, 0xd8, 0xff])) return DetectedFileType.jpg;
  if (starts(const [0x47, 0x49, 0x46, 0x38])) return DetectedFileType.gif;
  if (starts(const [0x42, 0x4d])) return DetectedFileType.bmp;
  // WebP: "RIFF" header followed by "WEBP" at byte offset 8.
  if (starts(const [0x52, 0x49, 0x46, 0x46]) && bytes.length >= 12 &&
      bytes[8] == 0x57 && bytes[9] == 0x45 &&
      bytes[10] == 0x42 && bytes[11] == 0x50) {
    return DetectedFileType.webp;
  }
  try {
    final text = utf8.decode(bytes.take(4096).toList(), allowMalformed: false).replaceFirst('\uFEFF', '').trimLeft().toLowerCase();
    if (text.contains('<svg') && text.indexOf('<svg') < 512) return DetectedFileType.svg;
  } catch (_) {}
  if (starts(const [0x1f, 0x8b]) && bytes.length <= 10 * 1024 * 1024) {
    try {
      final value = jsonDecode(utf8.decode(GZipDecoder().decodeBytes(bytes)));
      if (value is Map && (value.containsKey('tgs') || (value.containsKey('v') && value.containsKey('layers')))) return DetectedFileType.tgs;
    } catch (_) {}
  }
  switch (fallbackName.split('.').last.toLowerCase()) {
    case 'png': return DetectedFileType.png;
    case 'jpg': case 'jpeg': return DetectedFileType.jpg;
    case 'gif': return DetectedFileType.gif;
    case 'bmp': return DetectedFileType.bmp;
    case 'svg': return DetectedFileType.svg;
    case 'tgs': return DetectedFileType.tgs;
    case 'webp': return DetectedFileType.webp;
  }
  return DetectedFileType.unknown;
}

/// Returns [fileName] carrying an extension that matches the actual [bytes].
///
/// Clipboard items that hold raw data (e.g. an image copied from a browser or
/// a screenshot tool) usually have no file name at all, so callers often fall
/// back to a name without an extension (e.g. `'clipboard_file'`).  In that
/// case – or when the existing extension does not match the content – the
/// correct extension is derived from the byte signature so the uploaded file
/// can be previewed in the app and opened by the right application after
/// download.
String ensureFileExtension(String fileName, Uint8List bytes) {
  final detected = detectFileType(bytes, fallbackName: fileName);
  if (detected == DetectedFileType.unknown) return fileName;
  final ext = detected.fileExtension;
  if (ext.isEmpty) return fileName;

  final lower = fileName.toLowerCase();
  // Keep an already-correct extension (also accept .jpeg for jpg content).
  if (lower.endsWith('.$ext') || (ext == 'jpg' && lower.endsWith('.jpeg'))) {
    return fileName;
  }

  final lastDot = lower.lastIndexOf('.');
  if (lastDot > 0) {
    // Replace a wrong extension (e.g. content is PNG but name says .jpg).
    return '${fileName.substring(0, lastDot)}.$ext';
  }
  return '$fileName.$ext';
}
