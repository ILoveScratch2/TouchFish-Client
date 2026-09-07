import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/models/file_task.dart';
import 'package:touchfish_client/providers/task/task_manager_provider.dart';
import 'package:touchfish_client/widgets/task_overlay.dart';

/// Seeds the task manager with a pre-populated list.
class _SeededTaskManager extends TaskManager {
  _SeededTaskManager(this._seed);
  final List<FileTask> _seed;

  @override
  List<FileTask> build() => _seed;
}

FileTask _transferringTask() => FileTask(
  id: 't1',
  type: FileTaskType.upload,
  status: FileTaskStatus.transferring,
  fileName: 'report.pdf',
  fileSize: 100,
  bytesTransferred: 50,
  createdAt: DateTime.now().subtract(const Duration(seconds: 2)),
);

void main() {
  final navigatorKey = GlobalKey<NavigatorState>();

  Widget app(Widget home, List<FileTask> seed) {
    return ProviderScope(
      overrides: [
        taskManagerProvider.overrideWith(() => _SeededTaskManager(seed)),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
        builder: (context, child) => Stack(
          children: [
            child!,
            TaskOverlay(
              navigatorContextProvider: () => navigatorKey.currentContext,
            ),
          ],
        ),
      ),
    );
  }

  testWidgets('tapping the pill opens the task sheet via the root navigator', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      app(const Scaffold(body: Center(child: Text('home'))), [
        _transferringTask(),
      ]),
    );
    await tester.pumpAndSettle();

    // The floating pill is shown for the active task.
    expect(find.text('report.pdf'), findsOneWidget);

    // This used to throw: "No Navigator found in context".
    await tester.tap(find.text('report.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('Transfer tasks'), findsOneWidget);

    // Drain the overlay's periodic prune timer by disposing the tree.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('hides when no active task remains', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app(const Scaffold(body: SizedBox()), []));
    await tester.pumpAndSettle();

    expect(find.text('report.pdf'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
