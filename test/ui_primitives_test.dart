import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/widgets/ui/empty_state.dart';
import 'package:touchfish_client/widgets/ui/load_more_footer.dart';
import 'package:touchfish_client/widgets/ui/refreshable.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('renders icon, title, description and action', (tester) async {
      await tester.pumpWidget(
        _harness(
          EmptyState(
            icon: Icons.search_off,
            title: 'Nothing here',
            description: 'Try another keyword',
            action: TextButton(onPressed: () {}, child: const Text('Retry')),
          ),
        ),
      );

      expect(find.byIcon(Icons.search_off), findsOneWidget);
      expect(find.text('Nothing here'), findsOneWidget);
      expect(find.text('Try another keyword'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('omits description and action when not provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const EmptyState(icon: Icons.inbox, title: 'Empty'),
        ),
      );

      expect(find.text('Empty'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
    });
  });

  group('LoadMoreFooter', () {
    testWidgets('shows a spinner while loading', (tester) async {
      await tester.pumpWidget(
        _harness(const LoadMoreFooter(loading: true, hasMore: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows nothing when more pages remain', (tester) async {
      await tester.pumpWidget(
        _harness(const LoadMoreFooter(loading: false, hasMore: true)),
      );
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('No more'), findsNothing);
    });

    testWidgets('shows the end-of-list label when exhausted', (tester) async {
      await tester.pumpWidget(
        _harness(const LoadMoreFooter(loading: false, hasMore: false)),
      );
      expect(find.text('No more'), findsOneWidget);
    });

    testWidgets('hides the end-of-list label when showNoMore is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          const LoadMoreFooter(
            loading: false,
            hasMore: false,
            showNoMore: false,
          ),
        ),
      );
      expect(find.text('No more'), findsNothing);
    });
  });

  group('PullToRefresh', () {
    testWidgets('content mode stays pullable and fires onRefresh', (
      tester,
    ) async {
      var refreshed = false;
      await tester.pumpWidget(
        _harness(
          PullToRefresh.content(
            onRefresh: () async => refreshed = true,
            child: const EmptyState(icon: Icons.inbox, title: 'Empty'),
          ),
        ),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });

    testWidgets('list mode stays pullable when the child is an empty state', (
      tester,
    ) async {
      var refreshed = false;
      await tester.pumpWidget(
        _harness(
          PullToRefresh.list(
            onRefresh: () async => refreshed = true,
            child: const ScrollableFill(
              child: EmptyState(icon: Icons.inbox, title: 'Empty'),
            ),
          ),
        ),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, 400));
      await tester.pumpAndSettle();

      expect(refreshed, isTrue);
    });

    testWidgets('list mode wraps the child in a RefreshIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          PullToRefresh.list(
            onRefresh: () async {},
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [SizedBox(height: 40)],
            ),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });
  });
}
