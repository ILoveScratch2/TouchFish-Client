import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/snackbar_service.dart';
import 'package:touchfish_client/widgets/snackbar_overlay.dart';

void main() {
  testWidgets('snackbar stays for the service-owned duration then clears',
      (tester) async {
    TouchFishSnackbarService.instance.clear();
    await tester.pumpWidget(
      const MaterialApp(
        home: TouchFishSnackbarOverlay(child: Scaffold(body: SizedBox())),
      ),
    );

    TouchFishSnackbarService.instance.showSuccess('saved');
    await tester.pump();
    expect(find.text('saved'), findsOneWidget);

    // 重建不应重置倒计时（旧实现把 Timer 放在 build 里，会被反复重置）
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('saved'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('saved'), findsNothing);
    expect(TouchFishSnackbarService.instance.message, isNull);
  });
}
