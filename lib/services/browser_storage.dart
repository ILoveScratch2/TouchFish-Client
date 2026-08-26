import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 显然我们不能只有 WebView
/// 现在我们有了：书签、历史、始终外部打开的域名
class BrowserStorage {
  BrowserStorage._();

  static final BrowserStorage instance = BrowserStorage._();

  static const String kBookmarksKey = 'browserBookmarks';
  static const String kHistoryKey = 'browserHistory';
  static const String kAlwaysExternalDomainsKey = 'browserAlwaysExternalDomains';
  static const int kHistoryLimit = 100;

  Future<SharedPreferences> get _prefs async => SharedPreferences.getInstance();

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list.whereType<String>().toList();
    } catch (_) {
      return [];
    }
  }

  static List<Map<String, dynamic>> _decode(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ---- 书签 ----

  Future<List<Map<String, dynamic>>> getBookmarks() async =>
      _decode((await _prefs).getString(kBookmarksKey));

  Future<bool> isBookmarked(String url) async {
    final bookmarks = await getBookmarks();
    return bookmarks.any((b) => b['url'] == url);
  }

  Future<void> addBookmark(String url, String title) async {
    final prefs = await _prefs;
    final bookmarks = _decode(prefs.getString(kBookmarksKey))
      ..removeWhere((b) => b['url'] == url);
    bookmarks.insert(0, {
      'url': url,
      'title': title,
      'addedAt': DateTime.now().millisecondsSinceEpoch,
    });
    await prefs.setString(kBookmarksKey, jsonEncode(bookmarks));
  }

  Future<void> removeBookmark(String url) async {
    final prefs = await _prefs;
    final bookmarks = _decode(prefs.getString(kBookmarksKey))
      ..removeWhere((b) => b['url'] == url);
    await prefs.setString(kBookmarksKey, jsonEncode(bookmarks));
  }

  // ---- 历史 ----

  Future<List<Map<String, dynamic>>> getHistory() async =>
      _decode((await _prefs).getString(kHistoryKey));

  Future<void> recordVisit(String url, String title) async {
    final prefs = await _prefs;
    final history = _decode(prefs.getString(kHistoryKey))
      ..removeWhere((h) => h['url'] == url);
    history.insert(0, {
      'url': url,
      'title': title,
      'visitedAt': DateTime.now().millisecondsSinceEpoch,
    });
    if (history.length > kHistoryLimit) {
      history.removeRange(kHistoryLimit, history.length);
    }
    await prefs.setString(kHistoryKey, jsonEncode(history));
  }

  Future<void> clearHistory() async {
    final prefs = await _prefs;
    await prefs.remove(kHistoryKey);
  }

  // ---- 始终外部浏览器打开的域名 ----

  Future<List<String>> getAlwaysExternalDomains() async =>
      _decodeStringList((await _prefs).getString(kAlwaysExternalDomainsKey));

  Future<bool> isAlwaysExternal(String domain) async {
    final domains = await getAlwaysExternalDomains();
    return domains.contains(domain);
  }

  Future<void> addAlwaysExternalDomain(String domain) async {
    final prefs = await _prefs;
    final domains = _decodeStringList(
      prefs.getString(kAlwaysExternalDomainsKey),
    );
    if (!domains.contains(domain)) {
      domains.add(domain);
      await prefs.setString(
        kAlwaysExternalDomainsKey,
        jsonEncode(domains),
      );
    }
  }

  Future<void> removeAlwaysExternalDomain(String domain) async {
    final prefs = await _prefs;
    final domains = _decodeStringList(
      prefs.getString(kAlwaysExternalDomainsKey),
    )..remove(domain);
    await prefs.setString(kAlwaysExternalDomainsKey, jsonEncode(domains));
  }
}
