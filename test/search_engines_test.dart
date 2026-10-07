import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/search_engines.dart';

void main() {
  group('SearchEngineConfig', () {
    test('byId finds configured engines', () {
      expect(SearchEngineConfig.byId('bing')?.id, 'bing');
      expect(SearchEngineConfig.byId('duckduckgo')?.id, 'duckduckgo');
      expect(SearchEngineConfig.byId('baidu')?.id, 'baidu');
      expect(SearchEngineConfig.byId('nope'), isNull);
    });

    test('defaultEngine is the first entry (bing)', () {
      expect(SearchEngineConfig.defaultEngine.id, 'bing');
    });

    test('searchUrl encodes the query', () {
      expect(
        SearchEngineConfig.byId('bing')!.searchUrl('hello world'),
        'https://www.bing.com/search?q=hello+world',
      );
      expect(
        SearchEngineConfig.byId('baidu')!.searchUrl('测试'),
        'https://www.baidu.com/s?wd=%E6%B5%8B%E8%AF%95',
      );
    });

    test('autocompleteUrl appends the query', () {
      expect(
        SearchEngineConfig.byId('bing')!.autocompleteUrl('fl'),
        'https://api.bing.com/osjson.aspx?query=fl',
      );
    });
  });

  group('parseSuggestions', () {
    test('parses bing/google style [query, [sug]] arrays', () {
      expect(
        parseSuggestions('["hel",["hello","help"]]'),
        ['hello', 'help'],
      );
    });

    test('parses duckduckgo style [{phrase}] arrays', () {
      expect(
        parseSuggestions('[{"phrase":"flutter"},{"phrase":"flask"}]'),
        ['flutter', 'flask'],
      );
    });

    test('parses baidu JSONP window.baidu.sug({...})', () {
      expect(
        parseSuggestions(
          'window.baidu.sug({"q":"测","s":["测试","测试网"]})',
        ),
        ['测试', '测试网'],
      );
    });

    test('returns empty for invalid json', () {
      expect(parseSuggestions(''), isEmpty);
      expect(parseSuggestions('not json at all'), isEmpty);
      expect(parseSuggestions('12345'), isEmpty);
    });

    test('skips empty and non-string entries', () {
      expect(parseSuggestions('["q",["a","","b"]]'), ['a', 'b']);
      expect(
        parseSuggestions('[{"phrase":"a"},{"phrase":""}]'),
        ['a'],
      );
    });
  });
}
