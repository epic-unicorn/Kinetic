import 'package:flutter_test/flutter_test.dart';
import 'package:kinetic_webdav/kinetic_webdav.dart';

void main() {
  group('WebDavUrl', () {
    test('accepts https and strips trailing slash', () {
      expect(
        WebDavUrl.requireHttps('https://dav.example.com/remote.php/dav/'),
        'https://dav.example.com/remote.php/dav',
      );
    });

    test('rejects http', () {
      expect(
        () => WebDavUrl.requireHttps('http://dav.example.com'),
        throwsFormatException,
      );
    });

    test('coerceHttps upgrades legacy http', () {
      expect(
        WebDavUrl.coerceHttps('http://dav.example.com/dav'),
        'https://dav.example.com/dav',
      );
    });

    test('validationError for empty', () {
      expect(WebDavUrl.validationError(''), isNotNull);
      expect(WebDavUrl.validationError('https://ok.example'), isNull);
    });
  });
}
