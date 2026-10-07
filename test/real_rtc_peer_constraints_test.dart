import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/real_rtc_peer.dart';

void main() {
  test('uses W3C exact deviceId constraints on web', () {
    expect(buildVideoConstraints('camera-1', isWeb: true), {
      'deviceId': {'exact': 'camera-1'},
    });
  });

  test('uses optional sourceId constraints on native platforms', () {
    expect(buildVideoConstraints('camera-1', isWeb: false), {
      'optional': [
        {'sourceId': 'camera-1'},
      ],
    });
  });

  test('uses the default camera when no device is selected', () {
    expect(buildVideoConstraints(null, isWeb: false), isTrue);
    expect(buildVideoConstraints('', isWeb: true), isTrue);
  });
}
