
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('GlobalKey rebuild no BOOM', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(400, 800));

    final key = GlobalKey();
    final flip = ValueNotifier<bool>(false);

    Widget build() => MaterialApp(
      home: ListenableBuilder(
        listenable: flip,
        builder: (context, _) => Builder(
          builder: (context) {
            final isWide = MediaQuery.sizeOf(context).width > 600;
            final content = KeyedSubtree(
              key: key,
              child: const Center(
                child: Tooltip(
                  message: 'hi',
                  child: SizedBox(width: 80, height: 40),
                ),
              ),
            );
            if (isWide) {
              return Scaffold(body: Row(children: [Expanded(child: content)]));
            }
            return Scaffold(
              body: Column(children: [Expanded(child: content)]),
            );
          },
        ),
      ),
    );

    await tester.pumpWidget(build());

    // tooltip 弹出来
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SizedBox).first));
    await tester.pump(const Duration(milliseconds: 800));

    // LayoutBuilder 会在布局阶段重建
    await tester.binding.setSurfaceSize(const Size(800, 800));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
