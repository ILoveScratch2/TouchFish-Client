import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reverse timeline starts at latest message', (tester) async {
    final key = GlobalKey<_TimelineHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TimelineHarness(key: key, messages: _messages(0, 40)),
      ),
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.controller.offset, 0);
    expect(find.text('message 39'), findsOneWidget);
    expect(find.text('message 0'), findsNothing);
  });

  testWidgets('prepending history preserves the visible anchor', (
    tester,
  ) async {
    final key = GlobalKey<_TimelineHarnessState>();
    await tester.pumpWidget(
      MaterialApp(
        home: TimelineHarness(key: key, messages: _messages(0, 40)),
      ),
    );
    await tester.pumpAndSettle();

    key.currentState!.controller.jumpTo(
      key.currentState!.controller.position.maxScrollExtent,
    );
    await tester.pump();
    final before = tester.getTopLeft(find.text('message 0')).dy;

    key.currentState!.prepend(_messages(-20, 0));
    await tester.pump();

    expect(tester.getTopLeft(find.text('message 0')).dy, closeTo(before, 0.01));
  });
}

List<int> _messages(int start, int end) => [
  for (var value = start; value < end; value++) value,
];

class TimelineHarness extends StatefulWidget {
  final List<int> messages;

  const TimelineHarness({super.key, required this.messages});

  @override
  State<TimelineHarness> createState() => _TimelineHarnessState();
}

class _TimelineHarnessState extends State<TimelineHarness> {
  final ScrollController controller = ScrollController();
  late final List<int> messages = [...widget.messages];

  void prepend(List<int> older) {
    setState(() => messages.insertAll(0, older));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox(
        height: 240,
        child: ListView.builder(
          controller: controller,
          reverse: true,
          itemExtent: 40,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[messages.length - 1 - index];
            return Text('message $message');
          },
        ),
      ),
    );
  }
}
