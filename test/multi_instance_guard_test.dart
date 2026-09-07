import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/services/multi_instance_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MultiInstanceGuard.hasConflict', () {
    const ownInst = 'inst-A';

    Map<String, dynamic> fresh(String inst, String server, int uid) =>
        <String, dynamic>{
          MultiInstanceGuard.kInst: inst,
          MultiInstanceGuard.kServer: server,
          MultiInstanceGuard.kUid: uid,
          MultiInstanceGuard.kUser: 'u$uid',
          MultiInstanceGuard.kTs: 1000,
        };

    test('no conflict on empty registry', () {
      expect(
        MultiInstanceGuard.hasConflict([], 's1', 1, ownInst),
        isFalse,
      );
    });

    test('same server + same uid by another instance conflicts', () {
      expect(
        MultiInstanceGuard.hasConflict(
          [fresh('inst-B', 's1', 1)],
          's1',
          1,
          ownInst,
        ),
        isTrue,
      );
    });

    test('same server + different uid does not conflict', () {
      expect(
        MultiInstanceGuard.hasConflict(
          [fresh('inst-B', 's1', 1)],
          's1',
          2,
          ownInst,
        ),
        isFalse,
      );
    });

    test('different server + same uid does not conflict', () {
      expect(
        MultiInstanceGuard.hasConflict(
          [fresh('inst-B', 's1', 1)],
          's2',
          1,
          ownInst,
        ),
        isFalse,
      );
    });

    test('own claim is ignored', () {
      expect(
        MultiInstanceGuard.hasConflict(
          [fresh(ownInst, 's1', 1)],
          's1',
          1,
          ownInst,
        ),
        isFalse,
      );
    });
  });

  group('MultiInstanceGuard.pruneRegistry', () {
    Map<String, dynamic> entry(
      String inst,
      String server,
      int uid,
      int ts,
    ) =>
        <String, dynamic>{
          MultiInstanceGuard.kInst: inst,
          MultiInstanceGuard.kServer: server,
          MultiInstanceGuard.kUid: uid,
          MultiInstanceGuard.kUser: 'u$uid',
          MultiInstanceGuard.kTs: ts,
        };

    test('removes entries older than staleAfterMs', () {
      final now = 1000000;
      final entries = [
        entry('a', 's1', 1, now), // fresh
        entry('b', 's1', 2, now - 1000), // recent, still fresh
        entry('c', 's1', 3, now - 50000), // beyond default 45s threshold
      ];
      MultiInstanceGuard.pruneRegistry(entries, now);
      expect(entries, hasLength(2));
      expect(
        entries.map((e) => e[MultiInstanceGuard.kUid]),
        containsAll(<Object>[1, 2]),
      );
    });

    test('keeps entries missing a timestamp', () {
      final now = 1000000;
      final entries = [
        {
          MultiInstanceGuard.kInst: 'a',
          MultiInstanceGuard.kServer: 's1',
          MultiInstanceGuard.kUid: 1,
        },
      ];
      MultiInstanceGuard.pruneRegistry(entries, now);
      expect(entries, hasLength(1));
    });

    test('honors a custom staleAfterMs', () {
      final now = 1000000;
      final entries = [
        entry('a', 's1', 1, now - 20000), // within custom 30s window
        entry('b', 's1', 2, now - 40000), // beyond it
      ];
      MultiInstanceGuard.pruneRegistry(entries, now, staleAfterMs: 30000);
      expect(entries, hasLength(1));
      expect(entries.single[MultiInstanceGuard.kUid], 1);
    });
  });
}
