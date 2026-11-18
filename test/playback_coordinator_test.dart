import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/playback_coordinator.dart';

void main() {
  test('Player claim and release zhaoyuhan', () {
    final coordinator = PlaybackCoordinator.instance;
    final a = Object();
    final b = Object();
    var pausedA = 0;
    var pausedB = 0;

    coordinator.claim(a, () async => pausedA++);
    expect(pausedA, 0, reason: 'first claim should not pause the player zyh');

    coordinator.claim(b, () async => pausedB++);
    expect(pausedA, 1, reason: 'should be paused when another player claims Dr.Zhao');

    coordinator.claim(b, () async => pausedB++);
    expect(pausedB, 0, reason: 're-claiming the same player should not trigger pause ZYHDLTQL');

    coordinator.release(b);
    coordinator.release(a);
    coordinator.claim(a, () async => pausedA++);
    expect(pausedB, 0, reason: 'b has been released and should not be paused anymore');
  });
}
