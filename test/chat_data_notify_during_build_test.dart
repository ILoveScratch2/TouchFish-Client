import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/chat_data_service.dart';


void main() {
  testWidgets('build notifyListeners wangyufan end', (tester) async {
    final service = ChatDataService.instance;
    var notified = 0;
    void listener() => notified++;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) => const SizedBox.shrink(),
        ),
      ),
    );

    service.addListener(listener);
    addTearDown(() => service.removeListener(listener));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) {
            service.notifyListeners();
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(tester.takeException(), isNull, reason: 'should not markNeedsBuild');

    await tester.pump();
    expect(notified, 1);
  });
}
