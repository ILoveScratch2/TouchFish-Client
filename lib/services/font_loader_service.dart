import 'package:flutter/foundation.dart' show kIsWeb;
import 'font_loader_service_desktop.dart'
    if (dart.library.html) 'font_loader_service_stub.dart';

class FontLoaderService {
  static final FontLoaderService _instance = FontLoaderService._internal();
  factory FontLoaderService() => _instance;
  FontLoaderService._internal();

  static FontLoaderService get instance => _instance;

  List<String>? _cachedFonts;
  Future<List<String>> getSystemFonts() async {
    if (_cachedFonts != null) {
      return _cachedFonts!;
    }

    List<String> fonts = [];
    if (!kIsWeb) {
      fonts = await FontLoaderPlatform.getSystemFontList();
    }
    final builtInFonts = [
      'System Default',
      'HarmonyOS Sans SC',
      'LXGW WenKai',
      '__custom__',
    ];
    fonts = [...builtInFonts, ...fonts];

    _cachedFonts = fonts;
    return fonts;
  }
  Future<String?> loadFont(String fontName) async {
    if (fontName == 'System Default') {
      return null;
    }
    if (fontName == 'HarmonyOS Sans SC') {
      return 'HarmonyOS Sans SC';
    }
    if (fontName == 'LXGW WenKai') {
      return 'LXGW WenKai';
    }
    if (!kIsWeb) {
      return await FontLoaderPlatform.loadSystemFont(fontName);
    }
    return null;
  }
  void rescan() {
    _cachedFonts = null;
  }
}
