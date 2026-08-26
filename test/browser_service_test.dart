import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/settings_model.dart';
import 'package:touchfish_client/services/browser_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BrowserService.normalizeUrl', () {
    test('adds http:// when scheme is missing', () {
      expect(BrowserService.normalizeUrl('example.com'), 'http://example.com');
      expect(
        BrowserService.normalizeUrl(' www.example.com/path '),
        'http://www.example.com/path',
      );
    });

    test('keeps existing schemes untouched', () {
      expect(
        BrowserService.normalizeUrl('http://example.com'),
        'http://example.com',
      );
      expect(
        BrowserService.normalizeUrl('https://example.com/a?b=1'),
        'https://example.com/a?b=1',
      );
      expect(BrowserService.normalizeUrl('about:blank'), 'about:blank');
    });
  });

  group('BrowserService.searchUrl', () {
    test('uses bing by default', () {
      expect(
        BrowserService.searchUrl('bing', 'hello'),
        'https://www.bing.com/search?q=hello',
      );
    });

    test('supports duckduckgo and baidu', () {
      expect(
        BrowserService.searchUrl('duckduckgo', 'flutter webview'),
        'https://duckduckgo.com/?q=flutter+webview',
      );
      expect(
        BrowserService.searchUrl('baidu', '测试'),
        'https://www.baidu.com/s?wd=%E6%B5%8B%E8%AF%95',
      );
    });

    test('falls back to default engine for unknown ids', () {
      expect(
        BrowserService.searchUrl('unknown-engine', 'hello'),
        'https://www.bing.com/search?q=hello',
      );
    });
  });

  group('BrowserService.intentFallbackUrl', () {
    test('extracts browser_fallback_url', () {
      expect(
        BrowserService.intentFallbackUrl(
          'intent://example.com/#Intent;scheme=https;S.browser_fallback_url=https%3A%2F%2Fexample.com%2Fpage;end',
        ),
        'https://example.com/page',
      );
    });

    test('returns null when no fallback marker', () {
      expect(
        BrowserService.intentFallbackUrl('intent://example.com/#Intent;end'),
        isNull,
      );
      expect(BrowserService.intentFallbackUrl('https://example.com'), isNull);
    });

    test('handles empty fallback value', () {
      expect(
        BrowserService.intentFallbackUrl(
          'intent://x/#Intent;S.browser_fallback_url=;end',
        ),
        isNull,
      );
    });
  });

  group('linkOpenMode setting', () {
    test('defaults to in-app browser on the setting model', () {
      final item = SettingsData.categories
          .expand((c) => c.items)
          .firstWhere((i) => i.key == 'linkOpenMode');
      expect(item.defaultValue, 'inapp');
      expect(item.options?.map((o) => o.value), contains('external'));
    });

    test('browserSearchEngine defaults to bing', () {
      final item = SettingsData.categories
          .expand((c) => c.items)
          .firstWhere((i) => i.key == 'browserSearchEngine');
      expect(item.defaultValue, 'bing');
      expect(
        item.options?.map((o) => o.value),
        containsAll(['bing', 'duckduckgo', 'baidu']),
      );
    });

    test('browserMixedContent defaults to block', () {
      final item = SettingsData.categories
          .expand((c) => c.items)
          .firstWhere((i) => i.key == 'browserMixedContent');
      expect(item.defaultValue, 'block');
      expect(item.options?.map((o) => o.value), containsAll(['block', 'allow']));
    });
  });
}
