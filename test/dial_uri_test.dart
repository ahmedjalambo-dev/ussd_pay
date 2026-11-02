import 'package:flutter_test/flutter_test.dart';
import 'package:ussd_pay/services/dialer_service.dart';

void main() {
  group('buildDialUri', () {
    test('encodes the trailing # as %23', () {
      // The classic USSD-app bug: an un-encoded "#" opens a URI fragment, so
      // the dialer receives "*268*1*0599123456*50" and the fragment is thrown
      // away. The truncated code is not a valid command.
      expect(
        DialerService.buildDialUri('*268*1*0599123456*50#').toString(),
        'tel:*268*1*0599123456*50%23',
      );
    });

    test('leaves * untouched', () {
      final uri = DialerService.buildDialUri('*268*1*0599123456*50#');
      expect(uri.toString(), contains('*268*1*'));
      expect(uri.toString(), isNot(contains('%2A')));
    });

    test('the scheme is tel', () {
      expect(DialerService.buildDialUri('*123#').scheme, 'tel');
    });

    test('the code round-trips through the URI unchanged', () {
      const codes = [
        '*268*1*0599123456*50#',
        '*268*2*0599123456*50#',
        '*370*1*1*0599123456*50#',
        '*370*2*0599123456*50#',
        '*370*2*0599123456*10.50#',
      ];
      for (final code in codes) {
        final uri = DialerService.buildDialUri(code);
        // Uri.path returns the *encoded* path, so decode before comparing.
        expect(Uri.decodeComponent(uri.path), code,
            reason: 'the dialer must receive exactly the confirmed code');
        expect(uri.toString(), 'tel:${code.replaceAll('#', '%23')}');
      }
    });

    test('no fragment is ever produced', () {
      final uri = DialerService.buildDialUri('*268*1*0599123456*50#');
      expect(uri.hasFragment, isFalse);
      expect(uri.fragment, isEmpty);
    });

    test('a code with a decimal amount encodes correctly', () {
      expect(
        DialerService.buildDialUri('*268*1*0599123456*10.50#').toString(),
        'tel:*268*1*0599123456*10.50%23',
      );
    });
  });
}
