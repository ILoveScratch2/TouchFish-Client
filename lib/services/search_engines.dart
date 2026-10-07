import 'dart:convert';

/// 内置浏览器的搜索引擎配置
/// Thank you to DeepSeek-V4-Flase-Vision-Exp for the idea
class SearchEngineConfig {
  final String id;
  final String searchUrlPrefix;
  final String autocompleteUrlPrefix;
  final String privacyPolicyUrl;

  const SearchEngineConfig({
    required this.id,
    required this.searchUrlPrefix,
    required this.autocompleteUrlPrefix,
    required this.privacyPolicyUrl,
  });

  String searchUrl(String query) =>
      '$searchUrlPrefix${Uri.encodeQueryComponent(query)}';

  String autocompleteUrl(String query) =>
      '$autocompleteUrlPrefix${Uri.encodeQueryComponent(query)}';

  static const List<SearchEngineConfig> all = [
    SearchEngineConfig(
      id: 'bing',
      searchUrlPrefix: 'https://www.bing.com/search?q=',
      autocompleteUrlPrefix: 'https://api.bing.com/osjson.aspx?query=',
      privacyPolicyUrl: 'https://privacy.microsoft.com/privacystatement',
    ),
    SearchEngineConfig(
      id: 'duckduckgo',
      searchUrlPrefix: 'https://duckduckgo.com/?q=',
      autocompleteUrlPrefix: 'https://duckduckgo.com/ac/?q=',
      privacyPolicyUrl: 'https://duckduckgo.com/privacy',
    ),
    SearchEngineConfig(
      id: 'baidu',
      searchUrlPrefix: 'https://www.baidu.com/s?wd=',
      autocompleteUrlPrefix: 'https://suggestion.baidu.com/su?wd=',
      privacyPolicyUrl: 'https://www.baidu.com/duty/safe_control.html',
    ),
  ];

  static SearchEngineConfig? byId(String? id) {
    for (final engine in all) {
      if (engine.id == id) return engine;
    }
    return null;
  }

  /// 默认引擎（无设置或未知 id 时回退）。
  static SearchEngineConfig get defaultEngine => all.first;
}

/// 解析搜索建议 JSON。对照 Telegram SearchEngine.extractSuggestions 支持：
/// - Bing: ["query", ["sug1", "sug2"]]
/// - DuckDuckGo: [{"phrase": "sug1"}, ...]
/// - Baidu: window.baidu.sug({"q": "...", "s": ["sug1", ...]})
List<String> parseSuggestions(String json) {
  var text = json.trim();
  if (text.isEmpty) return [];

  Object? decoded;
  try {
    decoded = jsonDecode(text);
  } catch (_) {
    // JSONP 包装：window.baidu.sug({...}) 之类，剥掉外层调用再解析。
    final m = RegExp(r'^[\w\.]+\((.*)\)\s*$', dotAll: true).firstMatch(text);
    if (m == null) return [];
    try {
      decoded = jsonDecode(m.group(1)!);
    } catch (_) {
      return [];
    }
  }
  return _extractSuggestions(decoded);
}

List<String> _extractSuggestions(Object? decoded) {
  if (decoded is List) {
    if (decoded.length >= 2 && decoded[1] is List) {
      // ["query", ["a", "b"]] 形式（Bing/Google 风格）。
      final list = decoded[1] as List;
      return list
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return decoded
        .whereType<Map>()
        .map((e) => e['phrase'])
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  if (decoded is Map && decoded['s'] is List) {
    // window.baidu.sug({"s": ["a", "b"]}) 形式。
    final list = decoded['s'] as List;
    return list
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
  return [];
}
