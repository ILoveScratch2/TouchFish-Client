import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/screens/chat_detail/chat_scroll_follower.dart';

class _FollowHarness extends StatefulWidget {
  const _FollowHarness({super.key, required this.count});

  final int count;

  @override
  State<_FollowHarness> createState() => _FollowHarnessState();
}

class _FollowHarnessState extends State<_FollowHarness> {
  final ScrollController controller = ScrollController();
  late final ChatScrollFollower follower = ChatScrollFollower(
    isActive: () => mounted,
  );
  late int count = widget.count;

  @override
  void initState() {
    super.initState();
    follower.attach(controller);
    controller.addListener(follower.notePosition);
  }

  @override
  void dispose() {
    controller.removeListener(follower.notePosition);
    controller.dispose();
    super.dispose();
  }

  void appendMessages(int extra) {
    setState(() => count += extra);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 420,
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              if (follower.shouldFollowContentChange) {
                follower.scrollToBottom(animated: false);
              }
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: follower.handleScrollNotification,
              child: CustomScrollView(
                controller: controller,
                reverse: true,
                slivers: [
                  SliverList.builder(
                    itemCount: count,
                    itemBuilder: (context, index) => SizedBox(
                      height: 48,
                      child: Text('message ${count - 1 - index}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('will not scroll back to bottom if user scrolls up after sending message yaowendao dl taiqule', (tester) async {
    final key = GlobalKey<_FollowHarnessState>();
    await tester.pumpWidget(_FollowHarness(key: key, count: 60));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    expect(controller.position.pixels, 0);

    key.currentState!.follower.scrollToBottom(animated: false);
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(CustomScrollView)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
    await tester.pumpAndSettle();

    expect(
      controller.position.pixels,
      greaterThan(60),
      reason: 'ywd already scrolled up, scheduled scroll to bottom should be canceled',
    );
    expect(key.currentState!.follower.isFollowing, isFalse);
  });

  testWidgets('content changes while scrolling up should not trigger auto scroll to bottom', (tester) async {
    final key = GlobalKey<_FollowHarnessState>();
    await tester.pumpWidget(_FollowHarness(key: key, count: 60));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(CustomScrollView)));

    for (var i = 0; i < 3; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -120)));
      await tester.pumpAndSettle();
    }
    final scrolledTo = controller.position.pixels;
    expect(scrolledTo, greaterThan(100));

    for (var i = 0; i < 5; i++) {
      key.currentState!.appendMessages(1);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      controller.position.pixels,
      greaterThan(100),
      reason: 'During history scrolling, any content changes should not trigger auto scroll to bottom',
    );
    expect(key.currentState!.follower.isFollowing, isFalse);

    // New messages should also not secretly restore the following state
    await tester.pumpAndSettle();
    expect(key.currentState!.follower.isFollowing, isFalse);
  });

  testWidgets('user scrolling back to bottom should restore following state', (tester) async {
    final key = GlobalKey<_FollowHarnessState>();
    await tester.pumpWidget(_FollowHarness(key: key, count: 60));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(CustomScrollView)));

    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -150)));
    await tester.pumpAndSettle();
    expect(key.currentState!.follower.isFollowing, isFalse);

    for (var i = 0; i < 4; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 150)));
      await tester.pumpAndSettle();
    }
    expect(controller.position.pixels, 0);
    expect(key.currentState!.follower.isFollowing, isTrue);
  });

  testWidgets('new messages should not disrupt staying at the bottom when already at the bottom', (tester) async {
    final key = GlobalKey<_FollowHarnessState>();
    await tester.pumpWidget(_FollowHarness(key: key, count: 60));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    expect(controller.position.pixels, 0);

    for (var i = 0; i < 4; i++) {
      key.currentState!.appendMessages(1);
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(controller.position.pixels, 0);
    expect(key.currentState!.follower.isFollowing, isTrue);
    expect(find.text('message 63'), findsOneWidget);
  });

  testWidgets('scrolling near the top should still allow upward scrolling (not locked by follow logic)', (tester) async {
    final key = GlobalKey<_FollowHarnessState>();
    await tester.pumpWidget(_FollowHarness(key: key, count: 60));
    await tester.pumpAndSettle();

    final controller = key.currentState!.controller;
    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    pointer.hover(tester.getCenter(find.byType(CustomScrollView)));

    key.currentState!.follower.scrollToBottom(animated: false);
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, -200)));
      await tester.pumpAndSettle();
      key.currentState!.appendMessages(1);
      await tester.pumpAndSettle();
    }

    expect(
      controller.position.pixels,
      greaterThan(500),
      reason: 'Even with continuous upward scrolling and new incoming messages, the user should not be forcibly scrolled back to the bottom.',
    );
  });
}
