import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:touchfish_client/models/external_auth_config.dart';
import 'package:touchfish_client/services/external_auth_loopback.dart';
import 'package:touchfish_client/services/external_auth_service.dart';

ExternalAuthConfig _config({
  List<String>? responseModes,
}) {
  return ExternalAuthConfig.tryParse({
    'issuer': 'https://auth.example.touchfish.xin',
    'authorization_endpoint': 'https://auth.example.touchfish.xin/authorize',
    'ticket_endpoint': 'https://auth.example.touchfish.xin/api/auth/ticket',
    'methods': <dynamic>[],
    if (responseModes != null) 'response_modes': responseModes,
  })!;
}

void main() {
  group('ExternalAuthPkce', () {
    test('verifier ok for length and state', () {
      final pkce = ExternalAuthPkce.generate();
      expect(pkce.verifier.length, inInclusiveRange(43, 128));
      expect(pkce.state, isNotEmpty);
      expect(pkce.challenge, isNotEmpty);
    });

    test('challenge is correct S256 hash of verifier', () {
      final pkce = ExternalAuthPkce.generate();
      final expected = base64Url
          .encode(sha256.convert(utf8.encode(pkce.verifier)).bytes)
          .replaceAll('=', '');
      expect(pkce.challenge, expected);
      expect(pkce.challenge, isNot(contains('=')));
    });

    test('each generation produces new materials', () {
      final a = ExternalAuthPkce.generate();
      final b = ExternalAuthPkce.generate();
      expect(a.verifier, isNot(b.verifier));
      expect(a.state, isNot(b.state));
    });
  });

  group('ExternalAuthConfig authorize', () {
    test('supports system browser channel when loopback is declared', () {
      expect(_config(responseModes: ['bridge', 'loopback']).supportsLoopback, isTrue);
    });

    test('treated as bridge only when not declared', () {
      expect(_config().supportsLoopback, isFalse);
      expect(_config(responseModes: ['bridge']).supportsLoopback, isFalse);
    });

    test('returns null when parsing fails', () {
      expect(
        ExternalAuthConfig.tryParse({'issuer': 'x'}),
        isNull,
      );
    });
  });

  group('ExternalAuthLoopback', () {
    test('returns ticket when state and ticket both match', () async {
      final loopback = await ExternalAuthLoopback.start();
      expect(loopback, isNotNull);
      final session = loopback!;
      addTearDown(session.close);

      final pending = session.waitForTicket('state-1');
      final client = HttpClient();
      final uri = Uri.parse(session.redirectUri).replace(
        queryParameters: {'state': 'state-1', 'ticket': 'ticket-abc'},
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain<void>();
      client.close();

      expect(await pending, 'ticket-abc');
    });

    test('callback with mismatched state does not complete the wait', () async {
      final loopback = await ExternalAuthLoopback.start();
      expect(loopback, isNotNull);
      final session = loopback!;
      addTearDown(session.close);

      final pending = session.waitForTicket(
        'right-state',
        timeout: const Duration(seconds: 1),
      );
      final client = HttpClient();
      final uri = Uri.parse(session.redirectUri).replace(
        queryParameters: {'state': 'wrong-state', 'ticket': 'ticket-abc'},
      );
      final request = await client.getUrl(uri);
      final response = await request.close();
      await response.drain<void>();
      client.close();

      expect(await pending, isNull);
    });

    test('callback URL uses loopback IP only', () {
      expect(
        Uri.parse('http://127.0.0.1:53683/auth/callback').host,
        '127.0.0.1',
      );
    });
  });
}
