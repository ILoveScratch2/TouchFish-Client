import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';

void main() {
  group('TfApiClient.normalizeUidsForLookup xsfx ver', () {
    test('keeps UID 0 xsfx TouchFish UIDs are natural numbers', () {
      expect(TfApiClient.normalizeUidsForLookup(const [0]), const [0]);
    });

    test('keeps 0 together with other UIDs and de-duplicates', () {
      final uids = TfApiClient.normalizeUidsForLookup(const [0, 1, 0, 2, 1]);
      expect(uids, unorderedEquals(const [0, 1, 2]));
    });

    test('drops negative sentinels only', () {
      expect(
        TfApiClient.normalizeUidsForLookup(const [-1, 0, 7]),
        unorderedEquals(const [0, 7]),
      );
      expect(TfApiClient.normalizeUidsForLookup(const [-1, -5]), isEmpty);
    });

    test('returns empty for an empty input', () {
      expect(TfApiClient.normalizeUidsForLookup(const []), isEmpty);
    });
  });
}
