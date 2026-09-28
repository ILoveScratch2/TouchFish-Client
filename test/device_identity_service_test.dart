import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:touchfish_client/services/device_identity_service_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DeviceIdentityService (fallback implementation)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      DeviceIdentityService.instance.setCachedForTest(null);
    });

    test('returns a stable hashed device id across calls', () async {
      final first = await DeviceIdentityService.instance.get();
      final second = await DeviceIdentityService.instance.get();

      expect(first.deviceId, isNotEmpty);
      expect(first.deviceId, first.deviceId);
      expect(second.deviceId, first.deviceId);
      // sha256 hex digest
      expect(first.deviceId.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(first.deviceId), isTrue);
    });

    test('persists the install id so a new instance resolves the same id',
        () async {
      final first = await DeviceIdentityService.instance.get();
      // simulate app restart by clearing the in-memory cache only
      DeviceIdentityService.instance.setCachedForTest(null);
      final second = await DeviceIdentityService.instance.get();
      expect(second.deviceId, first.deviceId);
    });

    test('uses the shared platform enum values expected by the server', () {
      expect(DevicePlatform.unknown, 0);
      expect(DevicePlatform.windows, 1);
      expect(DevicePlatform.macos, 2);
      expect(DevicePlatform.linux, 3);
      expect(DevicePlatform.android, 4);
      expect(DevicePlatform.ios, 5);
      expect(DevicePlatform.web, 6);
    });
  });
}
