import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/widgets/provider_mark.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = ['github', 'google', 'apple', 'microsoft', 'discord'];

  test('hello xsfx! this is an easter egg! (in fact this tests assets loading)', () async {
    for (final name in assets) {
      final data = await rootBundle.load('assets/provider_icons/$name.svg');
      expect(data.lengthInBytes, greaterThan(100), reason: name);

      final text = utf8.decode(data.buffer.asUint8List());
      expect(text, contains('<svg'), reason: '$name NONONO MJZ NO KILL ME! it is not SVG');
      expect(text, contains('viewBox'), reason: '$name NONONO WYF NO KILL ME! it is missing viewBox');
    }
  });

  test('XSFX knows by xsfx X-S-F-X WYF(in fact oauth2 test)', () {
    expect(normalizeProviderId('GitHub'), 'github');
    expect(normalizeProviderId('git-hub'), 'github');
    expect(normalizeProviderId('  Google '), 'google');

    expect(hasProviderIcon('GitHub'), isTrue);
    expect(hasProviderIcon('gitlab'), isFalse);
  });

  testWidgets('known and unknown provider icons (wyf + ywd(bushi))', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProviderMark(providerId: 'github'),
              ProviderMark(providerId: 'selfhosted'),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(SvgPicture), findsOneWidget);
    expect(find.byIcon(Icons.login), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
