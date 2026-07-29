import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

enum DetectedFileType { png, jpg, gif, bmp, svg, tgs, unknown }

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
  try {
    final text = utf8.decode(bytes.take(4096).toList(), allowMalformed: false).replaceFirst('\uFEFF', '').trimLeft().toLowerCase();
    if (text.indexOf('<svg') >= 0 && text.indexOf('<svg') < 512) return DetectedFileType.svg;
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
  }
  return DetectedFileType.unknown;
}
