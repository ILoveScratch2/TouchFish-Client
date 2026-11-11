import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/screens/chat_detail/widgets/chat_detail_banners.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('empty slots collapse to nothing', (tester) async {
    await tester.pumpWidget(wrap(const ChatDetailBanners()));
    expect(find.byType(Column), findsNothing);
  });

  testWidgets('non-null slots render in order', (tester) async {
    await tester.pumpWidget(
      wrap(
        const ChatDetailBanners(
          syncIndicator: Text('sync'),
          pinnedBar: Text('pinned'),
          notice: Text('notice'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sync'), findsOneWidget);
    expect(find.text('pinned'), findsOneWidget);
    expect(find.text('notice'), findsOneWidget);

    final syncY = tester.getTopLeft(find.text('sync')).dy;
    final pinnedY = tester.getTopLeft(find.text('pinned')).dy;
    final noticeY = tester.getTopLeft(find.text('notice')).dy;
    expect(syncY, lessThan(pinnedY));
    expect(pinnedY, lessThan(noticeY));
  });

  testWidgets('slots animate in and out as they become non-null / null', (
    tester,
  ) async {
    Widget build({Widget? essence}) =>
        wrap(ChatDetailBanners(essenceBar: essence));

    await tester.pumpWidget(build());
    expect(find.text('essence'), findsNothing);

    await tester.pumpWidget(build(essence: const Text('essence')));
    await tester.pumpAndSettle();
    expect(find.text('essence'), findsOneWidget);

    await tester.pumpWidget(build());
    await tester.pumpAndSettle();
    expect(find.text('essence'), findsNothing);
  });

  testWidgets('ChatDetailNotice renders text and close button on dismiss', (
    tester,
  ) async {
    var dismissed = 0;
    await tester.pumpWidget(
      wrap(
        ChatDetailNotice(text: 'joined the group', onDismiss: () => dismissed++),
      ),
    );
    expect(find.text('joined the group'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    expect(dismissed, 1);
  });

  testWidgets('ChatDetailNotice omits the close button without onDismiss', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ChatDetailNotice(text: 'hello')));
    expect(find.text('hello'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
