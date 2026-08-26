import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/services/browser_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('BrowserStorage bookmarks', () {
    test('add, check and remove a bookmark', () async {
      final storage = BrowserStorage.instance;
      expect(await storage.isBookmarked('https://a.com'), isFalse);

      await storage.addBookmark('https://a.com', 'A');
      expect(await storage.isBookmarked('https://a.com'), isTrue);
      final bookmarks = await storage.getBookmarks();
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first['url'], 'https://a.com');
      expect(bookmarks.first['title'], 'A');

      await storage.removeBookmark('https://a.com');
      expect(await storage.isBookmarked('https://a.com'), isFalse);
      expect(await storage.getBookmarks(), isEmpty);
    });

    test('adding the same url twice moves it to the front without duplicates',
        () async {
      final storage = BrowserStorage.instance;
      await storage.addBookmark('https://a.com', 'A');
      await storage.addBookmark('https://b.com', 'B');
      await storage.addBookmark('https://a.com', 'A2');

      final bookmarks = await storage.getBookmarks();
      expect(bookmarks, hasLength(2));
      expect(bookmarks.first['url'], 'https://a.com');
      expect(bookmarks.first['title'], 'A2');
    });
  });

  group('BrowserStorage history', () {
    test('records visits with deduplication and most-recent-first order',
        () async {
      final storage = BrowserStorage.instance;
      await storage.recordVisit('https://a.com', 'A');
      await storage.recordVisit('https://b.com', 'B');
      await storage.recordVisit('https://a.com', 'A');

      final history = await storage.getHistory();
      expect(history, hasLength(2));
      expect(history.first['url'], 'https://a.com');
      expect(history.last['url'], 'https://b.com');
    });

    test('truncates history beyond the limit', () async {
      final storage = BrowserStorage.instance;
      for (var i = 0; i < BrowserStorage.kHistoryLimit + 20; i++) {
        await storage.recordVisit('https://site$i.com', 'Site $i');
      }
      final history = await storage.getHistory();
      expect(history, hasLength(BrowserStorage.kHistoryLimit));
      expect(history.first['url'], 'https://site${BrowserStorage.kHistoryLimit + 19}.com');
    });

    test('clearHistory empties the list', () async {
      final storage = BrowserStorage.instance;
      await storage.recordVisit('https://a.com', 'A');
      await storage.clearHistory();
      expect(await storage.getHistory(), isEmpty);
    });
  });

  group('BrowserStorage always-external domains', () {
    test('add, check and remove a domain', () async {
      final storage = BrowserStorage.instance;
      expect(await storage.isAlwaysExternal('example.com'), isFalse);

      await storage.addAlwaysExternalDomain('example.com');
      expect(await storage.isAlwaysExternal('example.com'), isTrue);
      expect(
        await storage.getAlwaysExternalDomains(),
        contains('example.com'),
      );

      await storage.removeAlwaysExternalDomain('example.com');
      expect(await storage.isAlwaysExternal('example.com'), isFalse);
      expect(await storage.getAlwaysExternalDomains(), isEmpty);
    });

    test('adding the same domain twice does not duplicate', () async {
      final storage = BrowserStorage.instance;
      await storage.addAlwaysExternalDomain('a.com');
      await storage.addAlwaysExternalDomain('a.com');
      await storage.addAlwaysExternalDomain('b.com');

      final domains = await storage.getAlwaysExternalDomains();
      expect(domains, hasLength(2));
      expect(domains, containsAll(['a.com', 'b.com']));
    });
  });
}
