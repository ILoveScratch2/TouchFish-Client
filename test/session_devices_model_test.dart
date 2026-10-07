import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/services/api/tf_api_client.dart';

void main() {
  group('TfAuthTokenInfo parsing', () {
    test('parses full session payload with device fields', () {
      final info = TfAuthTokenInfo.fromJson(const {
        'session_id': 'sess-1',
        'created_at': 1700000000,
        'last_seen_at': 1700000100,
        'expires_at': 1700003600,
        'ip': '192.168.1.1',
        'ua': 'TouchFish-Client/1.0 (official)',
        'is_current': true,
        'device_id': 'dev-1',
        'device_name': 'iPhone 15',
        'label': 'My Phone',
        'platform': 5,
        'location': 'Beijing',
      });

      expect(info.sessionId, 'sess-1');
      expect(info.issuedAt, 1700000000);
      expect(info.lastSeen, 1700000100);
      expect(info.expiresAt, 1700003600);
      expect(info.isCurrent, isTrue);
      expect(info.deviceId, 'dev-1');
      expect(info.deviceName, 'iPhone 15');
      expect(info.label, 'My Phone');
      expect(info.platform, 5);
      expect(info.location, 'Beijing');
    });

    test('falls back to legacy fields when device fields are absent', () {
      final info = TfAuthTokenInfo.fromJson(const {
        'jti': 'legacy-jti',
        'issued_at': 42,
        'expires_at': 84,
        'ip': '10.0.0.1',
        'ua': 'old-client',
      });

      expect(info.jti, 'legacy-jti');
      expect(info.sessionId, 'legacy-jti');
      expect(info.issuedAt, 42);
      expect(info.lastSeen, 0);
      expect(info.deviceId, '');
      expect(info.label, '');
      expect(info.platform, 0);
      expect(info.isCurrent, isFalse);
    });
  });

  group('TfTokenListResult parsing', () {
    test('reads sessions array', () {
      final result = TfTokenListResult.fromJson(const {
        'sessions': [
          {'session_id': 'a', 'is_current': true},
          {'session_id': 'b'},
        ],
        'max_per_user': 5,
      });
      expect(result.tokens.length, 2);
      expect(result.maxPerUser, 5);
      expect(result.tokens.first.isCurrent, isTrue);
    });

    test('reads legacy tokens array', () {
      final result = TfTokenListResult.fromJson(const {
        'tokens': [
          {'jti': 'a'},
        ],
      });
      expect(result.tokens.length, 1);
      expect(result.tokens.first.sessionId, 'a');
      expect(result.maxPerUser, 0);
    });
  });

  group('TfDeviceInfo parsing', () {
    test('parses device payload and exposes displayName', () {
      final device = TfDeviceInfo.fromJson(const {
        'device_id': 'dev-1',
        'device_name': 'Pixel 8',
        'label': 'Work',
        'platform': 4,
        'last_seen': 1700000000,
      });
      expect(device.deviceId, 'dev-1');
      expect(device.deviceName, 'Pixel 8');
      expect(device.label, 'Work');
      expect(device.platform, 4);
      expect(device.lastSeen, 1700000000);
      expect(device.displayName, 'Work');
    });

    test('displayName falls back to deviceName then deviceId', () {
      final noLabel = TfDeviceInfo.fromJson(const {
        'device_id': 'dev-2',
        'device_name': 'Desktop',
      });
      expect(noLabel.displayName, 'Desktop');

      final onlyId = TfDeviceInfo.fromJson(const {'device_id': 'dev-3'});
      expect(onlyId.displayName, 'dev-3');
    });

    test('parses devices list result', () {
      final result = TfDeviceListResult.fromJson(const {
        'devices': [
          {'device_id': 'a'},
          {'device_id': 'b'},
        ],
      });
      expect(result.devices.length, 2);
    });

    test('empty or malformed payload yields no devices', () {
      expect(TfDeviceListResult.fromJson(const {}).devices, isEmpty);
      expect(
        TfDeviceListResult.fromJson(const {'devices': 'nope'}).devices,
        isEmpty,
      );
    });
  });
}
