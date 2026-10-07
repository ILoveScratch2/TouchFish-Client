import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:touchfish_client/models/settings_service.dart';
import 'package:touchfish_client/services/domain_trust_service.dart';

void main() {
  final service = DomainTrustService.instance;

  group('DomainTrustService.matchesHostPattern', () {
    test('exact domain pattern only matches the exact host', () {
      expect(
        service.matchesHostPattern('touchfish.xin', 'touchfish.xin/*'),
        isTrue,
      );
      expect(
        service.matchesHostPattern('touchfish.xin', 'touchfish.xin'),
        isTrue,
      );
      expect(
        service.matchesHostPattern('www.touchfish.xin', 'touchfish.xin/*'),
        isFalse,
      );
      expect(
        service.matchesHostPattern('evil-touchfish.xin', 'touchfish.xin/*'),
        isFalse,
      );
      expect(
        service.matchesHostPattern('notouchfish.xin', 'touchfish.xin/*'),
        isFalse,
      );
    });

    test('wildcard pattern matches base host and subdomains', () {
      expect(
        service.matchesHostPattern('touchfish.xin', '*.touchfish.xin/*'),
        isTrue,
      );
      expect(
        service.matchesHostPattern('api.touchfish.xin', '*.touchfish.xin/*'),
        isTrue,
      );
      expect(
        service.matchesHostPattern('a.b.touchfish.xin', '*.touchfish.xin/*'),
        isTrue,
      );
      expect(
        service.matchesHostPattern(
          'touchfish.xin.evil.com',
          '*.touchfish.xin/*',
        ),
        isFalse,
      );
      expect(
        service.matchesHostPattern('evil.com', '*.touchfish.xin/*'),
        isFalse,
      );
    });

    test('pattern without path is treated as host only', () {
      expect(service.matchesHostPattern('github.com', 'github.com'), isTrue);
      expect(
        service.matchesHostPattern('raw.githubusercontent.com', 'github.com'),
        isFalse,
      );
      expect(
        service.matchesHostPattern(
          'raw.githubusercontent.com',
          '*.githubusercontent.com/*',
        ),
        isTrue,
      );
    });

    test('default trusted domains cover the standard servers', () {
      for (final host in [
        'touchfish.xin',
        'api.touchfish.xin',
        'touchfish.us.ci',
        'bopid.cn',
        'ilovescratch.us.ci',
        'cdn.ilovescratch.us.ci',
        'piaoztsdy.cn',
        'file.piaoztsdy.cn',
        'icc.gt.tc',
        'github.com',
        'raw.githubusercontent.com',
        'luogu.com.cn',
        'www.luogu.com.cn',
        'luogu.com',
        'www.luogu.com',
        'luogu.me',
        'bilibili.com',
        'b23.tv',
        'bing.com',
        'google.com',
      ]) {
        final matched = DomainTrustService.defaultTrustedDomains.any(
          (pattern) => service.matchesHostPattern(host, pattern),
        );
        expect(
          matched,
          isTrue,
          reason: '$host should be trusted by the default list',
        );
      }
    });

    test('default list does not trust unrelated domains', () {
      for (final host in [
        'evil.com',
        'touchfish.xin.phishing.net',
        'google.com.phishing.net',
        'luogu.com.cn.evil.io',
      ]) {
        final matched = DomainTrustService.defaultTrustedDomains.any(
          (pattern) => service.matchesHostPattern(host, pattern),
        );
        expect(
          matched,
          isFalse,
          reason: '$host must not match the default trust list',
        );
      }
    });
  });

  group('DomainTrustService confirm counts', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SettingsService.instance.init();
      await SettingsService.instance.remove(
        DomainTrustService.kConfirmCountsKey,
      );
      await SettingsService.instance.remove(
        DomainTrustService.kTrustedDomainsKey,
      );
    });

    test('no confirmations initially and no trust suggestion', () async {
      expect(await service.confirmCountFor('example.com'), 0);
      expect(await service.shouldSuggestTrust('example.com'), isFalse);
    });

    test('first confirmation does not suggest trust', () async {
      await service.recordConfirmedOpen(Uri.parse('https://example.com/a'));
      expect(await service.confirmCountFor('example.com'), 1);
      expect(await service.shouldSuggestTrust('example.com'), isFalse);
    });

    test('second confirmation triggers suggestion on next ask', () async {
      await service.recordConfirmedOpen(Uri.parse('https://example.com/a'));
      await service.recordConfirmedOpen(Uri.parse('https://example.com/b'));
      expect(await service.confirmCountFor('example.com'), 2);
      expect(await service.shouldSuggestTrust('example.com'), isTrue);
    });

    test('counts are tracked per host', () async {
      await service.recordConfirmedOpen(Uri.parse('https://a.com/x'));
      await service.recordConfirmedOpen(Uri.parse('https://b.com/y'));
      await service.recordConfirmedOpen(Uri.parse('https://b.com/z'));
      expect(await service.confirmCountFor('a.com'), 1);
      expect(await service.confirmCountFor('b.com'), 2);
      expect(await service.shouldSuggestTrust('a.com'), isFalse);
      expect(await service.shouldSuggestTrust('b.com'), isTrue);
    });

    test('addTrustedDomain adds host pattern to the list', () async {
      await service.addTrustedDomain('Example.COM');
      final domains = service.trustedDomains;
      expect(domains, contains('example.com/*'));
    });

    test('addTrustedDomain is a no-op when already trusted', () async {
      await service.addTrustedDomain('github.com');
      final domains = service.trustedDomains;
      expect(domains.where((d) => d.contains('github.com')), hasLength(1));
      expect(domains, orderedEquals(DomainTrustService.defaultTrustedDomains));
    });
  });
}
