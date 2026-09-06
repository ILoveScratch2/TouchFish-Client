import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/services/real_rtc_peer.dart';

void main() {
  group('resolveMediaAvailability', () {
    test('no devices disables both audio and video', () {
      final r = resolveMediaAvailability(const [], videoRequested: true);
      expect(r.audio, isFalse);
      expect(r.video, isFalse);
    });

    test('mic only yields audio without video', () {
      final r = resolveMediaAvailability(
        const ['audioinput'],
        videoRequested: true,
      );
      expect(r.audio, isTrue);
      expect(r.video, isFalse);
    });

    test('camera + mic yields audio and video', () {
      final r = resolveMediaAvailability(
        const ['audioinput', 'videoinput'],
        videoRequested: true,
      );
      expect(r.audio, isTrue);
      expect(r.video, isTrue);
    });

    test('video is not requested when the user asked audio only', () {
      final r = resolveMediaAvailability(
        const ['audioinput', 'videoinput'],
        videoRequested: false,
      );
      expect(r.audio, isTrue);
      expect(r.video, isFalse);
    });
  });
}
