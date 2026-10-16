import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/utils/read_receipt_throttle.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 12);

  test('the first query is allowed', () {
    expect(ReadReceiptThrottle().shouldQuery(1, t0), isTrue);
  });

  test('the same mid inside the cooldown window is skipped', () {
    final throttle = ReadReceiptThrottle(
      cooldown: const Duration(seconds: 3),
    );
    expect(throttle.shouldQuery(1, t0), isTrue);
    throttle.done();

    expect(
      throttle.shouldQuery(1, t0.add(const Duration(seconds: 2))),
      isFalse,
    );
    expect(
      throttle.shouldQuery(1, t0.add(const Duration(seconds: 3))),
      isTrue,
    );
  });

  test('a new mid is queried immediately, even inside the window', () {
    final throttle = ReadReceiptThrottle();
    expect(throttle.shouldQuery(1, t0), isTrue);
    throttle.done();

    expect(
      throttle.shouldQuery(2, t0.add(const Duration(milliseconds: 100))),
      isTrue,
    );
  });

  test('a query still in flight blocks the next one', () {
    final throttle = ReadReceiptThrottle();
    expect(throttle.shouldQuery(1, t0), isTrue);
    expect(throttle.shouldQuery(2, t0), isFalse);

    throttle.done();
    expect(throttle.shouldQuery(2, t0), isTrue);
  });

  test('a query that never settles stops blocking once it times out', () {
    final throttle = ReadReceiptThrottle(
      timeout: const Duration(seconds: 10),
    );
    expect(throttle.shouldQuery(1, t0), isTrue);
    // 仍在 timeout 之内：算在飞，不放行
    expect(
      throttle.shouldQuery(2, t0.add(const Duration(seconds: 9))),
      isFalse,
    );
    // 超过 timeout：一次挂死的请求不该把本房间的补查永久堵住
    expect(
      throttle.shouldQuery(2, t0.add(const Duration(seconds: 10))),
      isTrue,
    );
  });

  test('done() also clears the in-flight deadline', () {
    final throttle = ReadReceiptThrottle(timeout: const Duration(seconds: 1));
    expect(throttle.shouldQuery(1, t0), isTrue);
    throttle.done();

    expect(
      throttle.shouldQuery(1, t0.add(const Duration(seconds: 30))),
      isTrue,
    );
  });

  test('reset drops the mid, the timestamp and the in-flight flag', () {
    final throttle = ReadReceiptThrottle();
    expect(throttle.shouldQuery(1, t0), isTrue);

    throttle.reset();
    expect(throttle.shouldQuery(1, t0), isTrue); // 冷却不再拦同一条消息
    expect(throttle.shouldQuery(2, t0), isFalse); // 但刚发起的这次仍在飞
  });
}
