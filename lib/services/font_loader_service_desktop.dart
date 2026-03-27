import 'package:system_fonts/system_fonts.dart';
import '../utils/talker.dart';

class FontLoaderPlatform {
  static Future<List<String>> getSystemFontList() async {
    try {
      final systemFonts = SystemFonts();
      final fonts = systemFonts.getFontList();
      return fonts.toSet().toList()..sort();
    } catch (e) {
      talker.error('Failed to get system font list', e);
      return [];
    }
  }

  static Future<String?> loadSystemFont(String fontName) async {
    try {
      final systemFonts = SystemFonts();
      return await systemFonts.loadFont(fontName);
    } catch (e) {
      talker.error('Failed to load system font: $fontName', e);
      return null;
    }
  }
}
