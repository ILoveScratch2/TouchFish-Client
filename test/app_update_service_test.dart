import 'package:flutter_test/flutter_test.dart';
import 'package:touchfish_client/services/app_update_service.dart';

void main() {
  group('compareVersions', () {
    test('equal versions compare as 0', () {
      expect(compareVersions('1.2.3', '1.2.3'), 0);
      expect(compareVersions('1.2.3+4', '1.2.3'), 0);
      expect(compareVersions('1.2.3', '1.2.3+7'), 0);
    });

    test('newer versions compare positive', () {
      expect(compareVersions('1.2.4', '1.2.3'), greaterThan(0));
      expect(compareVersions('1.3.0', '1.2.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
    });

    test('older versions compare negative', () {
      expect(compareVersions('1.2.3', '1.2.4'), lessThan(0));
      expect(compareVersions('1.2.9', '1.3.0'), lessThan(0));
      expect(compareVersions('1.9.9', '2.0.0'), lessThan(0));
    });

    test('handles missing components as zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1', '1.0.0'), 0);
      expect(compareVersions('1.2.1', '1.2'), greaterThan(0));
    });

    test('handles trailing build metadata', () {
      expect(compareVersions('1.2.3+100', '1.2.3+1'), 0);
      expect(compareVersions('1.2.4+1', '1.2.3+999'), greaterThan(0));
    });
  });

  group('_parseVersionFromHtml', () {
    test('parses version from <version> tag', () {
      expect(
        AppUpdateService.parseVersionFromHtml(
          '<html><body><version>1.2.3</version></body></html>',
        ),
        '1.2.3',
      );
    });

    test('parses version with dev-build suffix from tag', () {
      expect(
        AppUpdateService.parseVersionFromHtml(
          '<html><body><version>1.2.3-dev-build</version></body></html>',
        ),
        '1.2.3-dev-build',
      );
    });

    test('parses plain version from html body', () {
      expect(
        AppUpdateService.parseVersionFromHtml(
          '<html><body>Latest: 1.2.3</body></html>',
        ),
        '1.2.3',
      );
    });

    test('returns null for content without a version', () {
      expect(AppUpdateService.parseVersionFromHtml('<html></html>'), isNull);
      expect(AppUpdateService.parseVersionFromHtml(''), isNull);
    });

    test('returns trimmed short content', () {
      expect(AppUpdateService.parseVersionFromHtml('  1.2.3  '), '1.2.3');
    });
  });
}