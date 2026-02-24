import 'package:system_fonts/system_fonts.dart';

class FontLoaderPlatform {
  static Future<List<String>> getSystemFontList() async {
    try {
      final systemFonts = SystemFonts();
      final fonts = systemFonts.getFontList();
      return fonts.toSet().toList()..sort();
    } catch (e) {
      return [];
    }
  }

  static Future<String?> loadSystemFont(String fontName) async {
    try {
      final systemFonts = SystemFonts();
      return await systemFonts.loadFont(fontName);
    } catch (e) {
      return null;
    }
  }
}
