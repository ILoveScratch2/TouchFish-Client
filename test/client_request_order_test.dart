import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/l10n/app_localizations.dart';
import 'package:touchfish_client/screens/forum_post_detail_screen.dart';
import 'package:touchfish_client/screens/forum_search_screen.dart';
import 'package:touchfish_client/screens/group_search_screen.dart';
import 'package:touchfish_client/services/api/tf_api_client.dart';

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

http.Response _response(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _forumResult(String title) => _response({
  'forums': [],
  'posts': [
    {'fid': 1, 'pid': 2, 'title': title, 'content': 'body'},
  ],
});

http.Response _groupResult(String name) => _response([
  [1, 2, name, [], null, '', '', true, false],
]);

void main() {
  final pending = <String, Completer<http.Response>>{};

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'TouchFish',
      packageName: 'touchfish_client',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    http.runWithClient(
      () => TfApiClient.instance,
      () => MockClient((request) async {
        final path = request.url.path;
        if (path == '/info' || path.startsWith('/forum/get_all_comments/')) {
          return _response({});
        }
        if (path == '/forum/get_forum_list') return _response([]);
        final key =
            request.url.queryParameters['query'] ??
            (path.startsWith('/forum/get_post/')
                ? path
                : request.url.pathSegments.last);
        return pending.putIfAbsent(key, Completer.new).future;
      }),
    );
  });

  setUp(pending.clear);

  testWidgets('forum search discards obsolete queries and clears pending results', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ForumSearchScreen()));
    final input = find.byType(TextField);
    for (final query in ['first', 'second']) {
      await tester.enterText(input, query);
      await tester.pump(const Duration(milliseconds: 400));
    }
    pending['second']!.complete(_forumResult('Second result'));
    await tester.pump();
    pending['first']!.complete(_forumResult('First result'));
    await tester.pump();
    expect(find.text('Second result'), findsOneWidget);
    expect(find.text('First result'), findsNothing);

    await tester.enterText(input, 'third');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.enterText(input, '');
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    pending['third']!.complete(_forumResult('Third result'));
    await tester.pump();
    expect(find.text('Third result'), findsNothing);
  });

  testWidgets('group search ignores results from an earlier submission', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const GroupSearchScreen()));
    final input = find.byType(TextField);
    for (final query in ['first', 'second']) {
      await tester.enterText(input, query);
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
    }

    pending['second']!.complete(_groupResult('Second group'));
    await tester.pump();
    expect(find.text('Second group'), findsOneWidget);

    pending['first']!.complete(_groupResult('First group'));
    await tester.pump();
    expect(find.text('Second group'), findsOneWidget);
    expect(find.text('First group'), findsNothing);
  });

  testWidgets('a late post response does not replace the current post', (
    tester,
  ) async {
    const firstPath = '/forum/get_post/42/1';
    const secondPath = '/forum/get_post/42/2';
    await tester.pumpWidget(
      _app(const ForumPostDetailScreen(forumId: '42', postId: '1')),
    );
    await tester.pump();
    await tester.pumpWidget(
      _app(const ForumPostDetailScreen(forumId: '42', postId: '2')),
    );
    await tester.pump();

    pending[secondPath]!.complete(
      _response({'fid': 42, 'pid': 2, 'title': 'Second thread'}),
    );
    await tester.pump();
    final currentTitle = find.descendant(
      of: find.byType(AppBar),
      matching: find.text('Second thread'),
    );
    expect(currentTitle, findsOneWidget);

    pending[firstPath]!.complete(
      _response({'fid': 42, 'pid': 1, 'title': 'First thread'}),
    );
    await tester.pump();
    expect(currentTitle, findsOneWidget);
    expect(find.text('First thread'), findsNothing);
  });
}
