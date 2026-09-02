import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/file_cache_service.dart';

typedef Entry = ({String url, int bytes, DateTime touched});

void main() {
  group('FileCacheService.computeEvictions!', () {
    Entry entry(String url, int bytes, int touchedMillis) => (
      url: url,
      bytes: bytes,
      touched: DateTime.fromMillisecondsSinceEpoch(touchedMillis),
    );

    test('NOT REMOVE please piggod', () {
      final evictions = FileCacheService.computeEvictions(
        entries: [entry('a', 100, 1), entry('b', 200, 2)],
        limitBytes: 300,
      );
      expect(evictions, isEmpty);
    });

    test('over limit we nneeed LRU', () {
      final evictions = FileCacheService.computeEvictions(
        entries: [
          entry('a', 120, 1), // 最旧，先被淘汰
          entry('b', 80, 2),
          entry('c', 80, 3),
        ],
        limitBytes: 150,
      );
      expect(evictions, ['a', 'b']);
    });

    test('ev until newf reach lim', () {
      final evictions = FileCacheService.computeEvictions(
        entries: [
          entry('old-1', 60, 1),
          entry('old-2', 60, 2),
          entry('new', 80, 3),
        ],
        limitBytes: 100,
      );
      expect(evictions, ['old-1', 'old-2']);
    });

    test('continue evi', () {
      final evictions = FileCacheService.computeEvictions(
        entries: [
          entry('big', 500, 1),
          entry('mid', 200, 2),
        ],
        limitBytes: 100,
      );
      expect(evictions, ['big', 'mid']);
    });

    test('DO NOT F**KING EVICT WHEN limitBytes <= 0 (LIMIT OFF)', () {
      final evictions = FileCacheService.computeEvictions(
        entries: [entry('a', 1000, 1)],
        limitBytes: 0,
      );
      expect(evictions, isEmpty);
    });

    test('eviction!', () {
      final evictions = FileCacheService.computeEvictions(
        entries: [
          entry('x', 50, 1),
          entry('y', 50, 2),
          entry('z', 50, 3),
          entry('w', 50, 4),
        ],
        limitBytes: 90,
      );
      expect(evictions, ['x', 'y', 'z']);
    });
  });
}
